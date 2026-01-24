#!/bin/bash
# core/scripts/orchestrator.sh
# Главный цикл Claudev — координирует работу агентов через Manager.
#
# Использование:
#   ./scripts/orchestrator.sh           # Интерактивно
#   ./scripts/orchestrator.sh &         # В фоне
#   nohup ./scripts/orchestrator.sh &   # Переживёт закрытие терминала

set -euo pipefail

PROJECT_DIR=$(pwd)
CLAUDEV_DIR="$PROJECT_DIR/.claudev"
LOGS_DIR="$PROJECT_DIR/logs"
LOCK_FILE="$CLAUDEV_DIR/orchestrator.lock"
CONFIG_FILE="$CLAUDEV_DIR/config.sh"

# === Lock file (single instance) ===

acquire_lock() {
    mkdir -p "$CLAUDEV_DIR"

    if ! (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
        OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "0")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo "ERROR: Orchestrator already running (PID $OLD_PID)"
            exit 1
        else
            echo "Removing stale lock (PID $OLD_PID not found)"
            rm -f "$LOCK_FILE"
            if ! (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
                echo "ERROR: Failed to acquire lock (race condition?)"
                exit 1
            fi
        fi
    fi
}

# === Logging ===

mkdir -p "$LOGS_DIR"

log() {
    local level=$1
    local message=$2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ORCHESTRATOR] $level: $message" | tee -a "$LOGS_DIR/claudev.log"
}

# === Config validation ===

validate_config() {
    local errors=0

    # Validate integers
    validate_int() {
        local name=$1
        local value=$2
        if ! [[ "$value" =~ ^[0-9]+$ ]]; then
            log "FATAL" "Invalid $name in config.sh: must be integer, got '$value'"
            ((errors++))
        fi
    }

    # Validate booleans
    validate_bool() {
        local name=$1
        local value=$2
        if [[ "$value" != "true" && "$value" != "false" ]]; then
            log "FATAL" "Invalid $name in config.sh: must be true/false, got '$value'"
            ((errors++))
        fi
    }

    # Validate timeout format (Nm or Ns)
    validate_timeout() {
        local name=$1
        local value=$2
        if ! [[ "$value" =~ ^[0-9]+[ms]$ ]]; then
            log "FATAL" "Invalid $name in config.sh: must be Nm or Ns (e.g. 10m), got '$value'"
            ((errors++))
        fi
    }

    # Run validations
    validate_int "MAX_PARALLEL_EXECUTORS" "$MAX_PARALLEL_EXECUTORS"
    validate_int "RETRY_LIMIT" "$RETRY_LIMIT"
    validate_int "ITERATION_DELAY" "$ITERATION_DELAY"
    validate_int "CLEANUP_KEEP_DAYS" "$CLEANUP_KEEP_DAYS"

    validate_bool "CI_ENABLED" "$CI_ENABLED"
    validate_bool "CD_ENABLED" "$CD_ENABLED"
    validate_bool "LOG_TOKENS" "$LOG_TOKENS"
    validate_bool "CLEANUP_ENABLED" "$CLEANUP_ENABLED"

    validate_timeout "TASK_TIMEOUT" "$TASK_TIMEOUT"
    validate_timeout "USER_INPUT_TIMEOUT" "$USER_INPUT_TIMEOUT"

    if [ "$errors" -gt 0 ]; then
        log "FATAL" "Config validation failed ($errors errors). Fix .claudev/config.sh"
        exit 1
    fi

    log "INFO" "Config loaded: MAX_PARALLEL=$MAX_PARALLEL_EXECUTORS, RETRY=$RETRY_LIMIT, DELAY=${ITERATION_DELAY}s"
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log "FATAL" "Config not found: $CONFIG_FILE. Run install.sh first."
        exit 1
    fi

    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    validate_config
}

# === Beads daemon check ===

check_beads() {
    if ! bd sync --status &>/dev/null; then
        log "FATAL" "Beads daemon not running. Run: bd daemon start"
        exit 1
    fi
}

# === Graceful shutdown ===

