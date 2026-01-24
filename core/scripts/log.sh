#!/bin/bash
# core/scripts/log.sh
# Хелпер для логирования в Claudev.
#
# Формат: YYYY-MM-DD HH:MM:SS [AGENT] EVENT: message
# Файл: logs/claudev.log
#
# Использование:
#   source ./scripts/log.sh
#   log "MANAGER" "INFO" "Starting phase detection"
#   log "EXECUTOR" "TASK_START" "claudev-abc"
#   log "ORCHESTRATOR" "FATAL" "Beads daemon not running"
#
# Или напрямую:
#   ./scripts/log.sh MANAGER INFO "Starting phase detection"

# Находим корень проекта (где .claudev/)
find_project_root() {
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.claudev" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    echo "$PWD"
}

PROJECT_ROOT=$(find_project_root)
LOGS_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOGS_DIR/claudev.log"

# Создаём директорию если нет
mkdir -p "$LOGS_DIR"

# Функция логирования
log() {
    local agent=$1
    local event=$2
    local message=$3
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "$timestamp [$agent] $event: $message" >> "$LOG_FILE"

    # Также выводим в stdout для интерактивного использования
    if [ -t 1 ]; then
        echo "$timestamp [$agent] $event: $message"
    fi
}

# Если запущен напрямую (не source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -lt 3 ]; then
        echo "Usage: $0 AGENT EVENT MESSAGE"
        echo "Example: $0 MANAGER INFO 'Starting phase detection'"
        exit 1
    fi
    log "$1" "$2" "$3"
fi
