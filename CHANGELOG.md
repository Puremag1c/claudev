# Changelog

## [0.7.1] - 2026-01-28

### Fixed
- **run-executors.sh**: Проверка статуса задачи ПЕРЕД claim (избегает путаницы при race condition)
- **run-executors.sh**: Retry counter теперь берёт максимальный retry: label и удаляет старый при инкременте
- **orchestrator.sh**: Heredoc для формирования prompt в run_interactive_agent (безопасно для кавычек в agent prompts)

---

## [0.7.0] - 2026-01-28

### Fixed
- **P0 CRITICAL**: Beads CLI флаги — `--format=json` заменён на `--json` во всех скриптах
  - `bd show` и `bd ready` не поддерживают `--format=json` (только глобальный `--json`)
  - `bd list --format=json` выдавал пустой вывод (Go template, не JSON)
  - Затронуты: orchestrator.sh, run-executors.sh, run-senior-executor.sh, run-analysts.sh, detect-phase.sh

### Added
- **Existing project support**: `claudev init` анализирует существующий код и создаёт PROJECT_CONTEXT.md
- **Delete command**: `claudev delete` для полного удаления claudev из проекта
- **Deep analysis**: `analyze-project.sh` определяет стек, фреймворк, зависимости
- **Tech Writer integration**: Учитывает PROJECT_CONTEXT.md при создании SPEC.md

---

## [0.6.0] - 2026-01-27

### Added
- **Global installation**: claudev устанавливается в `~/.claudev/` и доступен глобально
- **claudev init**: Инициализация проекта командой `claudev init` в любой директории
- **Project-local config**: `.claudev/config.sh` создаётся в проекте, не глобально
- **Symlinked agents**: `.claude/agents/` ссылается на глобальные агенты

### Changed
- install.sh теперь устанавливает глобально (не в текущую папку)
- bin/claudev переписан как полноценный CLI с командами (init, run, status, delete)

---

## [0.5.5] - 2026-01-27

### Added
- **install.sh**: Auto-создание `.claude/settings.json` с pre-approved permissions
  - git, gh, bd — полный доступ без вопросов
  - Скрипты: `./scripts/*`, bash, timeout
  - Утилиты: jq, date, stat, pkill, kill, sleep
  - Файловые операции: Read, Edit, Write, Glob, Grep
- Пользователь больше не будет завален вопросами при запуске orchestrator

---

## [0.5.0] - 2026-01-27

### Milestone: Ready for Testing

Первый полностью функциональный релиз. Все 18 задач закрыты, архитектурный аудит пройден.

### Summary
- 10 агентов: Tech Writer, Manager, Architect, Executor, Senior Executor, 5 Analysts
- 8 скриптов: orchestrator, detect-phase, run-analysts, run-executors, run-senior-executor, close-completed-parents, log, notify
- 7 фаз: INIT → PLANNING → HELPERS → PLAN_REVIEW → IMPLEMENTATION → FINAL_REVIEW → DONE
- 27 архитектурных решений задокументированы в PROJECT.md
- One-liner установка: `curl -fsSL .../invite.sh | bash`

### Architecture Highlights
- Atomic orchestrator lock (noclobber)
- Graceful shutdown с smart reset (5min threshold)
- Backpressure через MAX_PARALLEL_EXECUTORS
- Squash merge на Senior Executor (Haiku-friendly)
- Draft TTL 24h для Tech Writer
- Beads daemon health check каждую итерацию

---

## [0.4.21] - 2026-01-27

### Fixed
- **P1**: CHANGELOG — добавлена пропущенная запись v0.4.20

### Improved
- **P2**: orchestrator.sh — явная обработка BLOCKED_CYCLES (создаёт P0 задачу для Architect)
- **P2**: PROJECT.md — обновлено решение #15 (squash перенесён на Senior Executor с v0.4.10)

## [0.4.20] - 2026-01-26

### Fixed
- **P1**: executor.md — добавлен TASK_TITLE extraction перед использованием в эскалации
- **P1**: senior-executor.md — убран дублирующий поиск задачи, TASK_ID берётся из контекста

### Improved
- **P2**: analyst-architecture.md — упрощена проверка model: labels (читаемый bash вместо сложного jq)
- **P2**: Все агенты — добавлена секция "Контекст" с явными переменными (TASK_ID, TRIGGER_TASK, PROJECT_ROOT)
- **P2**: executor.md — добавлена заметка для Haiku про пропуск rebase
- **P2**: senior-executor.md — очистка reviewing label во всех exit paths
- **P2**: detect-phase.sh — проверка циклов перед IMPLEMENTATION фазой

