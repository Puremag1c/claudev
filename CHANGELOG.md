# Changelog

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
