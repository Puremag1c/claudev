# Claudev Architecture

Многоагентная AI-система автоматической разработки на базе Claude Code.

## Обзор

```
orchestrator.sh (bash loop с lock file)
    │
    └─► Manager (Sonnet, stateless)
            │
            ├─► detect-phase.sh → определяет текущую фазу
            │
            └─► Запускает агентов по фазе:
                ├─► Tech Writer (Opus) — собирает требования
                ├─► Architect (Opus) — план, задачи, dependencies
                ├─► Analysts (Sonnet × 5) — аудит плана
                ├─► Executors (по задаче) — реализация в git ветках
                └─► Senior Executor (Opus) — ревью, merge, релиз
```

## Фазы проекта

```
INIT → PLANNING → HELPERS → PLAN_REVIEW → IMPLEMENTATION → FINAL_REVIEW → DONE
```

| Фаза | Условие перехода | Агент | Действие |
|------|-----------------|-------|----------|
| INIT | Нет SPEC.md | Tech Writer | Собирает требования от user |
| PLANNING | Есть SPEC.md | Architect | Создаёт задачи в beads |
| HELPERS | milestone:planning-done | Analysts ×5 | Параллельный аудит плана |
| PLAN_REVIEW | milestone:analysts-done | Architect | Ревьюит добавления Analysts |
| IMPLEMENTATION | milestone:plan-reviewed | Executors | Реализуют задачи |
| FINAL_REVIEW | Все задачи closed | Architect | Проверяет целостность |
| DONE | milestone:project-done | — | Проект завершён |

## Агенты

### Manager (Sonnet)
- **Роль:** Stateless координатор
- **Задача:** Определить фазу, запустить нужного агента, выйти
- **Не делает:** Не создаёт задачи, не пишет код

### Tech Writer (Opus)
- **Роль:** Сбор требований
- **Задача:** Через диалог с user создать SPEC.md
- **Особенности:** Интерактивный режим, без timeout

### Architect (Opus)
- **Роль:** Главный технический эксперт
- **Задачи:**
  - Создание плана из SPEC.md
  - Разбивка на мелкие задачи (1-5 мин)
  - Расстановка dependencies
  - Назначение модели каждой задаче
  - Ревью добавлений от Analysts
  - Разрешение конфликтов и эскалаций

### Analysts (Sonnet × 5)
- **Роль:** Параллельный аудит плана
- **Виды:**
  - UX — пользовательские сценарии, UI состояния
  - Security — OWASP, auth, secrets
  - OPS — тесты, CI/CD, мониторинг
  - Reliability — edge cases, failure modes
  - Architecture — структура кода, зависимости
- **Правило:** Только добавляют задачи, не удаляют

### Executor (по задаче)
- **Роль:** Реализация одной задачи
- **Модель:** Из label задачи (model:haiku/sonnet/opus)
- **Workflow:**
  1. Claim задачу через `bd update --claim`
  2. Работает в ветке `task/beads-{id}`
  3. Rebase на main
  4. Push и пометить `needs-review`

### Senior Executor (Opus)
- **Роль:** Quality gate перед main
- **Задачи:**
  - Code review
  - Проверка на secrets
  - Запуск тестов
  - Merge через PR (или local merge)
  - Релиз

## Скрипты

| Скрипт | Назначение |
|--------|------------|
| `orchestrator.sh` | Главный цикл с lock file |
| `detect-phase.sh` | Определение текущей фазы |
| `run-analysts.sh` | Параллельный запуск 5 Analysts |
| `run-executors.sh` | Параллельный запуск Executors с backpressure |
| `log.sh` | Хелпер для логирования |
| `notify.sh` | Уведомления (macOS) |

## Конфигурация

`.claudev/config.sh`:

```bash
MAX_PARALLEL_EXECUTORS=3    # Лимит параллельных Executors
RETRY_LIMIT=3               # Retry до эскалации к Architect
TASK_TIMEOUT="10m"          # Таймаут на задачу
USER_INPUT_TIMEOUT="30m"    # Таймаут ожидания user
CI_ENABLED=false            # GitHub CI интеграция
CD_ENABLED=false            # Автоматический релиз
```

## Beads интеграция

### Статусы задач

- `open` — задача создана, ждёт исполнителя
- `in_progress` — Executor работает
- `in_progress` + `needs-review` — ждёт Senior Executor
- `closed` — завершено

### Labels

- `model:haiku/sonnet/opus` — какая модель выполняет
- `added-by:analyst-*` — кто добавил задачу
- `milestone:*` — маркер завершения фазы
- `retry:N` — счётчик повторных попыток
- `blocked:*` — причина блокировки

### Dependencies

```bash
bd dep add <task-id> <depends-on-id>
bd dep cycles  # Проверка циклов
```

## Отказоустойчивость

### Lock file
- Один orchestrator за раз
- Atomic через `set -C` (noclobber)
- Автоочистка stale lock

### Retry logic
- 3 попытки на задачу
- Счётчик в label `retry:N`
- После лимита — эскалация к Architect

### Graceful shutdown
- `trap SIGINT SIGTERM`
- Reset stale tasks (>5min in_progress)
- Cleanup lock file

### Config validation
- Проверка при каждой итерации
- Integers, booleans, timeouts
- Fail fast при ошибках

## Git workflow

```
main
  │
  ├── task/beads-abc  ← Executor 1
  ├── task/beads-def  ← Executor 2
  └── task/beads-ghi  ← Executor 3
```

1. Executor создаёт ветку от main
2. Работает, коммитит
3. Rebase на main (при конфликте — эскалация)
4. Push с `--force-with-lease`
5. Senior Executor мержит через PR

## Backpressure

- Лимит = `MAX_PARALLEL_EXECUTORS`
- Считаем через beads (не gh pr list)
- Работает без GitHub

## Логирование

Формат: `YYYY-MM-DD HH:MM:SS [AGENT] EVENT: message`

```bash
./scripts/log.sh MANAGER INFO "Starting phase detection"
./scripts/log.sh EXECUTOR TASK_START "claudev-abc"
./scripts/log.sh ORCHESTRATOR FATAL "Beads daemon not running"
```

## Установка

```bash
cd your-project
git clone <claudev-repo> .claudev
.claudev/install.sh
./scripts/orchestrator.sh
```

## Зависимости

- **beads** — управление задачами
- **claude** — Claude Code CLI
- **gh** — GitHub CLI (опционально)
- **jq** — JSON processing
- **gitleaks** — secret detection (опционально)
