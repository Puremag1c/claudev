# Claudev — Project Context

## Что это за проект

**Claudev** — многоагентная система автоматической разработки на базе Claude Code.

Система позволяет запустить полностью автономную разработку проекта: менеджер координирует работу архитектора, кодеров, ревьюеров и помощников. Состояние хранится в Beads, работа идёт через bash orchestrator.

## Цель

Система должна легко интегрироваться в любой проект через `git clone`.

## Структура проекта

```
claudev/
├── CLAUDE.md              # Персональный ассистент (переносится между проектами)
├── PROJECT.md             # ← Этот файл (контекст проекта)
├── core/                  # Ядро системы
│   ├── agents/            # Шаблоны агентов (manager, architect, coder...)
│   ├── commands/          # Slash-команды (/start, /status)
│   └── scripts/           # Bash скрипты (orchestrator, claim-task...)
├── templates/             # Шаблоны для целевого проекта
│   ├── SPEC.template.md   # Шаблон спецификации
│   └── CLAUDE.template.md # Шаблон CLAUDE.md для проекта
├── install.sh             # Установщик в целевой проект
└── docs/                  # Документация
    └── architecture.md    # Архитектура системы
```

## ВАЖНО: Работа с файлами агентов

Файлы в `core/agents/*.md` — это **КОД ПРОЕКТА**, а не инструкции для текущей сессии Claude.

При работе над claudev я редактирую эти файлы как обычный исходный код. Они станут инструкциями только когда система будет установлена в целевой проект и запущена через orchestrator.

## Как система интегрируется в проект

```bash
# В целевом проекте:
git clone git@github.com:user/claudev.git .claudev
.claudev/install.sh

# Результат:
target-project/
├── .claudev/              # Клонированное ядро
├── .claude/               # Симлинки на agents и commands
│   ├── agents -> ../.claudev/core/agents
│   └── commands -> ../.claudev/core/commands
├── scripts -> .claudev/core/scripts
├── SPEC.md                # Спецификация проекта (заполняет пользователь)
└── CLAUDE.md              # Project instructions
```

## Ключевые компоненты системы

### Агенты (core/agents/)

| Агент | Модель | Роль |
|-------|--------|------|
| manager | Sonnet | Stateless координатор, определяет фазу по beads, единая точка входа |
| tech-writer | Opus | Собирает требования, задаёт вопросы, формирует SPEC.md |
| architect | Opus | Создаёт план, назначает модели задачам, расставляет dependencies |
| analyst-ux | Sonnet | Проверяет UX, добавляет задачи (только добавляет, не удаляет) |
| analyst-security | Sonnet | Проверяет безопасность, добавляет задачи |
| analyst-ops | Sonnet | Проверяет операционные аспекты, добавляет задачи |
| analyst-reliability | Sonnet | Проверяет надёжность, edge cases, добавляет задачи |
| analyst-architecture | Sonnet | Проверяет архитектуру, добавляет задачи |
| executor | По задаче | Реализует ОДНУ задачу, работает в своей git ветке |
| senior-executor | Opus | Последовательно валидирует код, мержит в main |

### Формат промптов агентов

Каждый файл агента (`core/agents/*.md`) содержит:

```markdown
---
name: agent-name
description: Краткое описание роли
model: opus|sonnet|haiku
---

# Роль: Название

Краткое описание что делает агент.

## КРИТИЧЕСКИЕ ПРАВИЛА
- Что НИКОГДА не делать
- Что ВСЕГДА делать первым

## Алгоритм работы
1. Первый шаг (с примером команды)
2. Второй шаг
3. ...

## Инструменты
- `bd` команды которые использует
- `git` операции если нужны
- Другие скрипты

## Завершение
- Как агент понимает что закончил
- Что делает в конце (close задачи, log, etc.)
```

**Принципы написания промптов для LLM:**
- Простые изолированные команды (одна операция = одна команда)
- Явные примеры с `bd create`, `bd close`, `git commit`
- Чёткие критерии завершения
- Минимум условной логики (if/else)

### Скрипты (core/scripts/)

| Скрипт | Назначение |
|--------|------------|
| orchestrator.sh | Главный цикл, пингует менеджера каждые N секунд |
| detect-phase.sh | Определение текущей фазы проекта |
| run-analysts.sh | Параллельный запуск 5 analysts |
| run-executors.sh | Параллельный запуск executors (до MAX_PARALLEL) |
| log.sh | Хелпер для логирования в logs/claudev.log |

**Устаревшие (удалить):**
- claim-task.sh — заменён на `bd update <id> --claim`
- init-manager.sh — Manager stateless, не нужна инициализация
| run-helpers.sh | Параллельный запуск помощников |
| run-coders.sh | Параллельный запуск кодеров |

### Фазы проекта

```
INIT → PLANNING → HELPERS → PLAN_REVIEW → IMPLEMENTATION → FINAL_REVIEW → DONE
```

## Зависимости

- **Beads** — система управления задачами (bd CLI)
- **Claude Code** — CLI для запуска агентов
- **Bash** — для orchestrator и скриптов

## Ключевые требования

### Целевая аудитория
- Непрограммисты, которые могут чётко отвечать на вопросы
- От словесного описания → к готовому продукту

### Принципы системы
- **Полная автономность** — не copilot, а отдел разработки
- **Итеративность** — MVP → доработка → доработка (не overthinking)
- **Короткие задачи** — каждый task в beads = 1-5 минут Sonnet
- **Персистентность** — всё в Beads, любой воркер может упасть

### Пайплайн ролей
```
Vision (заказчик)
    ↓
Tech Writer (собирает требования, задаёт вопросы, формирует ТЗ + config)
    ↓
Architect (план, разбивка на задачи, зависимости)
    ↓
Analysts (UX / Security / OPS / Reliability / Architecture)
    ↓
Architect (доработка плана по feedback аналитиков)
    ↓
Executors (реализация задач)
    ↓
Senior Executor (код ревью, merge, релиз)
    ↓
Architect (FINAL_REVIEW — проверка целостности)
    ↓
CI/CD GitHub (опционально)
```

### Управление процессом
- Manager в цикле (пока нет лучшего решения)
- Таймауты для управления падениями (задача > 10 мин = проблема)
- Beads как единственный источник правды

---

## Текущий статус

**Статус:** РЕАЛИЗАЦИЯ ЗАВЕРШЕНА (24 января 2026)

Все 52 задачи закрыты. Система готова к использованию.

**Реализовано:**
- ✅ core/agents/ — 10 промптов агентов (Tech Writer, Manager, Architect, Executor, Senior Executor, 5 Analysts)
- ✅ core/scripts/ — orchestrator.sh, detect-phase.sh, run-executors.sh, run-analysts.sh, log.sh
- ✅ templates/ — config.template.sh, SPEC.template.md, CLAUDE.template.md
- ✅ install.sh — dependency check, git init, beads init, pre-commit hook, .gitignore
- ✅ docs/architecture.md — полная документация

**Архитектурный аудит:**
- ✅ Первое прохождение (23 января): 10 угроз → решения #11-#20
- ✅ Второе прохождение (24 января): 9 угроз → решения #21-#25
- ✅ Все P0 блокеры закрыты (config validation, backpressure)

**Следующий шаг:** Первый реальный запуск системы на тестовом проекте.