### Minor
- **P3**: tech-writer.md — уточнение что timeout это рекомендация
- **P3**: orchestrator.sh — health check для claude CLI при старте
- **P3**: run-executors.sh — удаление executor label при timeout/error

## [0.4.13] - 2026-01-26

### Fixed
- **P2**: senior-executor.md унифицирован подход к labels (`bd label remove` → `bd update --remove-label`)
- **P2**: PROJECT.md примеры обновлены для соответствия реальному коду:
  - `bd list --label=` → jq фильтры (как в orchestrator.sh)
  - `--label=X` → `--labels=X` для bd create

## [0.4.12] - 2026-01-26

### Fixed
- **P0 CRITICAL**: `bd update --label=X` не существует в beads CLI — заменено на `--add-label=X`
  - run-executors.sh: executor claim и retry labels
  - executor.md: needs-rebase, needs-review labels
  - senior-executor.md: reviewing label
  - manager.md: blocked/escalation labels
  - architect.md: blocked:escalation-limit label
  - PROJECT.md: примеры в документации

### Changed
- manager.md: `--label=X --label=Y` заменено на `--labels=X,Y` для bd create
- manager.md: `--label=-retry:*` заменено на `--set-labels=` для сброса labels

## [0.4.11] - 2026-01-26

### Fixed
- **P2**: architect.md heredoc теперь корректно вычисляет дату (переменные до EOF, не внутри 'EOF')

## [0.4.10] - 2026-01-26

### Fixed
- **P1**: Tech Writer больше не использует bd commands (state через файлы SPEC.md/SPEC.draft.md)
- **P1**: Executor больше не делает squash — Senior Executor делает squash merge (безопаснее)
- **P2**: Milestone creation для analysts перенесён в orchestrator (нет race condition)
- **P3**: VERSION path в stats теперь передаётся параметром (корректно при symlinks)

### Changed
- tech-writer.md: убраны `bd update`/`bd close`, только файловые операции
- executor.md: убран шаг squash (git reset --soft), просто push после rebase
- senior-executor.md: local merge теперь `git merge --squash` вместо `--no-ff`
- run-analysts.sh: убрано создание milestone (теперь в orchestrator)
- orchestrator.sh: создаёт milestone:analysts-done после run-analysts.sh

## [0.4.9] - 2026-01-26

### Added
- **Stats generation**: отчёт `stats/iteration-*.md` с метриками итерации (задачи, агенты, токены)
- **Draft TTL check**: SPEC.draft.md старше 24h автоматически архивируется, начинается заново

### Changed
- orchestrator.sh: генерирует stats при завершении итерации (фаза DONE)
- orchestrator.sh: проверяет возраст draft перед INIT фазой

## [0.4.6] - 2026-01-26

### Fixed
- **P2**: Кроссплатформенный date parsing в orchestrator.sh (macOS + Linux)
- executor.md: убраны вызовы `./scripts/log.sh`, упрощены примеры ошибок

### Changed
- run-executors.sh: фильтр задач по title pattern вместо `implementation` label
- run-executors.sh: добавлен warning в лог при fallback на sonnet (если нет `model:*` label)
- architect.md: убран устаревший `--label=implementation` из примеров

### Removed
- `implementation` label больше не используется (избыточен, `model:*` достаточен)

## [0.4.5] - 2026-01-26

### Fixed
- **P1**: architect.md теперь ищет task id по title (bd требует id, не title)
- **P1**: run-senior-executor.sh корректно удаляет label (`--remove-label` вместо `--label=""`)
- **P1**: analyst-architecture.md валидирует наличие `model:*` label на tasks (defense in depth)

### Changed
- orchestrator.sh выводит версию при старте (отладка)
- detect-phase.sh: убрано дублирование в HELPERS фазе

### Removed
- Мёртвый код `run_agent()` из orchestrator.sh (заменён на `run_agent_with_mode`)

## [0.4.4] - 2026-01-26

### Fixed
- **P0 CRITICAL**: orchestrator теперь НАПРЯМУЮ вызывает скрипты по фазам (bash вызывает bash)
- **P0 CRITICAL**: Все агенты теперь с tool use (`-p` вместо `--print`)
  - `--print` отключал Bash tool — агенты не могли выполнять `bd create`, `git commit`
  - Теперь: `claude --model $model -p "$prompt"` — полный доступ к tools
