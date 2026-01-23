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

### Скрипты (core/scripts/)

| Скрипт | Назначение |
|--------|------------|
| orchestrator.sh | Главный цикл, пингует менеджера каждые N секунд |
| init-manager.sh | Инициализация состояния менеджера в Beads |
| claim-task.sh | Атомарный захват задачи (без race conditions) |
| detect-phase.sh | Определение текущей фазы проекта |
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
CI/CD GitHub (опционально)
```

### Управление процессом
- Manager в цикле (пока нет лучшего решения)
- Таймауты для управления падениями (задача > 10 мин = проблема)
- Beads как единственный источник правды

---

## Текущий статус

Базовая структура (набросок):
- [x] core/ — агенты, команды, скрипты
- [x] templates/ — шаблоны SPEC.md и CLAUDE.md
- [x] install.sh — установщик
- [x] docs/ — документация

**Статус:** Требуется редизайн под новые требования

**Обсуждено (22 января 2026):**
- ✅ Tech Writer — Opus, сам пишет в beads, режимы (новый/итерация)
- ✅ Manager — Sonnet, stateless, определяет фазу по beads
- ✅ Архитектура — subagents + beads, каждый агент сам пишет состояние
- ✅ Отказоустойчивость — retry 3x, эскалация к Architect, лимит 2
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
  - **КРИТИЧНО:** Захват задачи ТОЛЬКО через `bd update <id> --claim` (атомарный, fails if already claimed)

- ✅ **Senior Executor (Opus):**
  - Работает последовательно — quality gate перед merge
  - Проверяет код, мержит в main
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
  - Ротация по итерации: после релиза `claudev.log` → `logs/archive/iteration-N.log`

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
  - Tech Writer уточняет на старте: CI есть? CD нужен? Параллельность?
  - Сохраняется в `.claudev/config.yaml`
  - Defaults:
    ```yaml
    ci: false
    cd: false
    max_parallel_executors: 3
    timeouts:
      task: 10m
      user_input: 30m
    retry_limit: 3
    ```

- ✅ **Приоритет задач:**
  - `bd ready` сортирует по приоритету (P0 → P4)
  - Executor берёт первую из списка
  - Manager НЕ назначает задачи — избыточно

- ✅ **Атомарный claim задачи:**
  - Executor использует `bd update <id> --claim`
  - Beads гарантирует атомарность (fails if already claimed)
  - Если занято — Executor берёт следующую задачу

- ✅ **Лимит эскалаций исчерпан:**
  - После 2 эскалаций → задача получает label `blocked:escalation-limit`
  - В `notes` задачи — полная история: что пробовали, почему не получилось
  - Зависимое дерево автоматически блокируется (через deps)
  - Система продолжает работать по независимым задачам
  - В финальном отчёте — секция "Blocked tasks" с объяснениями

- ✅ **Circular dependencies:**
  - Architect после создания задач запускает `bd dep cycles`
  - Если есть циклы — исправляет сам
  - Manager перепроверяет перед переходом в IMPLEMENTATION (safety net)

- ✅ **Senior Executor — последовательный by design:**
  - Quality gate перед main — параллелить нельзя (race conditions, конфликты)
  - Очередь PR = система работает быстрее чем можем безопасно мержить
  - Bottleneck здесь — фича, не баг

- ✅ **SPEC.md validation:**
  - Tech Writer перед передачей Architect проверяет:
    - Файл не пустой
    - Есть обязательные секции (Goal, MVP scope, etc.)
  - Если битый/неполный — переспрашивает user

- ✅ **Beads daemon down:**
  - Система падает, пишет user
  - Не пытаемся работать без sync — это путь к потере данных

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

**Отложено на следующие итерации:**
- [ ] OS Notifications (macOS/Linux)
- [ ] Webhook уведомления (Telegram, Slack)
- [ ] Автодокументация (README, API docs)