**Обсуждено (22 января 2026):**
- ✅ Tech Writer — Opus, сам пишет в beads, режимы (новый/итерация)
- ✅ Manager — Sonnet, stateless, определяет фазу по beads
- ✅ Архитектура — subagents + beads, каждый агент сам пишет состояние
- ✅ Отказоустойчивость — retry 3x, эскалация к Architect, лимит 2
- ✅ **Timeout enforcement:**
  - Orchestrator запускает агентов через `timeout 10m claude -p "..."`
  - При таймауте: процесс убивается, логируется, retry counter++
  - Retry history хранится в notes задачи:
    ```
    retry 1: 2026-01-23 15:30 - timeout
    retry 2: 2026-01-23 15:45 - timeout
    ```
  - После 3 retry → эскалация к Architect
- ✅ UX — 4 статуса, варианты для user, clarification vs decision
- ✅ Итерации — SPEC.md с секциями Iteration N

**Обсуждено (23 января 2026):**
- ✅ Senior Analyst — убран, избыточен
- ✅ Противоречия между аналитиками — решает Architect
- ✅ Приоритет: Security > UX (избыточные меры убираем итерациями)
- ✅ Аналитики только ДОБАВЛЯЮТ задачи, Architect может УДАЛЯТЬ (дубликаты, избыточность)
- ✅ Manager — единая точка координации, Architect не ждёт аналитиков сам
- ✅ Формат задачи в beads для Executor:
  ```
  title: краткое описание (1-2 предложения)
  files: какие файлы трогать (1-3)
  done_when: чёткий критерий готовности
  ```
- ✅ Гранулярность задач — эвристика: "если есть 'и' — это 2 задачи", "больше 3 файлов — разбей"

- ✅ Analysts — оставляем всех 5 (UX, Security, OPS, Reliability, Architecture). Дёшево запустить, дорого пропустить ошибки.

- ✅ **Executors — git workflow:**
  - Architect назначает модель (haiku/sonnet/opus) каждой задаче по сложности
  - Architect расставляет dependencies для возможности параллельной работы
  - Executor создаёт ветку `task/beads-xxx`, работает, коммитит
  - Executor помечает задачу done → разблокирует зависимые
  - **КРИТИЧНО:** Захват задачи ТОЛЬКО через `bd update <id> --claim`
  - ✅ Проверено: bd CLI гарантирует атомарность (fails if already claimed)
  - Race condition между Executors невозможен

- ✅ **Senior Executor (Opus):**
  - Работает последовательно — quality gate перед merge
  - Проверяет код, мержит через PR (не локальный merge):
    - `gh pr create` из task/beads-xxx в main
    - `gh pr merge --squash` после проверки
    - GitHub гарантирует атомарность, при падении PR остаётся open
  - После merge — cleanup веток:
    - `git push origin --delete task/beads-xxx`
    - `git branch -d task/beads-xxx`
  - Merge conflict — сам решает, максимум эскалирует к Architect
  - Если код плохой — НЕ закрывает задачу, возвращает в `bd ready` (меняет статус, обновляет description с причиной)

- ✅ **Тестирование:** Architect включает тесты в задачу. "Сделай X + напиши тест" — Executor видит это в `done_when`.

- ✅ **Старт системы (гибрид):**
  - Если SPEC.md есть → Manager сразу к Architect
  - Если SPEC.md нет → Manager запускает Tech Writer
  - Tech Writer задаёт вопросы → формирует SPEC.md → потом Architect

- ✅ **Финиш системы:**
  - Manager проверяет: `bd list --status=open` = 0 (все задачи closed)
  - Если да → фаза DONE, уведомление в логе
  - Учитываются ВСЕ задачи, включая добавленные Analysts

- ✅ **Взаимодействие с пользователем:**
  - Terminal prompt (stdin/stdout)
  - Интерактивный процесс — вопрос → ответ → возможны уточнения
  - Система паузит пока не получит ответ

- ✅ **MVP scope:** Tech Writer спрашивает "что минимум нужно для запуска?"

- ✅ **Стек и язык:** Architect выбирает, если не указано в ТЗ на этапе Tech Writer

- ✅ **CI/CD — опционально (GitHub Actions):**
  - **CI есть:** Senior Executor после merge ждёт CI (`gh run watch`), CI failed → bug issue
  - **CI нет:** Senior Executor проверяет только код + тесты локально
  - **CD есть:** релиз через `gh release create`
  - **CD нет:** релиз = merge в main + git tag

- ✅ **Параллельность Executors:**
  - Переменная `MAX_PARALLEL_EXECUTORS` (default: 3)
  - Architect может переопределить в SPEC.md если нужно больше/меньше

- ✅ **Бюджет:**
  - Рассчитано на подписку MAX ($200/мес)
  - ~2.5-3M токенов на итерацию — укладываемся с запасом
  - Логируем расход для анализа (в будущем)

- ✅ **Quality gate (Senior Executor проверяет):**
  - Код ревью (обязательно)
  - Тесты проходят (обязательно, локально)
  - Линтинг (если настроен)
  - Покрытие не упало (если настроено)
  - CI green (если CI настроен)
  - Сборка артефактов (если CD настроен)

- ✅ **Логирование (детально):**

  **Структура:**
  - Основной лог: `logs/claudev.log` — всё в одном месте для отладки
  - Ротация по итерации: `mv logs/claudev.log logs/archive/iteration-N.log` (атомарно)
  - Race condition safe: `log.sh` использует `>>` (append), создаёт новый файл если старый перемещён

  **Формат (plaintext, человекочитаемый):**
  ```
  2026-01-23 15:30:45 [AGENT] EVENT: описание
  2026-01-23 15:30:45 [MANAGER] PHASE: IMPLEMENTATION
  2026-01-23 15:30:46 [EXECUTOR] TASK_START: claudev-abc "Добавить кнопку"
  2026-01-23 15:35:12 [EXECUTOR] TASK_DONE: claudev-abc
  2026-01-23 15:35:13 [EXECUTOR] ERROR: git push failed - remote rejected
  ```

  **Что логируется (обязательно):**
  - Старт/финиш каждого агента
  - Переходы между фазами (INIT → PLANNING → ...)
  - Задачи: взял (TASK_START), завершил (TASK_DONE), вернул (TASK_RETURNED)
  - Git операции: commit, merge, revert, push
  - Все ошибки с контекстом (ERROR: что случилось)
  - Решения агентов (DECISION: почему выбрал X)

  **Что логируется (опционально, для анализа расхода):**
  - Токены: `TOKENS: input=1234 output=567 total=1801`
  - Включается через `config.yaml: log_tokens: true`

  **Хелпер для агентов:**
  ```bash
  # core/scripts/log.sh
  log() {
    local agent=$1 event=$2 message=$3
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$agent] $event: $message" >> logs/claudev.log
  }
  # Использование: log "MANAGER" "PHASE" "IMPLEMENTATION"
  ```

  **Безопасность логов:**
  - НИКОГДА не логировать: пароли, токены API, содержимое .env
  - Логировать только ID задач, не полное содержимое

- ✅ **Релизный процесс (после итерации):**
  - Manager видит: все задачи closed (+ CI green если CI настроен)
  - Определяется тип версии: bugfix→patch, feature→minor, breaking→major
  - Обновляется version в package.json / mix.exs / etc.
  - Генерируется CHANGELOG.md из closed задач итерации
  - Создаётся git tag
  - **Если CD настроен:** `gh release create` с артефактами
  - **Если CD нет:** итерация завершена, tag в main

