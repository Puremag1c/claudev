# Changelog

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