- Исправлено в: orchestrator.sh, run-analysts.sh, run-executors.sh, run-senior-executor.sh
- Manager теперь тоже с tool use — автономно разрешает проблемы

### Changed
- **Архитектура разделена на два уровня:**
  - Механика (bash): orchestrator напрямую вызывает run-analysts.sh, run-executors.sh, агентов
  - Решения (LLM): Manager вызывается при проблемах и САМ их разрешает
- dispatch_phase() теперь содержит прямые вызовы для каждой фазы
- manager.md: переписан как "Problem Resolver" — выполняет команды, не даёт рекомендации

### Added
- `run_agent_with_mode()` — запуск агента с MODE параметром
- `create_analyst_triggers()` — создание trigger tasks для analysts
- `check_and_create_done_milestone()` — проверка FINAL_REVIEW: PASSED
- `check_problems_and_consult_manager()` — вызов Manager при проблемах
- `call_manager_for_problems()` — передача контекста проблем Manager'у

## [0.4.3] - 2026-01-26

### Fixed
- **P0 CRITICAL**: Trigger tasks для analysts теперь создаются (Manager вызывается для всех фаз кроме INIT/DONE)
- **P0 CRITICAL**: Trigger task run-plan-review теперь создаётся Manager'ом
- **P0 CRITICAL**: milestone:project-done теперь создаётся в FINAL_REVIEW
- run_interactive_agent передаёт содержимое файла через --system-prompt (не путь)

### Changed
- orchestrator.sh: dispatch_phase() теперь делегирует Manager'у для всех фаз кроме INIT и DONE
- manager.md: переписан под получение CURRENT_PHASE из контекста orchestrator
- Архитектура: orchestrator определяет фазу → вызывает Manager → Manager выполняет действия

## [0.4.2] - 2026-01-26

### Fixed
- **P0 CRITICAL**: Tech Writer теперь запускается интерактивно (без `--print`)
- Фаза INIT требует диалога с пользователем — невозможно в non-interactive режиме

### Added
- `run_interactive_agent()` — новая функция для агентов требующих user input

## [0.4.1] - 2026-01-26

### Fixed
- Heredoc syntax in orchestrator.sh — `$(cat ...)` теперь выполняется до heredoc
- Heredoc syntax in run-executors.sh — error handler перенесён из heredoc body в if/then
- Heredoc syntax in run-analysts.sh — аналогичное исправление
- Backpressure filter — теперь считает только `executor` label, не `model:*`

### Added
- Phase dispatcher в orchestrator — прямой вызов скриптов по фазам вместо зависимости от Manager
- run-senior-executor.sh — обработка задач с `needs-review` label (sequential quality gate)

### Changed
- Orchestrator больше не зависит от Manager.md для dispatch команд
- Manager становится advisory (опционально для отладки)

## [0.4] - 2026-01-24

### Added
- Architect обязан повышать версию и обновлять changelog в FINAL_REVIEW
- VERSION файл для хранения текущей версии (универсально для любого стека)
- SemVer: MAJOR (breaking) / MINOR (features) / PATCH (bugfixes)

### Changed
- architect.md: расширена секция MODE: final_review с версионированием

## [0.3] - 2026-01-24

### Added
- Auto-close features и epics когда все children завершены
- Новый скрипт `close-completed-parents.sh`
- Использует встроенную команду beads `bd epic close-eligible`

### Changed
- orchestrator.sh вызывает auto-close каждый цикл (шаг 7)

## [0.2] - 2026-01-24

### Added
- One-liner установка: `curl ... | bash`
- Полная автоустановка зависимостей (homebrew, beads, gh, jq, claude-code)
- Поддержка Windows через WSL (автоопределение + инструкции)
- README для пользователей

### Changed
- Очистка .claudev/ от файлов разработки после установки
- Пользователь видит только рабочие файлы (core/, templates/, install.sh)

## [0.1] - 2026-01-24

### Added
- Многоагентная система разработки
- 10 агентов: Tech Writer, Manager, Architect, Executor, Senior Executor, 5 Analysts
- Orchestrator с atomic lock, graceful shutdown
- Beads интеграция для управления задачами
- 7 фаз проекта: INIT → PLANNING → HELPERS → PLAN_REVIEW → IMPLEMENTATION → FINAL_REVIEW → DONE
- Архитектурный аудит: 19 угроз найдено и закрыто