- ✅ **Secrets и безопасность (средний уровень):**
  - `.gitignore`: .env, .env.*, *.pem, *.key, credentials.*, secrets/
  - Pre-commit hook: `gitleaks protect --staged` (install.sh добавляет)
  - Для тестов — mocks, не реальные API
  - CI использует GitHub Secrets (агенты их не видят)
  - Инструкция агентам: "НИКОГДА не читай .env, не логируй secrets, не пиши secrets в beads"
  - Senior Executor проверяет diff на паттерны: sk-, api_key=, password=
  - **Остаточный риск:** агент технически может прочитать .env — митигируем инструкциями
  - **Pre-commit hook fail:** не пропускаем, считаем как обычный fail → retry → эскалация к Architect

- ✅ **Merge conflicts:**
  - Простой конфликт (разные места) — Senior Executor решает сам
  - Семантический (одна функция) — откладывает merge, создаёт задачу для Architect
  - Architect решает: переписать или объединить

- ✅ **Rollback при проблемах после merge:**
  - **Если CI есть и упал:** Senior Executor делает `git revert`, задача → open с "CI failed: [error]"
  - **Если CI нет:** Senior Executor проверяет тесты локально ДО merge, rollback не нужен
  - Executor получает задачу снова с контекстом ошибки

- ✅ **User silence (таймаут 30 мин):**
  - Tech Writer сохраняет draft, завершается
  - При следующем запуске: Manager автоматически показывает незакрытый вопрос user'у

- ✅ **Кто делает релиз:** Senior Executor
  - Логичное продолжение: проверил → замержил → CI passed → релиз

- ✅ **Статусы задач в beads:**
  - `open` → задача создана, ждёт исполнителя
  - `in_progress` → Executor работает (через `bd update --claim`)
  - `in_progress` + label `needs-review` → Executor закончил, ждёт Senior Executor
  - `closed` → Senior Executor замержил, CI passed
  - `open` (возврат) → CI failed после merge, задача вернулась с ошибкой в notes

- ✅ **Конфигурация проекта:**
  - **Bootstrap:** install.sh копирует `templates/config.template.yaml` → `.claudev/config.yaml`
  - Tech Writer может обновить config если user хочет CI/CD
  - Система стартует с defaults, не блокируется на отсутствии конфига
  - Defaults:
    ```yaml
    ci: false
    cd: false
    max_parallel_executors: 3
    timeouts:
      task: 10m
      user_input: 30m
    retry_limit: 3
    log_tokens: false
    cleanup:
      enabled: false    # по умолчанию храним всё
      keep_days: 30     # если enabled: удаляем старше 30 дней
    ```
  - **Cleanup** (если enabled): `find logs/archive stats -mtime +$KEEP_DAYS -delete`

- ✅ **Приоритет задач:**
  - `bd ready` сортирует по приоритету (P0 → P4)
  - Executor берёт первую из списка
  - Manager НЕ назначает задачи — избыточно

- ✅ **Атомарный claim задачи:** (проверено в bd CLI)
  - Executor использует `bd update <id> --claim`
  - Beads гарантирует атомарность (fails if already claimed)
  - Если занято — Executor берёт следующую задачу
  - Race condition между параллельными Executors невозможен

- ✅ **Лимит эскалаций исчерпан:**
  - После 2 эскалаций → задача получает label `blocked:escalation-limit`
  - В `notes` задачи — полная история: что пробовали, почему не получилось
  - Зависимое дерево автоматически блокируется (через deps)
  - Система продолжает работать по независимым задачам
  - В финальном отчёте — секция "Blocked tasks" с объяснениями

- ✅ **Лимит времени итерации:**
  - Жёсткого лимита нет — большой проект может легитимно занять много часов
  - Лимиты через retry/эскалации уже защищают от зависания
  - **Мониторинг:**
    - Каждые 2h: `log "ORCHESTRATOR" "INFO" "Iteration running for Xh, Y tasks remaining"`
    - Если ВСЕ оставшиеся задачи blocked: `log "ORCHESTRATOR" "WARN" "All remaining tasks blocked, stopping"` → система останавливается
  - User может посмотреть лог и остановить вручную если нужно

- ✅ **Circular dependencies:**
  - Architect после создания задач запускает `bd dep cycles`
  - Если есть циклы — исправляет сам
  - Manager перепроверяет перед переходом в IMPLEMENTATION (safety net)

- ✅ **Senior Executor — последовательный by design:**
  - Quality gate перед main — параллелить нельзя (race conditions, конфликты)
  - Очередь PR = система работает быстрее чем можем безопасно мержить
  - Bottleneck здесь — фича, не баг

- ✅ **Tech Writer — подход к SPEC.md:**
  - SPEC.md — результат диалога, не заполнение шаблона
  - Tech Writer адаптируется под клиента, а не наоборот
  - **Если Architect не понимает SPEC.md:**
    - Создаёт задачу: `bd create --title="Clarify SPEC.md: <что непонятно>" --type=task --priority=0`
    - Логирует и завершает работу
    - Manager видит P0 → запускает Tech Writer
    - Tech Writer читает reason, задаёт user уточняющий вопрос
  - **Поведение:**
    - Слушает что хочет клиент
    - Задаёт уточняющие вопросы по неясным местам
    - Предлагает популярные решения если клиент не знает:
      - "Обычно для такого используют PostgreSQL, подойдёт?"
      - "Для авторизации чаще всего JWT или сессии. Вам важна разница?"
    - Не требует ответа на всё — неопределённое отдаёт Architect
  - **Валидация перед передачей Architect:**
    - Не "есть ли секция X", а:
      - Понятно ЧТО система должна делать?
      - Понятно ДЛЯ КОГО?
      - Понятно что МИНИМУМ нужно для первого релиза?
    - Если да — структурирует и передаёт
  - **Результат:** Architect получает хорошо структурированную суть, не формальный документ

- ✅ **Beads daemon down:**
  - Система падает, пишет user
  - Не пытаемся работать без sync — это путь к потере данных
  - **Проверка:** Orchestrator вызывает `bd sync --status`
    - При старте (обязательно)
    - В цикле каждые 10 итераций (не каждый раз, чтобы не замедлять)
  - При падении: `log "ORCHESTRATOR" "FATAL" "Beads daemon not running"` + exit 1

- ✅ **Single instance (lock file):**
  - Orchestrator при старте создаёт `.claudev/orchestrator.lock` с PID
  - Если lock есть и процесс жив (`kill -0`) → exit "already running"
  - Если lock от мёртвого процесса → stale lock, удаляем и продолжаем
  - `trap "rm -f .claudev/orchestrator.lock" EXIT` для cleanup
  - **Stale lock recovery** (при SIGKILL trap не срабатывает):
    ```bash
    if [ -f "$LOCK_FILE" ]; then
        OLD_PID=$(cat "$LOCK_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo "Orchestrator already running (PID $OLD_PID)"; exit 1
        else
            echo "Removing stale lock file"; rm -f "$LOCK_FILE"
        fi
    fi
    ```

- ✅ **Merge conflicts (промпт Senior Executor):**
  - Мержить по приоритету задач (P0 первым)
  - Pull перед каждым merge (свежий main)
  - Простой конфликт (разные файлы/места) — решает сам
  - Семантический конфликт (один кусок кода) — откладывает merge, создаёт задачу для Architect

- ✅ **Подписка и статистика:**
  - Используем Claude Code Max 20x
  - Таймаутов достаточно для защиты от зависаний
  - После итерации генерируется `stats/iteration-N.yaml`:
    ```yaml
    tokens:
      total: 125000
      by_role:
        manager: 5000
        tech_writer: 15000
        architect: 25000
        analysts: 30000
        executors: 40000
        senior_executor: 10000
    tasks:
      total: 24
      completed: 22
      blocked: 2
    time:
      start: 2026-01-23T10:00:00
      end: 2026-01-23T12:30:00
    ```

