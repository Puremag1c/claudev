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
            # Strip milliseconds and timezone for cross-platform parsing
            local clean_date="${updated_at%%.*}"  # Remove .123Z or .123+03:00
            clean_date="${clean_date%%+*}"        # Remove +03:00 if no milliseconds
            clean_date="${clean_date%%Z*}"        # Remove Z if no milliseconds
            # macOS: date -j -f, Linux: date -d
            claimed_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$clean_date" +%s 2>/dev/null || date -d "$clean_date" +%s 2>/dev/null || echo "0")
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

# === Run agent interactively (for user dialogue) ===

run_interactive_agent() {
    local agent_name=$1
    local agent_file=$2
    local model=${3:-"opus"}

    log "INFO" "Starting INTERACTIVE agent: $agent_name (user dialogue required)"

    if [ ! -f "$agent_file" ]; then
        log "ERROR" "Agent file not found: $agent_file"
        return 1
    fi

    # Read agent prompt from file
    local agent_prompt
    agent_prompt=$(cat "$agent_file")

    # Интерактивный режим: передаём содержимое промпта как системную инструкцию
    # Без --print, без timeout, без перенаправления в файл
    # Используем --system-prompt для инструкций агента
    if claude --model "$model" --system-prompt "$agent_prompt

---
PROJECT_ROOT: $PROJECT_DIR"; then
        log "INFO" "Interactive agent $agent_name completed"
        return 0
    else
        log "WARN" "Interactive agent $agent_name exited with error"
        return 1
    fi
}

# === Run agent with MODE parameter (with tool use) ===

run_agent_with_mode() {
    local agent_name=$1
    local agent_file=$2
    local model=$3
    local mode=$4
    local extra_context=${5:-""}

    log "INFO" "Running agent: $agent_name (mode: $mode, model: $model)"

    if [ ! -f "$agent_file" ]; then
        log "ERROR" "Agent file not found: $agent_file"
        return 1
    fi

    local agent_prompt
    agent_prompt=$(cat "$agent_file")

    local output_file="$LOGS_DIR/${agent_name}-$(date +%s).log"

    # Run with tool use enabled (NO --print flag!)
    # Claude Code can execute bd, git, and other commands
    local full_prompt="$agent_prompt

---
MODE: $mode
PROJECT_ROOT: $PROJECT_DIR
$extra_context"

    if timeout "$TASK_TIMEOUT" claude --model "$model" -p "$full_prompt" > "$output_file" 2>&1; then
        log "INFO" "Agent $agent_name completed (mode: $mode)"
        return 0
    else
        log "WARN" "Agent $agent_name failed or timed out (mode: $mode)"
        return 1
    fi
}

# === Create analyst trigger tasks ===

create_analyst_triggers() {
    local analysts=("ux" "security" "ops" "reliability" "architecture")

    for analyst in "${analysts[@]}"; do
        local trigger_title="run-analyst-$analyst"
        if ! bd list --format=json 2>/dev/null | jq -e ".[] | select(.title == \"$trigger_title\")" > /dev/null 2>&1; then
            bd create --title="$trigger_title" --type=task --priority=1 2>/dev/null || true
            log "INFO" "Created trigger: $trigger_title"
        fi
    done
}

# === Check and create done milestone after final_review ===

check_and_create_done_milestone() {
    # Check if architect output contains PASSED
    local latest_log
    latest_log=$(ls -t "$LOGS_DIR"/architect-*.log 2>/dev/null | head -1)

    if [ -n "$latest_log" ] && grep -q "FINAL_REVIEW: PASSED" "$latest_log" 2>/dev/null; then
        log "INFO" "Final review passed, creating project-done milestone"
        bd create --title="Project complete" --type=task --label=milestone:project-done 2>/dev/null || true
        local milestone_id
        milestone_id=$(bd list --format=json 2>/dev/null | jq -r '.[] | select(.labels[]? == "milestone:project-done") | .id' | head -1)
        if [ -n "$milestone_id" ]; then
            bd close "$milestone_id" --reason="Final review passed" 2>/dev/null || true
        fi
    fi
}

# === Check for problems and consult Manager ===
# Manager is called ONLY for problem resolution, not for phase coordination

