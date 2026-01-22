# AI Development System

Автономная мульти-агентная система разработки с памятью в Beads.

## Ключевые особенности

- **Менеджер с памятью** — состояние хранится в Beads, не теряется между вызовами
- **Автономная работа** — orchestrator пинает менеджера в цикле до завершения
- **Параллельные агенты** — помощники и кодеры работают одновременно
- **Атомарный захват задач** — кодеры не дублируют работу

## Быстрый старт

```bash
# 1. Установи зависимости
npm install -g @anthropic-ai/claude-code
brew install jq
# + beads

# 2. Скопируй в проект
cp -r ai-dev-system/{.claude,scripts,CLAUDE.md} my-project/
cd my-project
bd init --quiet
chmod +x scripts/*.sh

# 3. Опиши ТЗ
vim SPEC.md

# 4. Инициализируй и запусти
./scripts/init-manager.sh
./scripts/orchestrator.sh
```

## Как это работает

```
┌─────────────────────────────────────────┐
│         orchestrator.sh                  │
│                                          │
│   while true:                            │
│       claude manager "Продолжи работу"   │
│       if PROJECT_COMPLETE: exit          │
│       sleep 10                           │
│                                          │
└─────────────────┬────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│         Manager (Claude)                 │
│                                          │
│   1. bd show MANAGER → читает состояние  │
│   2. Анализирует задачи                  │
│   3. Принимает решение                   │
│   4. Выполняет действие                  │
│   5. bd update MANAGER → сохраняет       │
│                                          │
└─────────────────┬────────────────────────┘
                  │
      ┌───────────┼───────────┐
      ▼           ▼           ▼
  Architect    Helpers     Coders
   (Opus)    (Sonnet×4)   (dynamic)
```

## Состояние менеджера в Beads

```json
{
  "phase": "IMPLEMENTATION",
  "cycle": 15,
  "helper_cycles": 2,
  "last_action": "run-coders",
  "last_decision": "8 задач open, запустил 2 кодеров",
  "blockers_seen": ["bd-f3a1"],
  "decisions": [
    {"cycle": 1, "action": "run-architect", "reason": "INIT"},
    {"cycle": 5, "action": "run-helpers", "reason": "План создан"},
    {"cycle": 10, "action": "run-coders", "reason": "План готов"},
    ...
  ]
}
```

## Интеграция с существующим проектом

```bash
# Если задачи уже в Beads:

# 1. Добавь модели
./scripts/add-models.sh sonnet

# 2. Пропусти планирование
./scripts/set-milestones.sh planning-done helpers-done plan-reviewed

# 3. Инициализируй менеджера в нужной фазе
./scripts/init-manager.sh --phase IMPLEMENTATION --helper-cycles 2

# 4. Запусти
./scripts/orchestrator.sh
```

## Скрипты

| Скрипт | Описание |
|--------|----------|
| `orchestrator.sh` | Главный цикл — пинает менеджера |
| `init-manager.sh` | Инициализация состояния менеджера |
| `run-helpers.sh` | Параллельный запуск помощников |
| `run-coders.sh` | Параллельный запуск кодеров |
| `claim-task.sh` | Атомарный захват задачи |
| `detect-phase.sh` | Определение фазы (legacy) |
| `add-models.sh` | Добавить model: labels |
| `set-milestones.sh` | Проставить milestones |
| `notify.sh` | macOS уведомления |

## Переменные окружения

```bash
MAX_CYCLES=100      # Лимит итераций orchestrator
PAUSE_SECONDS=10    # Пауза между вызовами менеджера
```

## Отладка

```bash
# Логи orchestrator
tail -f logs/orchestrator.log

# Логи конкретного цикла менеджера
cat logs/manager-15.log

# Состояние менеджера
bd list --json | jq '.[] | select(.labels | index("role:manager")) | .description | fromjson'

# Сбросить и начать заново
./scripts/init-manager.sh --reset
```