- ✅ **Завершение фазы HELPERS (analysts):**
  - Manager перед запуском создаёт 5 задач-триггеров:
    - `run-analyst-ux`, `run-analyst-security`, `run-analyst-ops`, `run-analyst-reliability`, `run-analyst-architecture`
  - Запускает 5 агентов параллельно через `timeout 10m`
  - Каждый analyst: claim своей задачи → работа → close
  - Manager проверяет: все 5 closed → переход в PLAN_REVIEW
  - **Timeout handling:**
    - `timeout` убивает зависший процесс
    - Задача-триггер остаётся open (analyst не успел close)
    - Manager в следующем цикле видит: "4 closed, 1 open" → перезапускает только зависшего
    - Retry counter в notes задачи-триггера
    - После 3 retry → эскалация к Architect

- ✅ **Фаза PLAN_REVIEW:**
  - Analysts создают задачи БЕЗ dependencies (только `--label=added-by:analyst-*`)
  - Architect в PLAN_REVIEW расставляет deps для новых задач
  - Manager создаёт задачу-триггер `run-plan-review`
  - Architect:
    1. Claim `run-plan-review`
    2. Находит задачи: `bd list --label=added-by:analyst-*`
    3. Убирает дубликаты: `bd close <id> --reason="Дубликат claudev-xxx"`
    4. Разрешает противоречия: `bd close <id> --reason="Противоречит Security: ..."`
    5. Close `run-plan-review`
  - Manager видит closed → переход в IMPLEMENTATION

- ✅ **Коммиты Executor:**
  - Один коммит в конце работы (перед close задачи)
  - Задачи короткие (1-5 мин), потеря при падении = перезапуск
  - Retry 3x покрывает случайные падения
  - Не усложняем промежуточными коммитами

- ✅ **Rebase перед push (Executor):**
  - Перед push Executor делает:
    ```bash
    git fetch origin main
    git rebase origin/main
    git push --force-with-lease -u origin task/beads-xxx
    ```
  - `--force-with-lease` — безопасно перезаписывает личную ветку при retry
  - Простой конфликт (разные файлы) — решает сам
  - Сложный конфликт (семантический) — эскалация к Architect
  - Senior Executor получает уже актуальные ветки

- ✅ **Идемпотентность агентов (git/gh ошибки):**
  - **Общее правило для ВСЕХ агентов:**
    - При ошибке git/gh команды: логируем, НЕ меняем статус задачи, завершаем работу
    - Manager перезапустит в следующем цикле
    - Агент должен быть идемпотентным — повторный запуск даёт тот же результат
  - **Executor при старте (идемпотентность):**
    ```bash
    git fetch origin
    git branch -D task/beads-xxx 2>/dev/null  # удаляем локальную если есть
    git checkout -b task/beads-xxx origin/main
    ```
  - **Потеря при падении:** максимум 1-5 минут работы (задачи короткие) — приемлемо

- ✅ **Фаза FINAL_REVIEW:**
  - Architect проверяет целостность результата перед релизом
  - Не дублирует Senior Executor (тот проверяет каждый PR отдельно)
  - **Что проверяет:**
    - Все features из SPEC.md реализованы?
    - Архитектура соответствует изначальному плану?
    - Нет пропущенных edge cases?
  - **Если всё ок:** подтверждает готовность → переход в DONE
  - **Если проблемы:** создаёт задачи на доработку → обратно в IMPLEMENTATION

- ✅ **Запуск агентов (формат команды):**
  ```bash
  # Статичный промпт + динамический контекст
  timeout 10m claude --model sonnet --print << EOF
  $(cat .claude/agents/manager.md)

  ---
  PROJECT_ROOT: $(pwd)
  CURRENT_PHASE: $(./scripts/detect-phase.sh)
  EOF
  ```
  - Промпт агента — файл (версионируется, редактируется)
  - Контекст — добавляется в конце через heredoc
  - `--print` — результат в stdout для логирования
  - Для Executor: добавляется `TASK_ID` и `TASK: $(bd show $TASK_ID --format=yaml)`

- ✅ **Модель для Executor:**
  - Architect назначает через label: `model:haiku`, `model:sonnet`, `model:opus`
  - run-executors.sh парсит: `bd show $TASK_ID --format=json | jq ...`
  - Если label нет → default `sonnet`

- ✅ **Интерактивность vs цикл orchestrator:**
  - **INIT фаза** (Tech Writer) — интерактивный режим, без timeout, stdin/stdout напрямую
  - **Остальные фазы** — автономный режим, с timeout, параллельные агенты
  - Orchestrator умеет работать в обоих режимах (switch по фазе)
  - User silence 30min — внутри Tech Writer (сам следит, завершается с draft)

- ✅ **install.sh (cold start, recovery):**
  - Git нет → `git init` автоматически
  - Remote нет → спрашивает: добавить URL или работать локально
  - Beads CLI нет → ошибка с инструкцией (не можем установить за пользователя)
  - Beads не инициализирован → `bd init` автоматически
  - Атомарность: собираем во temp dir, потом move
  - Идемпотентность: повторный запуск безопасен

- ✅ **Graceful shutdown:**
  - `trap cleanup SIGINT SIGTERM` в orchestrator
  - cleanup: SIGTERM детям → ждём 10s → SIGKILL если завис → rm lock
  - Задачи `in_progress` остаются — это ОК
  - При старте orchestrator сбрасывает все `in_progress` → `open` с notes "Reset: orchestrator restart"
  - Идемпотентность агентов покрывает повторный запуск

---

## Архитектурные решения

**Контекст:** Перед стартом реализации прогнали архитектурный чеклист (failure modes, bottlenecks, data flow, edge cases) и закрыли все найденные пробелы.

### 1. Draft Tech Writer — привязка к задаче

**Проблема:** User тайм-аут, Tech Writer должен сохранить draft и завершиться. Но как продолжить при возврате?

**Решение:** `SPEC.draft.md` + путь в notes задачи

**Workflow:**
```bash
# Tech Writer при timeout:
echo "..." > SPEC.draft.md
bd update <task-id> --notes="Draft saved: SPEC.draft.md. Awaiting user input."
bd close <task-id>

# Manager следующая итерация:
if [ -f SPEC.draft.md ] && user_active; then
  bd create --title="Finalize SPEC from draft + user input" --type=task
fi
```

**Чеклист:**
- ✅ Failure: Tech Writer упал → draft в файле + notes указывает путь
- ✅ Data flow: draft → notes → Manager → new task
- ✅ Edge case: User удалил draft → новый Tech Writer начинает с нуля
- ✅ LLM-friendly: простые команды, явный маркер (файл + notes)

---

### 2. Iteration numbering — timestamp вместо счётчика

**Проблема:** `iteration.txt` с инкрементом → crash между инкрементом и архивацией → сломанная нумерация

**Решение:** timestamp в имени файла, никакого state file

**Workflow:**
```bash
mv logs/current.log "logs/archive/iteration-$(date +%Y%m%d-%H%M%S).log"
```

**Чеклист:**
- ✅ Failure: crash в любой момент → ничего не сломается, timestamp уникален
- ✅ Bottleneck: нет state file = нет race conditions
- ✅ Data flow: одна операция, атомарная
- ✅ Edge case: два mv одновременно (невозможно, orchestrator один) → разные timestamps
- ✅ LLM-friendly: одна команда, без арифметики