check_problems_and_consult_manager() {
    # Count blocked tasks
    local blocked_count
    blocked_count=$(bd list --format=json 2>/dev/null | jq '[.[] | select(.labels[]? | startswith("blocked:"))] | length' 2>/dev/null || echo "0")

    # Count tasks at retry limit
    local retry_limit_count
    retry_limit_count=$(bd list --format=json 2>/dev/null | jq "[.[] | select(.labels[]? | test(\"^retry:[$RETRY_LIMIT-9]\"))] | length" 2>/dev/null || echo "0")

    # If problems exist, consult Manager
    if [ "$blocked_count" -gt 0 ] || [ "$retry_limit_count" -gt 0 ]; then
        log "WARN" "Problems detected: blocked=$blocked_count, retry_limit=$retry_limit_count"
        call_manager_for_problems "$blocked_count" "$retry_limit_count"
    fi
}

# === Call Manager for problem resolution ===

call_manager_for_problems() {
    local blocked=$1
    local retry_limit=$2

    local manager_file=".claude/agents/manager.md"
    if [ ! -f "$manager_file" ]; then
        log "WARN" "manager.md not found, skipping problem resolution"
        return 0
    fi

    log "INFO" "Consulting Manager for problem resolution..."

    local manager_prompt
    manager_prompt=$(cat "$manager_file")

    # Get problem details
    local blocked_tasks
    blocked_tasks=$(bd list --format=json 2>/dev/null | jq -r '.[] | select(.labels[]? | startswith("blocked:")) | "\(.id): \(.title)"' 2>/dev/null || echo "none")

    local retry_tasks
    retry_tasks=$(bd list --format=json 2>/dev/null | jq -r ".[] | select(.labels[]? | test(\"^retry:[$RETRY_LIMIT-9]\")) | \"\(.id): \(.title)\"" 2>/dev/null || echo "none")

    local output_file="$LOGS_DIR/manager-problems-$(date +%s).log"

    # Manager with tool use — resolves problems autonomously
    local full_prompt="$manager_prompt

---
PROBLEM_RESOLUTION_MODE: true
PROJECT_ROOT: $PROJECT_DIR

BLOCKED_TASKS ($blocked):
$blocked_tasks

RETRY_LIMIT_TASKS ($retry_limit):
$retry_tasks

Разреши проблемы автономно:
1. Для blocked — проверь зависимости, разблокируй если dependency closed
2. Для retry limit — эскалируй к Architect (создай задачу) или закрой как невозможную"

    timeout "$TASK_TIMEOUT" claude --model sonnet -p "$full_prompt" > "$output_file" 2>&1 || true

    log "INFO" "Manager problem resolution complete (see $output_file)"
}

# === Draft TTL check (24h) ===
# If draft is older than 24h, archive it and start fresh

check_draft_ttl() {
    local draft_file="$PROJECT_DIR/SPEC.draft.md"
    local ttl_seconds=86400  # 24 hours

    if [ ! -f "$draft_file" ]; then
        return 0
    fi

    # Get file modification time (cross-platform)
    local draft_mtime
    draft_mtime=$(stat -f %m "$draft_file" 2>/dev/null || stat -c %Y "$draft_file" 2>/dev/null || echo "0")
    local now
    now=$(date +%s)
    local age=$((now - draft_mtime))

    if [ "$age" -gt "$ttl_seconds" ]; then
        log "INFO" "Draft is ${age}s old (>24h), archiving and starting fresh"
        mv "$draft_file" "$PROJECT_DIR/SPEC.draft.$(date +%Y%m%d).old"
        return 1  # Signal to start fresh
    else
        log "INFO" "Draft is ${age}s old (<24h), continuing from draft"
        return 0  # Signal to continue from draft
    fi
}

# === Generate iteration stats ===

