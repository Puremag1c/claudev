# Project Instructions

Многоагентная AI-система разработки с памятью в Beads.

## Архитектура

```
orchestrator.sh (bash loop)
    │
    └─► Manager (Claude Sonnet)
            │
            ├─► Читает состояние из Beads
            ├─► Принимает решение
            ├─► Выполняет действие
            ├─► Сохраняет состояние в Beads
            │
            └─► Вызывает агентов:
                ├─► Architect (Opus)
                ├─► Helpers (Sonnet × 4)
                ├─► Analyst (Sonnet)
                ├─► Coders (по задаче)
                └─► Reviewers (Sonnet)
```

## Запуск

```bash
# 1. Инициализируй состояние менеджера (один раз)
./scripts/init-manager.sh

# 2. Запусти orchestrator
./scripts/orchestrator.sh

# Или в фоне
nohup ./scripts/orchestrator.sh &
tail -f logs/orchestrator.log
```

## Состояние менеджера

Хранится в Beads как задача с label `role:manager`:

```json
{
  "phase": "IMPLEMENTATION",
  "cycle": 15,
  "helper_cycles": 2,
  "last_action": "run-coders",
  "decisions": [...]
}
```

Посмотреть:
```bash
bd list --json | jq '.[] | select(.labels | index("role:manager"))'
```

## Команды

```bash
./scripts/init-manager.sh              # Инициализация
./scripts/init-manager.sh --reset      # Сброс состояния
./scripts/init-manager.sh --phase IMPLEMENTATION  # Установить фазу

./scripts/orchestrator.sh              # Главный цикл
./scripts/detect-phase.sh              # Определить фазу (legacy)
./scripts/run-helpers.sh               # Запустить помощников
./scripts/run-coders.sh 3              # Запустить 3 кодеров

./scripts/add-models.sh sonnet         # Добавить модели к задачам
./scripts/set-milestones.sh ...        # Проставить milestones
```

## Интеграция с существующим проектом

```bash
# 1. Скопируй систему
cp -r ai-dev-system/{.claude,scripts,CLAUDE.md} .
chmod +x scripts/*.sh

# 2. Добавь модели к задачам
./scripts/add-models.sh sonnet

# 3. Проставь milestones
./scripts/set-milestones.sh planning-done helpers-done plan-reviewed

# 4. Инициализируй менеджера с нужной фазой
./scripts/init-manager.sh --phase IMPLEMENTATION --helper-cycles 2

# 5. Запусти
./scripts/orchestrator.sh
```

## Фазы

| Фаза | Описание |
|------|----------|
| INIT | Начало, нет плана |
| PLANNING | Архитектор создаёт план |
| HELPERS | Помощники аудитят |
| PLAN_REVIEW | Ревью + Аналитик |
| IMPLEMENTATION | Кодеры работают |
| FINAL_REVIEW | Тесты + финальное ревью |
| DONE | Завершено |