---

### 3. Cleanup — раз в сутки по timestamp

**Проблема:** cleanup при каждом старте orchestrator (iteration_delay=5min) → избыточные проверки ФС

**Решение:** `.claudev/last_cleanup.txt` с timestamp, проверка раз в 24h

**Workflow:**
```bash
LAST=$(cat .claudev/last_cleanup.txt 2>/dev/null || echo 0)
NOW=$(date +%s)
if [ $((NOW - LAST)) -gt 86400 ]; then  # 24 hours
  find logs/archive -mtime +$KEEP_DAYS -delete
  echo $NOW > .claudev/last_cleanup.txt
fi
```

**Чеклист:**
- ✅ Failure: cleanup упал → last_cleanup.txt не обновился → попробует снова (OK)
- ✅ Bottleneck: проверка раз в сутки, не каждые 5 минут
- ✅ LLM-friendly: простая проверка, один state file

---

### 4. Stats tokens — оценка по размеру

**Проблема:** Claude Code не даёт детальную токен-статистику через API

**Решение:** считаем chars, оцениваем tokens как `chars / 4`

**Workflow:**
```bash
INPUT_CHARS=$(wc -c < prompts/architect.md)
OUTPUT_CHARS=$(wc -c < output.log)
ESTIMATED_TOKENS=$(( (INPUT_CHARS + OUTPUT_CHARS) / 4 ))

cat > stats/iteration-$TIMESTAMP.yaml <<EOF
iteration_timestamp: "$TIMESTAMP"
agents_run: 12
tasks_completed: 8
estimated_input_chars: $INPUT_CHARS
estimated_output_chars: $OUTPUT_CHARS
estimated_tokens: $ESTIMATED_TOKENS
EOF
```

**Чеклист:**
- ✅ Data flow: chars → оценка токенов (approximation лучше чем ничего)
- ✅ LLM-friendly: простая математика
- ✅ Future-proof: можно уточнить парсингом логов позже

---

### 5. Release timing — review+release одной задачей

**Проблема:** Release как отдельная задача → review failed → висячая release task

**Решение:** Senior Executor (Reviewer) делает review И release в одной задаче

**Workflow:**
```bash
# Manager → FINAL_REVIEW:
bd create --title="Review & Release" --type=task --assignee=senior-executor

# Senior Executor:
# 1. Review code
# 2. If PASS:
gh pr create && gh pr merge
bd close <task> --notes="Reviewed & released"
# 3. If FAIL:
bd create <tasks for fixes>
bd close <task> --notes="Review failed, fixes created"
# Manager sees fail → phase back to IMPLEMENTATION
```

**Чеклист:**
- ✅ Failure: review failed → нет висячей release task
- ✅ Edge case: нет промежуточного состояния
- ✅ LLM-friendly: одна задача = review + conditional release
- ✅ Изоляция: Senior Executor владеет всем процессом

---

### 6. PR workflow — fail hard без remote

**Проблема:** Local merge без PR = no code review, опасно автоматизировать

**Решение:** если нет GitHub remote → error, остановка, ждём User

**Workflow:**
```bash
if ! git remote -v | grep -q github; then
  log "ERROR: No GitHub remote. Cannot auto-release. Manual action required."
  exit 1
fi

gh pr create && gh pr merge
```

**Чеклист:**
- ✅ Edge case: локальный проект → явная ошибка, не silent fail
- ✅ Safety: не делаем то что может быть опасным (local merge без review)
- ✅ LLM-friendly: простая проверка

---

### 7. Config reload — каждую итерацию

**Проблема:** config read только при старте → срочные изменения применяются через iteration_delay (может быть 30+ минут)

**Решение:** orchestrator читает config в начале каждой итерации

**Workflow:**
```bash
while true; do
  source .claudev/config.yaml  # read fresh config
  log "Iteration started with config: iteration_delay=$ITERATION_DELAY"

  detect_phase
  run_agents

  sleep $ITERATION_DELAY
done
```

**Чеклист:**
- ✅ Data flow: config → iteration start → применяется сразу
- ✅ Предсказуемость: изменения применяются максимум через iteration_delay
- ✅ Edge case: срочные изменения → User останавливает orchestrator и перезапускает
- ✅ LLM-friendly: одна команда `source`

---

### 8. GitHub remote — early detection + graceful degradation

**Проблема:** Если нет GitHub remote → система работает до Senior Executor → падает при merge

**Решение:** Проверка в начале (Manager INIT) + локальный merge как fallback

**Workflow:**
```bash
# Manager при первом запуске (INIT фаза):
if ! git remote -v | grep -q github; then
  log "WARN" "No GitHub remote detected. Final merge will require manual action."
  bd create --title="Setup GitHub remote for automated PR workflow" \
    --type=task --priority=4 --label=optional
fi

# Senior Executor при merge:
if ! git remote -v | grep -q github; then
  log "INFO" "No GitHub remote. Performing local merge (no PR review)."
  git checkout main
  git merge --no-ff task/beads-$TASK_ID
  git push || log "WARN" "Cannot push to remote. Manual push required."
else
  gh pr create && gh pr merge
fi
```

**Чеклист:**
- ✅ Failure: User узнаёт о проблеме в начале, не в конце
- ✅ Edge case: локальные проекты работают (merge без PR)
- ✅ LLM-friendly: простая проверка + if/else
- ✅ Safety: опциональная задача P4 для настройки remote

---

### 9. Executor rebase conflicts — всегда эскалировать

**Проблема:** LLM плохо классифицирует "простой vs сложный" конфликт → риск неправильного разрешения

**Решение:** Любой rebase conflict → abort + эскалация к Architect

**Workflow:**
```bash
# Executor при rebase:
git fetch origin main
git rebase origin/main

if [ $? -ne 0 ]; then
  git rebase --abort
  log "WARN" "Rebase conflict detected, escalating to Architect"

  bd update $TASK_ID --status=open \
    --notes="Rebase conflict with main. Files: $(git diff --name-only origin/main...HEAD)"

  bd create --title="Resolve conflict: $TASK_TITLE" \
    --type=task --priority=0 --assignee=architect

  exit 0  # Штатная эскалация, не ошибка
fi

git push --force-with-lease -u origin task/beads-$TASK_ID
```

**Чеклист:**
- ✅ Failure: Executor не принимает решения о конфликтах (меньше риска)
- ✅ LLM-friendly: простейшая логика (failed? → abort + escalate)
- ✅ Safety: Architect (Opus) с полным контекстом разрешает любой конфликт
- ✅ Data flow: конфликт → open task → P0 для Architect

---

### 10. Stats tokens — измерять input, оценивать output

**Проблема:** Claude Code output в stdout смешан с системными сообщениями → сложно парсить точно

**Решение:** Измерять input chars, оценивать output (~50% от input), считать tokens через `/4`