cleanup() {
    log "INFO" "Shutting down gracefully..."

    # SIGTERM children
    pkill -P $$ -TERM 2>/dev/null || true
    sleep 5
    pkill -P $$ -KILL 2>/dev/null || true

    # Reset stale in_progress tasks (>5min old)
    for task_id in $(bd list --status=in_progress --format=json 2>/dev/null | jq -r '.[].id' 2>/dev/null || true); do
        local updated_at
        updated_at=$(bd show "$task_id" --format=json 2>/dev/null | jq -r '.updated_at' 2>/dev/null || echo "")
        if [ -n "$updated_at" ]; then
            local claimed_epoch now_epoch age
            claimed_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${updated_at%%.*}" +%s 2>/dev/null || date -d "$updated_at" +%s 2>/dev/null || echo "0")
            now_epoch=$(date +%s)
            age=$((now_epoch - claimed_epoch))

            if [ "$age" -gt 300 ]; then
                log "INFO" "Resetting stale task $task_id (age: ${age}s)"
                bd update "$task_id" --status=open --notes="Reset: stale at shutdown (${age}s old)" 2>/dev/null || true
            fi
        fi
    done

    rm -f "$LOCK_FILE"
    log "INFO" "Shutdown complete"
    exit 0
}

trap cleanup SIGINT SIGTERM

# === Detect phase ===

detect_phase() {
    ./scripts/detect-phase.sh 2>/dev/null || echo "UNKNOWN"
}

# === Main loop ===

main() {
    acquire_lock

    log "INFO" "=========================================="
    log "INFO" "ORCHESTRATOR STARTED (PID $$)"
    log "INFO" "Project: $PROJECT_DIR"
    log "INFO" "=========================================="

    # Record iteration start time
    date '+%Y-%m-%d %H:%M:%S' > "$CLAUDEV_DIR/iteration_start.txt"

    local cycle=0
    local max_cycles="${MAX_CYCLES:-1000}"

    while [ $cycle -lt "$max_cycles" ]; do
        ((cycle++))

        # 1. Check beads daemon (every iteration, fast ~10-50ms)
        check_beads

        # 2. Load config (allows hot reload)
        load_config

        # 3. Detect current phase
        local phase
        phase=$(detect_phase)
        log "INFO" "--- Cycle $cycle | Phase: $phase ---"

        # 4. Run Manager agent
        local manager_out
        manager_out=$(timeout "$TASK_TIMEOUT" claude --model sonnet --print <<EOF 2>&1 || true)
$(cat .claude/agents/manager.md 2>/dev/null || echo "# Manager agent not found")

---
PROJECT_ROOT: $PROJECT_DIR
CURRENT_PHASE: $phase
CYCLE: $cycle
EOF

        # Log manager output
        echo "$manager_out" >> "$LOGS_DIR/manager-$cycle.log"

        # 5. Check for completion
        if echo "$manager_out" | grep -q "PROJECT_COMPLETE"; then
            log "INFO" "=========================================="
            log "INFO" "PROJECT COMPLETE"
            log "INFO" "=========================================="

            # Archive logs
            local timestamp
            timestamp=$(date +%Y%m%d-%H%M%S)
            mkdir -p "$LOGS_DIR/archive"
            mv "$LOGS_DIR/claudev.log" "$LOGS_DIR/archive/iteration-$timestamp.log" 2>/dev/null || true

            ./scripts/notify.sh "Project complete" "All tasks done" 2>/dev/null || true
            rm -f "$LOCK_FILE"
            exit 0
        fi

        # 6. Check for critical errors
        if echo "$manager_out" | grep -qi "CRITICAL_ERROR\|FATAL"; then
            log "ERROR" "Critical error detected in Manager output"
            ./scripts/notify.sh "Critical error" "Check logs/manager-$cycle.log" 2>/dev/null || true
        fi

        # 7. Pause before next iteration
        log "INFO" "Pause ${ITERATION_DELAY}s..."
        sleep "$ITERATION_DELAY"
    done

    log "WARN" "Max cycles reached ($max_cycles)"
    rm -f "$LOCK_FILE"
    exit 1
}

main "$@"
