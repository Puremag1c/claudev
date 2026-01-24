# Project Instructions

Claudev — многоагентная AI-система разработки.

## Архитектура

```
orchestrator.sh (bash loop)
    │
    └─► Manager (Sonnet, stateless)
            │
            ├─► Определяет фазу
            ├─► Запускает агентов
            │
            └─► Агенты:
                ├─► Tech Writer (Opus) — собирает требования
                ├─► Architect (Opus) — план, задачи, dependencies
                ├─► Analysts (Sonnet × 5) — аудит плана
                ├─► Executors (по задаче) — реализация
                └─► Senior Executor (Opus) — ревью, merge
```

## Запуск

```bash
# Запустить систему
./scripts/orchestrator.sh

# В фоне
nohup ./scripts/orchestrator.sh &
tail -f logs/claudev.log
```

## Фазы

| Фаза | Описание |
|------|----------|
| INIT | Нет SPEC.md → Tech Writer собирает требования |
| PLANNING | Architect создаёт план из SPEC.md |
| HELPERS | 5 Analysts аудитят план параллельно |
| PLAN_REVIEW | Architect ревьюит добавления Analysts |
| IMPLEMENTATION | Executors реализуют задачи |
| FINAL_REVIEW | Architect проверяет целостность |
| DONE | Проект завершён |

## Полезные команды

```bash
bd ready                    # Готовые к работе задачи
bd list                     # Все задачи
bd list --status=in_progress # Задачи в работе
bd show <id>                # Детали задачи

./scripts/orchestrator.sh   # Запустить систему
./scripts/detect-phase.sh   # Определить текущую фазу
```

## Конфигурация

Редактируйте `.claudev/config.sh`:

```bash
MAX_PARALLEL_EXECUTORS=3    # Параллельные Executors
RETRY_LIMIT=3               # Retry перед эскалацией
TASK_TIMEOUT="10m"          # Таймаут на задачу
```

## Логи

```bash
tail -f logs/claudev.log           # Основной лог
ls logs/archive/                   # Архив итераций
cat logs/executor-<task-id>.log    # Лог конкретного executor
```