**Workflow:**
```bash
# Orchestrator при запуске агента:
run_agent() {
  local agent=$1 model=$2 task_id=$3

  # Формируем промпт во temp файл
  local prompt_file=".claudev/prompts/${agent}-${task_id}.txt"
  cat ".claude/agents/${agent}.md" > "$prompt_file"
  echo -e "\n---\nTASK_ID: $task_id\n..." >> "$prompt_file"

  # Считаем input
  local input_chars=$(wc -c < "$prompt_file")

  # Запускаем (output в общий лог)
  {
    echo "=== AGENT START: $agent (task: $task_id) ==="
    timeout 10m claude --model $model --print < "$prompt_file"
    echo "=== AGENT END: $agent ==="
  } | tee -a logs/claudev.log

  # Логируем stats
  log "STATS" "RUN" "agent=$agent model=$model input_chars=$input_chars task=$task_id"

  rm "$prompt_file"
}

# Stats script (конец итерации):
grep "STATS.*RUN" logs/claudev.log | \
  awk '{
    for(i=1;i<=NF;i++) {
      if($i ~ /input_chars=/) {
        split($i,a,"="); total += a[2]
      }
    }
  } END {
    estimated_output = total * 0.5
    estimated_tokens = (total + estimated_output) / 4
    print "input_chars: " total
    print "estimated_output_chars: " estimated_output
    print "estimated_tokens: " int(estimated_tokens)
  }' > stats/iteration-$(date +%Y%m%d-%H%M%S).yaml
```

**Чеклист:**
- ✅ Data flow: промпт → temp файл → измерение → запуск → cleanup
- ✅ Failure: падение агента → input залогирован (log перед запуском)
- ✅ LLM-friendly: простые команды (cat, wc, awk)
- ✅ Точность: ~60%, достаточно для планирования бюджета (не billing)

---

### 11. Orchestrator lock — atomic через noclobber (FINAL)

**Проблема:** Race condition при параллельном старте — два процесса могут создать lock file одновременно

**Решение:** Atomic file creation через `set -C` (noclobber mode)

**Workflow:**
```bash
LOCK_FILE=".claudev/orchestrator.lock"

# Atomic lock: noclobber fails если файл существует
if ! (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
    # Lock exists, check if stale
    OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "0")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Orchestrator already running (PID $OLD_PID)"
        exit 1
    else
        echo "Removing stale lock (PID $OLD_PID not found)"
        rm -f "$LOCK_FILE"
        # Retry once
        if ! (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
            echo "Failed to acquire lock (race with another process?)"
            exit 1
        fi
    fi
fi

trap "rm -f '$LOCK_FILE'" EXIT
```

**Чеклист:**
- ✅ Race condition невозможен (atomic FS operation)
- ✅ Stale lock detection (kill -0 проверка)
- ✅ Graceful cleanup (trap EXIT)
- ✅ LLM-friendly: простая логика

---

### 12. Config — bash напрямую (FINAL)

**Проблема:** YAML parsing сложен, race conditions с timestamp, нужна синхронизация

**Решение:** Отказ от YAML, config.sh напрямую (bash syntax)

**Workflow:**
```bash
# .claudev/config.sh (User редактирует напрямую)
CI_ENABLED=false
CD_ENABLED=false
MAX_PARALLEL_EXECUTORS=3
TASK_TIMEOUT="10m"
USER_INPUT_TIMEOUT="30m"
RETRY_LIMIT=3
LOG_TOKENS=false
CLEANUP_ENABLED=false
CLEANUP_KEEP_DAYS=30

# Orchestrator просто source:
source .claudev/config.sh
```

**Чеклист:**
- ✅ Нет парсинга (меньше кода, меньше багов)
- ✅ Нет race conditions (атомарный read)
- ✅ User-friendly (bash синтаксис простой, комментарии в файле)
- ✅ Reload каждую итерацию без доп. логики

---

### 13. GitHub check — через gh CLI с fallback (FINAL)

**Проблема:** `grep github` не ловит enterprise/custom domains, что если gh CLI не установлен?

**Решение:** Проверка через gh CLI + graceful fallback к local merge

**Workflow:**
```bash
# Хелпер для проверки
check_github_pr_available() {
    command -v gh &>/dev/null && gh auth status &>/dev/null
}

# Senior Executor при merge:
if check_github_pr_available; then
    gh pr create --fill
    gh pr merge --squash --auto
else
    log "INFO" "No gh CLI or not authenticated, performing local merge"
    git checkout main
    git merge --no-ff "task/beads-$TASK_ID"
    git push 2>/dev/null || log "WARN" "Cannot push (no remote or no access)"
fi
```

**Чеклист:**
- ✅ Ловит любые варианты GitHub (enterprise, custom)
- ✅ Проверяет наличие gh CLI + авторизацию
- ✅ Graceful degradation (local merge если gh недоступен)
- ✅ LLM-friendly: простая функция-хелпер

---

### 14. Beads daemon — проверка каждую итерацию (FINAL)

**Проблема:** Редкая проверка (каждые 10 итераций) → daemon упал → работаем без sync → data loss

**Решение:** Проверка в начале КАЖДОЙ итерации (дёшево, критично)

**Workflow:**
```bash
while true; do
    # 1. Check daemon (fast, ~10-50ms)
    if ! bd sync --status &>/dev/null; then
        log "FATAL" "Beads daemon not running. Run: bd daemon start"
        exit 1
    fi

    # 2. Load config
    source .claudev/config.sh

    # 3. Detect phase & run agents
    ...

    sleep "$ITERATION_DELAY"
done
```

**Чеклист:**
- ✅ Fail fast (защита от data loss)
- ✅ Дёшево (~10-50ms overhead)
- ✅ Критично (sync обязателен для корректности)

---

### 15. Executor rebase — WIP commit для сохранности (FINAL)

**Проблема:** Conflict → abort → вся работа потеряна (задачи маленькие, но гарантия не помешает)

**Решение:** WIP commit перед rebase + squash в конце (clean history)

**Workflow:**
```bash
# 1. WIP commit (сохраняем работу)
git add -A
git commit -m "WIP: task-$TASK_ID (pre-rebase)"

# 2. Rebase
git fetch origin main
if ! git rebase origin/main; then
    # Conflict detected
    git rebase --abort

    log "WARN" "Rebase conflict, escalating to Architect"

    # Работа сохранена в WIP commit, можно push
    git push --force-with-lease -u origin "task/beads-$TASK_ID"

    # Эскалация
    bd create --title="Resolve rebase conflict: $TASK_TITLE" \
        --type=task --priority=0 --assignee=architect \
        --notes="Branch: task/beads-$TASK_ID, conflicts with main"

    bd update "$TASK_ID" --status=blocked --label=needs-rebase
    exit 0
fi

# 3. Squash WIP commit (clean history)
git reset --soft HEAD~1
git commit -m "$COMMIT_MESSAGE"
git push --force-with-lease -u origin "task/beads-$TASK_ID"

bd update "$TASK_ID" --label=needs-review
```

**Чеклист:**
- ✅ Работа НИКОГДА не теряется (WIP commit)
- ✅ Clean history в итоге (squash перед push)
- ✅ Architect получает ветку с работой
- ✅ Не усложняет (~5 строк кода)

---

### 16. Executors backpressure — лимит open PR (FINAL)

**Проблема:** Executors создают PR быстрее чем Senior Executor мержит → очередь растёт бесконечно

**Решение:** Queue limit через MAX_PARALLEL_EXECUTORS

**Workflow:**
```bash
# run-executors.sh перед запуском:
OPEN_PRS=$(gh pr list --state open --json number --jq 'length' 2>/dev/null || echo 0)

if [ "$OPEN_PRS" -ge "$MAX_PARALLEL_EXECUTORS" ]; then
    log "INFO" "PR queue full ($OPEN_PRS/$MAX_PARALLEL_EXECUTORS), waiting"
    exit 0
fi

# Иначе запускаем новых Executors
...
```