generate_iteration_stats() {
    local timestamp=$1
    local version=${2:-"unknown"}
    local stats_dir="$PROJECT_DIR/stats"
    mkdir -p "$stats_dir"

    local stats_file="$stats_dir/iteration-$timestamp.md"

    # Get iteration start time
    local start_time
    start_time=$(cat "$CLAUDEV_DIR/iteration_start.txt" 2>/dev/null || echo "unknown")
    local end_time
    end_time=$(date '+%Y-%m-%d %H:%M:%S')

    # Calculate duration
    local duration="unknown"
    if [ -f "$CLAUDEV_DIR/iteration_start.txt" ]; then
        local start_epoch end_epoch
        start_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$start_time" +%s 2>/dev/null || date -d "$start_time" +%s 2>/dev/null || echo "0")
        end_epoch=$(date +%s)
        if [ "$start_epoch" -gt 0 ]; then
            local dur_seconds=$((end_epoch - start_epoch))
            local dur_hours=$((dur_seconds / 3600))
            local dur_minutes=$(( (dur_seconds % 3600) / 60 ))
            duration="${dur_hours}h ${dur_minutes}m"
        fi
    fi

    # Get task stats from beads
    local total closed blocked
    total=$(bd list --format=json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
    closed=$(bd list --status=closed --format=json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
    blocked=$(bd list --format=json 2>/dev/null | jq '[.[] | select(.labels[]? | startswith("blocked:"))] | length' 2>/dev/null || echo "0")

    # Count agent runs from logs
    local manager_runs architect_runs executor_runs analyst_runs senior_runs
    manager_runs=$(grep -c "\[ORCHESTRATOR\].*Manager" "$LOGS_DIR/claudev.log" 2>/dev/null || echo "0")
    architect_runs=$(grep -c "Running agent: architect" "$LOGS_DIR/claudev.log" 2>/dev/null || echo "0")
    executor_runs=$(grep -c "Starting executor for" "$LOGS_DIR/claudev.log" 2>/dev/null || echo "0")
    analyst_runs=$(grep -c "Starting analyst-" "$LOGS_DIR/claudev.log" 2>/dev/null || echo "0")
    senior_runs=$(grep -c "Processing review for" "$LOGS_DIR/claudev.log" 2>/dev/null || echo "0")

    # Estimate tokens (rough: count chars in agent logs / 4)
    local total_chars estimated_tokens
    total_chars=$(find "$LOGS_DIR" -name "*.log" -newer "$CLAUDEV_DIR/iteration_start.txt" -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
    estimated_tokens=$((total_chars / 4))

    # Get blocked tasks details
    local blocked_details
    blocked_details=$(bd list --format=json 2>/dev/null | jq -r '.[] | select(.labels[]? | startswith("blocked:")) | "- `\(.id)`: \(.title)"' 2>/dev/null || echo "- none")

    # Generate report
    cat > "$stats_file" << EOF
# Iteration Report

**Started:** $start_time
**Completed:** $end_time
**Duration:** $duration

## Tasks
- Total created: $total
- Completed: $closed
- Blocked: $blocked

## Agents Activity
| Agent | Runs |
|-------|------|
| Manager | $manager_runs |
| Architect | $architect_runs |
| Executors | $executor_runs |
| Analysts | $analyst_runs |
| Senior Executor | $senior_runs |

**Estimated tokens:** ~$estimated_tokens (based on log size)

## Blocked Tasks
$blocked_details

---
*Generated by Claudev v$version*
EOF

    log "INFO" "Stats generated: $stats_file"
}

# === Phase dispatcher ===
# Orchestrator DIRECTLY calls scripts/agents by phase.
# Manager is called ONLY for problem resolution (blocked, retry limit, escalations).

dispatch_phase() {
    local phase=$1

    case $phase in
        INIT)
            # Check draft TTL first
            check_draft_ttl

            # Tech Writer creates SPEC.md (INTERACTIVE - needs user dialogue)
            if [ -f ".claude/agents/tech-writer.md" ]; then
                log "INFO" "INIT: Starting Tech Writer (interactive)..."
                run_interactive_agent "tech-writer" ".claude/agents/tech-writer.md" "opus"
            else
                log "WARN" "tech-writer.md not found, skipping INIT"
            fi
            ;;

        PLANNING)
            # Architect creates plan from SPEC.md
            log "INFO" "PLANNING: Starting Architect to create plan..."
            local spec_content
            spec_content=$(cat SPEC.md 2>/dev/null || echo "SPEC.md not found")
            run_agent_with_mode "architect" ".claude/agents/architect.md" "opus" "create_plan" "SPEC:
$spec_content"
            ;;

        HELPERS)
            # Create trigger tasks for analysts (if not exist), then run them
            log "INFO" "HELPERS: Creating analyst triggers and running analysts..."
            create_analyst_triggers
            ./scripts/run-analysts.sh

            # Check if all analysts done and create milestone (single source of truth)
            local open_triggers
            open_triggers=$(bd list --status=open --format=json 2>/dev/null | jq '[.[] | select(.title | startswith("run-analyst-"))] | length' 2>/dev/null || echo "0")
            if [ "$open_triggers" -eq 0 ]; then
                if ! bd list --format=json 2>/dev/null | jq -e '.[] | select(.labels[]? == "milestone:analysts-done")' > /dev/null 2>&1; then
                    log "INFO" "All analysts done, creating milestone"
                    bd create --title="Analysts complete" --type=task --label=milestone:analysts-done 2>/dev/null || true
                    local milestone_id
                    milestone_id=$(bd list --format=json 2>/dev/null | jq -r '.[] | select(.labels[]? == "milestone:analysts-done") | .id' | head -1)
                    [ -n "$milestone_id" ] && bd close "$milestone_id" 2>/dev/null || true
                fi
            fi
            ;;

        PLAN_REVIEW)
            # Architect reviews additions from Analysts
            log "INFO" "PLAN_REVIEW: Starting Architect to review plan..."
            # Create trigger task if not exists
            if ! bd list --format=json 2>/dev/null | jq -e '.[] | select(.title == "run-plan-review")' > /dev/null 2>&1; then
                bd create --title="run-plan-review" --type=task --priority=0 2>/dev/null || true
            fi
            run_agent_with_mode "architect" ".claude/agents/architect.md" "opus" "plan_review" ""
            ;;

        IMPLEMENTATION)
            # Run executors for open tasks, senior executor for reviews
            log "INFO" "IMPLEMENTATION: Running executors..."
            ./scripts/run-executors.sh
            ./scripts/run-senior-executor.sh
            ;;

        FINAL_REVIEW)
            # Architect does final review and versioning
            log "INFO" "FINAL_REVIEW: Starting Architect for final review..."
            run_agent_with_mode "architect" ".claude/agents/architect.md" "opus" "final_review" ""
            # Check if architect created project-done milestone
            check_and_create_done_milestone
            ;;

        DONE)
            log "INFO" "Project phase: DONE"
            return 0
            ;;

        *)
            log "WARN" "Unknown phase: $phase"
            ;;
    esac

    # After phase actions, check for problems and call Manager if needed
    check_problems_and_consult_manager
}

