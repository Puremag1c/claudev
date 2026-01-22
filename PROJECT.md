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
| manager | Sonnet | Координатор, хранит состояние в Beads, принимает решения |
| architect | Opus | Создаёт план из SPEC.md, назначает модели задачам |
| coder | По задаче | Реализует ОДНУ задачу за сессию |
| reviewer | Sonnet | Проверяет код, создаёт баг-репорты |
| analyst | Opus | Оценивает готовность плана |
| helper-* | Sonnet | Аудит плана (architecture, reliability, ux, ops) |

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

## Текущий статус

Базовая структура готова:
- [x] core/ — агенты, команды, скрипты
- [x] templates/ — шаблоны SPEC.md и CLAUDE.md
- [x] install.sh — установщик
- [x] docs/ — документация

**Следующие шаги:**
- [ ] Обсудить и зафиксировать функциональные требования
- [ ] Протестировать интеграцию в тестовый проект
- [ ] Проверить работу orchestrator
- [ ] Доработать агентов по результатам тестов
