# Changelog

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