**Чеклист:**
- ✅ Natural flow control (Senior Executor мержит → слот освобождается)
- ✅ Bottleneck управляется автоматически
- ✅ LLM-friendly: простая проверка

---

### 17. Stats tokens — простая оценка для статистики (FINAL)

**Проблема:** Claude Code не даёт точную токен-статистику, нужна хотя бы оценка

**Решение:** Простой подсчёт chars → tokens (для info, не для billing)

**Workflow:**
```bash
# Orchestrator при запуске агента:
run_agent() {
    local prompt_file=".claudev/prompts/${agent}-${task_id}.txt"

    # Формируем промпт
    cat ".claude/agents/${agent}.md" > "$prompt_file"
    echo -e "\n---\nTASK_ID: $task_id\n..." >> "$prompt_file"

    # Считаем input
    local input_chars=$(wc -c < "$prompt_file")
    local estimated_tokens=$((input_chars / 4))

    # Запускаем
    timeout 10m claude --model $model --print < "$prompt_file" | tee -a logs/claudev.log

    # Логируем stats
    echo "$agent,$input_chars,$estimated_tokens" >> stats/current-iteration.csv

    rm "$prompt_file"
}
```

**Чеклист:**
- ✅ Простая оценка (примерная, но достаточно)
- ✅ CSV для постобработки
- ✅ LLM-friendly: одна команда wc

---

### 18. Graceful shutdown — smart reset (5min threshold) (FINAL)

**Проблема:** Сбрасываем все `in_progress` → дублирование работы если агент успел close но мы не увидели

**Решение:** Reset только старых задач (>5min), свежие оставляем

**Workflow:**
```bash
cleanup() {
    log "INFO" "Shutting down gracefully..."

    # SIGTERM детям (даём время завершиться)
    pkill -P $$ -TERM
    sleep 5
    pkill -P $$ -KILL 2>/dev/null

    # Reset только старых задач (>5min in_progress)
    for task_id in $(bd list --status=in_progress --format=json | jq -r '.[].id'); do
        claimed_ts=$(bd show "$task_id" --format=json | jq -r '.updated_at')
        claimed_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$claimed_ts" +%s 2>/dev/null || date -d "$claimed_ts" +%s)
        now_epoch=$(date +%s)
        age=$((now_epoch - claimed_epoch))

        if [ "$age" -gt 300 ]; then  # 5 minutes
            log "INFO" "Resetting stale task $task_id (age: ${age}s)"
            bd update "$task_id" --status=open --notes="Reset: stale at shutdown (${age}s old)"
        else
            log "INFO" "Keeping recent task $task_id (age: ${age}s)"
        fi
    done

    rm -f "$LOCK_FILE"
    exit 0
}

trap cleanup SIGINT SIGTERM
```

**Чеклист:**
- ✅ Свежие задачи (<5min) не трогаем
- ✅ Старые задачи (>5min) сбрасываем
- ✅ Minimal duplication

---

### 19. Tech Writer draft — TTL 24h (FINAL)

**Проблема:** Draft устаревает (user вернулся через 2 недели), но Manager пытается продолжить

**Решение:** TTL 24h + архивация старых drafts

**Workflow:**
```bash
# Manager при INIT фазе:
if [ -f SPEC.draft.md ]; then
    draft_age=$(( $(date +%s) - $(stat -f %m SPEC.draft.md 2>/dev/null || stat -c %Y SPEC.draft.md) ))

    if [ "$draft_age" -gt 86400 ]; then
        # Draft >24h old
        log "INFO" "Found old draft (${draft_age}s old), archiving"
        mv SPEC.draft.md "SPEC.draft.$(date +%Y%m%d).old"

        # Start fresh
        bd create --title="Gather requirements (fresh start)" \
            --type=task --assignee=tech-writer --priority=0
    else
        # Draft fresh, continue
        bd create --title="Finalize SPEC from draft" \
            --type=task --assignee=tech-writer --priority=0 \
            --notes="Continue from SPEC.draft.md"
    fi
fi
```

**Чеклист:**
- ✅ 24h TTL (разумный баланс)
- ✅ Старый draft архивируется (не теряется)
- ✅ User видит что началось заново

---

### 20. Circular dependencies — check после каждого add (FINAL)

**Проблема:** Architect добавляет deps пачкой → цикл обнаруживается поздно, сложно откатить

**Решение:** Инструкция в промпте — проверка после КАЖДОЙ зависимости

**Промпт Architect (секция dependencies):**
```markdown
## Добавление зависимостей

**КРИТИЧНО:** Проверяй cycles ПОСЛЕ КАЖДОЙ зависимости:

```bash
# Для каждой пары:
bd dep add <task-id> <depends-on-id>

# СРАЗУ проверяем
if bd dep cycles 2>&1 | grep -q "cycle"; then
    echo "ERROR: Cycle detected with last dependency"
    bd dep remove <task-id> <depends-on-id>
    # Пересмотри dependency graph
fi
```

**Если cycles detection failed после всех deps:**
1. Выведи граф: `bd dep graph`
2. Найди цикл вручную
3. Удали одну зависимость из цикла
4. Залогируй: почему удалил именно эту
```

**Чеклист:**
- ✅ Обнаруживаем цикл сразу (easy rollback)
- ✅ Architect знает какая зависимость создала проблему
- ✅ LLM-friendly (простая инструкция)

---

### 21. Iteration lock concept — одна итерация за раз (FINAL)

**Проблема:** Timestamp collision в logs, параллельные итерации могут сломать состояние

**Решение:** Концептуально: одна итерация = один orchestrator процесс = один lock file