# === Main loop ===

main() {
    acquire_lock

    # Health check: claude CLI
    if ! command -v claude &>/dev/null; then
        log "FATAL" "Claude CLI not found. Install: npm install -g @anthropic/claude-code"
        exit 1
    fi

    # Find VERSION relative to this script (works with symlinks)
    local script_real_path claudev_root version
    script_real_path=$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")
    claudev_root=$(dirname "$(dirname "$(dirname "$script_real_path")")")
    version=$(cat "$claudev_root/VERSION" 2>/dev/null || echo "unknown")

    log "INFO" "=========================================="
    log "INFO" "ORCHESTRATOR STARTED (PID $$)"
    log "INFO" "Version: $version"
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

        # 4. Dispatch phase-specific actions
        dispatch_phase "$phase"

        # 5. Check for completion
        if [ "$phase" = "DONE" ]; then
            log "INFO" "=========================================="
            log "INFO" "PROJECT COMPLETE"
            log "INFO" "=========================================="

            # Generate iteration stats
            local timestamp
            timestamp=$(date +%Y%m%d-%H%M%S)
            generate_iteration_stats "$timestamp" "$version"

            # Archive logs
            mkdir -p "$LOGS_DIR/archive"
            mv "$LOGS_DIR/claudev.log" "$LOGS_DIR/archive/iteration-$timestamp.log" 2>/dev/null || true

            ./scripts/notify.sh "Project complete" "All tasks done" 2>/dev/null || true
            rm -f "$LOCK_FILE"
            exit 0
        fi

        # 6. Auto-close completed features and epics
        ./scripts/close-completed-parents.sh 2>/dev/null || true

        # 8. Pause before next iteration
        log "INFO" "Pause ${ITERATION_DELAY}s..."
        sleep "$ITERATION_DELAY"
    done

    log "WARN" "Max cycles reached ($max_cycles)"
    rm -f "$LOCK_FILE"
    exit 1
}

main "$@"
