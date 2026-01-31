#!/bin/bash
# core/scripts/run-executors.sh
# Запускает Executor агентов параллельно с backpressure контролем.
#
# Backpressure: количество активных executors ограничено через MAX_PARALLEL_EXECUTORS.
# Считаем через beads (in_progress + label=executor), не через gh pr list.
#
# Использование: ./scripts/run-executors.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

PROJECT_DIR=$(pwd)
LOGS_DIR="$PROJECT_DIR/logs"
CONFIG_FILE="$PROJECT_DIR/.claudev/config.sh"

# Load config
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

MAX_PARALLEL="${MAX_PARALLEL_EXECUTORS:-3}"
TASK_TIMEOUT="${TASK_TIMEOUT:-10m}"

mkdir -p "$LOGS_DIR"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [RUN-EXECUTORS] $1: $2" | tee -a "$LOGS_DIR/claudev.log"
}

# === Backpressure check ===
# Считаем active executors через beads (работает всегда, не зависит от gh)

count_active_executors() {
    # Считаем задачи в in_progress с label executor
    bd list --status=in_progress --json 2>/dev/null | \
        jq '[.[] | select(.labels[]? == "executor")] | length' 2>/dev/null || echo "0"
}

# === Get ready tasks for executors ===

get_ready_tasks() {
    # Получаем задачи готовые к работе (не blocked, не in_progress)
    # Фильтруем:
    #   - type == task
    #   - исключаем служебные (triggers, milestones)
    bd ready --json 2>/dev/null | \
        jq -r '.[] | select(.issue_type == "task") | select(.title | test("^run-|^milestone:") | not) | .id' 2>/dev/null | \
        head -n "$MAX_PARALLEL"
}

# === Run single executor ===

run_executor() {
    local task_id=$1

    # Check task status before claim (avoid race condition confusion)
    local current_status
    current_status=$(bd show "$task_id" --json 2>/dev/null | jq -r '.[0].status // "unknown"' 2>/dev/null)

    if [ "$current_status" != "open" ]; then
        log "INFO" "Task $task_id not open (status: $current_status), skipping"
        return 0
    fi

    # Try to claim the task (atomic via beads)
    if ! bd update "$task_id" --status=in_progress --add-label=executor 2>/dev/null; then
        log "INFO" "Task $task_id claim failed (race condition), skipping"
        return 0
    fi

    # Get task details
    local task_json
    task_json=$(bd show "$task_id" --json 2>/dev/null || echo "[]")

    local task_title
    task_title=$(echo "$task_json" | jq -r '.[0].title // "Unknown"')

    # Get model from label (fallback: sonnet with warning)
    local model
    model=$(echo "$task_json" | jq -r '.[0].labels[]? | select(startswith("model:")) | split(":")[1]' 2>/dev/null | head -1)
    if [ -z "$model" ]; then
        log "WARN" "Task $task_id has no model: label, using fallback sonnet"
        model="sonnet"
    fi

    log "INFO" "Starting executor for $task_id ($model): $task_title"

    # Run executor agent with timeout (with tool use enabled)
    local output_file="$LOGS_DIR/executor-$task_id.log"
    local executor_prompt
    executor_prompt=$(cat .claude/agents/executor.md 2>/dev/null || echo "# Executor agent not found")

    local full_prompt="$executor_prompt

---
TASK_ID: $task_id
TASK: $task_json
PROJECT_ROOT: $PROJECT_DIR"

    # Use stdin to avoid issues with prompts starting with "---"
    if ! printf '%s' "$full_prompt" | timeout_cmd "$TASK_TIMEOUT" claude --model "$model" > "$output_file" 2>&1; then
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log "WARN" "Executor timeout for $task_id"
            # Increment retry counter (take max if multiple exist, remove old label)
            local current_retry old_retry_label
            current_retry=$(echo "$task_json" | jq -r '[.[0].labels[]? | select(startswith("retry:")) | split(":")[1] | tonumber] | max // 0' 2>/dev/null)
            current_retry="${current_retry:-0}"
            local new_retry=$((current_retry + 1))

            # Remove old retry label if exists, add new one
            old_retry_label=$(echo "$task_json" | jq -r '.[0].labels[]? | select(startswith("retry:"))' 2>/dev/null | head -1)
            if [ -n "$old_retry_label" ]; then
                bd update "$task_id" --status=open --remove-label=executor --remove-label="$old_retry_label" --add-label="retry:$new_retry" --notes="Timeout at $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null || true
            else
                bd update "$task_id" --status=open --remove-label=executor --add-label="retry:$new_retry" --notes="Timeout at $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null || true
            fi
        else
            log "ERROR" "Executor failed for $task_id (exit: $exit_code)"
            bd update "$task_id" --status=open --remove-label=executor --notes="Executor failed (exit: $exit_code)" 2>/dev/null || true
        fi
        return 0
    fi

    log "INFO" "Executor completed for $task_id"
}

# === Main ===

main() {
    log "INFO" "=========================================="
    log "INFO" "RUN-EXECUTORS STARTED"
    log "INFO" "Max parallel: $MAX_PARALLEL"
    log "INFO" "=========================================="

    # Check backpressure
    local active
    active=$(count_active_executors)

    if [ "$active" -ge "$MAX_PARALLEL" ]; then
        log "INFO" "Executor queue full ($active/$MAX_PARALLEL), waiting for slots"
        exit 0
    fi

    local available_slots=$((MAX_PARALLEL - active))
    log "INFO" "Available slots: $available_slots (active: $active)"

    # Get ready tasks
    local tasks
    tasks=$(get_ready_tasks)

    if [ -z "$tasks" ]; then
        log "INFO" "No ready tasks for executors"
        exit 0
    fi

    # Start executors in parallel (up to available slots)
    local started=0
    for task_id in $tasks; do
        if [ $started -ge $available_slots ]; then
            break
        fi

        run_executor "$task_id" &
        ((started++))
    done

    log "INFO" "Started $started executors"

    # Wait for all background jobs
    wait

    log "INFO" "All executors finished"

    # Sync only if daemon is not running (daemon auto-syncs)
    if ! bd sync --status 2>/dev/null | grep -q "auto-commit.*enabled"; then
        bd sync 2>/dev/null || true
    fi
}

main "$@"