**Гарантии:**
- Orchestrator.lock (решение #11) уже обеспечивает единственность процесса
- Одна итерация = от старта orchestrator до фазы DONE (или stop)
- Параллельные итерации невозможны (atomic lock)
- Timestamp в logs = время архивации, не нумерация итераций

**Workflow:**
```bash
# Orchestrator lock уже защищает от параллельного запуска
# При завершении итерации (фаза DONE):
mv logs/claudev.log "logs/archive/iteration-$(date +%Y%m%d-%H%M%S).log"
mv stats/current-iteration.md "stats/iteration-$(date +%Y%m%d-%H%M%S).md"
```

**Чеклист:**
- ✅ Параллельные итерации невозможны (lock file)
- ✅ Timestamp collision невозможен (одна итерация за раз)
- ✅ Каждая итерация = один релиз

---

### 22. Stats format — Markdown вместо CSV (FINAL)

**Проблема:** CSV без header, сложно читать, нет контекста

**Решение:** Markdown report с таблицами и метриками

**Workflow:**
```bash
# stats/iteration-TIMESTAMP.md
cat > stats/iteration-$(date +%Y%m%d-%H%M%S).md <<EOF
# Iteration Report

**Started:** $(cat .claudev/iteration_start.txt)
**Completed:** $(date '+%Y-%m-%d %H:%M:%S')
**Duration:** $(calculate_duration)

## Tasks
- Total created: $(bd list --format=json | jq 'length')
- Completed: $(bd list --status=closed --format=json | jq 'length')
- Blocked: $(bd list --label=blocked --format=json | jq 'length')

## Agents Activity
| Agent | Runs | Est. tokens |
|-------|------|-------------|
$(generate_agent_stats)

## Blocked Tasks
$(bd list --label=blocked --format=json | jq -r '.[] | "- \`\(.id)\`: \(.title) (reason: \(.notes))"')
EOF
```

**Чеклист:**
- ✅ Читаемый формат (markdown)
- ✅ Контекст (время, duration, summary)
- ✅ Легко парсить для метрик (jq из json source)

---

### 23. Retry counter — label вместо notes parsing (FINAL)

**Проблема:** Retry в notes как текст → хрупкий regex parsing

**Решение:** Label `retry:N` (атомарно, легко парсить)

**Workflow:**
```bash
# Executor при первой попытке:
bd update $TASK_ID --status=in_progress --label=retry:0

# Orchestrator при retry:
CURRENT_RETRY=$(bd show $TASK_ID --format=json | jq -r '.labels[] | select(startswith("retry:")) | split(":")[1]')
NEW_RETRY=$((CURRENT_RETRY + 1))

if [ "$NEW_RETRY" -ge "$RETRY_LIMIT" ]; then
    # Эскалация к Architect
    bd create --title="Escalation: $TASK_TITLE failed after $RETRY_LIMIT retries" \
        --type=task --priority=0 --assignee=architect
    bd update $TASK_ID --label=blocked:escalation-limit
else
    # Retry
    bd update $TASK_ID --status=open --label=retry:$NEW_RETRY
fi
```

**Чеклист:**
- ✅ Атомарная операция (beads label)
- ✅ Легко парсить (jq select)
- ✅ Видно в bd list (label отображается)

---

### 24. Install.sh — dependency checker + auto-install (FINAL)

**Проблема:** Pre-commit hook fails если gitleaks нет, gh workflow fails если gh нет

**Решение:** Check all deps при install, опционально auto-install

**Workflow:**
```bash
#!/bin/bash
check_deps() {
    local missing=()

    command -v bd &>/dev/null || missing+=("beads")
    command -v gh &>/dev/null || missing+=("gh")
    command -v gitleaks &>/dev/null || missing+=("gitleaks")
    command -v claude &>/dev/null || missing+=("claude-code")

    if [ ${#missing[@]} -gt 0 ]; then
        echo "Missing dependencies: ${missing[*]}"
        echo ""
        echo "Install commands:"
        [[ " ${missing[*]} " =~ " beads " ]] && echo "  npm install -g @beadsland/beads"
        [[ " ${missing[*]} " =~ " gh " ]] && echo "  brew install gh  # or: apt install gh"
        [[ " ${missing[*]} " =~ " gitleaks " ]] && echo "  brew install gitleaks  # optional (security)"
        [[ " ${missing[*]} " =~ " claude-code " ]] && echo "  npm install -g @anthropic/claude-code"
        echo ""

        if [ "$AUTO_INSTALL" = "true" ]; then
            echo "Auto-installing npm packages..."
            [[ " ${missing[*]} " =~ " beads " ]] && npm install -g @beadsland/beads
            [[ " ${missing[*]} " =~ " claude-code " ]] && npm install -g @anthropic/claude-code
            echo "Note: gh and gitleaks require manual install (brew/apt)"
        else
            echo "Run with --auto-install to install npm packages automatically"
            exit 1
        fi
    fi
}

# Usage: ./install.sh [--auto-install]
```

**Чеклист:**
- ✅ Проверяет все критичные deps (beads, claude, gh, gitleaks)
- ✅ Показывает инструкции для установки
- ✅ Опционально auto-install npm пакетов (безопасно)
- ✅ Pre-commit hook добавляется только если gitleaks установлен

---

### 25. SPEC.draft.md cleanup — mv при финализации (FINAL)

**Проблема:** Tech Writer создаёт draft, кто удаляет после финализации?

**Решение:** Tech Writer при успешном завершении перезаписывает

**Workflow:**
```bash
# Tech Writer при timeout (30min):
cat > SPEC.draft.md <<EOF
# [WIP] Project Spec
... (что успел собрать)
EOF
bd update $TASK_ID --notes="Draft saved: SPEC.draft.md, awaiting user input"
bd close $TASK_ID

# Tech Writer при финализации (user вернулся):
# 1. Читает draft
# 2. Задаёт оставшиеся вопросы
# 3. Финализирует:
mv SPEC.draft.md SPEC.md  # Перезаписываем draft → final
bd close $TASK_ID --notes="SPEC finalized from draft"
```

**Чеклист:**
- ✅ Draft автоматически становится final (не нужен cleanup)
- ✅ TTL 24h (решение #19) для старых drafts
- ✅ Нет orphaned files

---

## Итоги финального архитектурного аудита (23-24 января 2026)

**Проведено два прохождения аудита перед началом реализации.**

### Первое прохождение (23 января): 10 угроз

**Критичные (data loss, race conditions): 4**
1. ✅ Orchestrator lock race condition → Решение #11: atomic через `set -C`
2. ✅ Config sync race condition → Решение #12: bash config напрямую (отказ от YAML)
3. ✅ Executor rebase потеря работы → Решение #15: WIP commit перед rebase
4. ✅ Graceful shutdown lost in-progress → Решение #18: smart reset (5min threshold)

**Средние (неточность, edge cases): 6**
5. ✅ GitHub remote detection fragile → Решение #13: проверка через gh CLI + fallback
6. ✅ Beads daemon check недостаточная частота → Решение #14: каждую итерацию
7. ✅ Senior Executor backpressure отсутствует → Решение #16: queue limit через MAX_PARALLEL_EXECUTORS
8. ✅ Stats tokens неточность → Решение #17: простая оценка (chars/4), достаточно для статистики
9. ✅ Tech Writer draft orphaned → Решение #19: TTL 24h + архивация
10. ✅ Circular deps false positive → Решение #20: check после каждого dep add

### Второе прохождение (24 января): 9 угроз

**Блокеры реализации (P0): 2**
1. ⚠️ Config validation отсутствует → [claudev-czh](claudev-czh) — валидация после source (РЕАЛЬНАЯ: typo → crash)
2. ⚠️ Backpressure не работает без gh CLI → [claudev-acs](claudev-acs) — счёт через beads (РЕАЛЬНАЯ: перегрузка без gh)

**Важные доработки (P1, не блокируют): 2**
3. 📋 Race: executors стартуют до PLAN_REVIEW → [claudev-ssb](claudev-ssb) — проверка run-plan-review (ТЕОРЕТИЧЕСКАЯ: маловероятно)
4. 📋 Manager cycles check нет обработки → [claudev-h03](claudev-h03) — P0 task при cycles (NICE TO HAVE: Architect уже проверяет)

**Решения при реализации: 5**
5. ✅ Iteration lock concept → Решение #21: одна итерация за раз (уже обеспечено lock file)
6. ✅ Stats format улучшение → Решение #22: Markdown вместо CSV
7. ✅ Retry counter хрупкий parsing → Решение #23: label `retry:N`
8. ✅ Install.sh missing deps → Решение #24: dependency checker + auto-install
9. ✅ SPEC.draft.md cleanup → Решение #25: mv при финализации

### Итого: 19 угроз найдено и обработано

**Из них критичных блокеров:** 2 (10%)
**Вероятность остальных проблем:** <10% (edge cases приемлемы для MVP)

**Общие принципы всех решений:**
- Следуют принципу минимальной сложности
- LLM-friendly (простые команды, чёткая логика)
- Атомарные операции где возможно
- Graceful degradation где нужно
- Fail fast на критичных проблемах

**Вывод:** После закрытия 2 P0 задач — готово к реализации. P1 задачи закрываются в процессе.

---

**Отложено на следующие итерации:**
- [ ] OS Notifications (macOS/Linux)
- [ ] Webhook уведомления (Telegram, Slack)
- [ ] Автодокументация (README, API docs)
