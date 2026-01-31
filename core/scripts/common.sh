#!/bin/bash
# core/scripts/common.sh
# Общие функции для всех скриптов hype

# Disable terminal color queries from beads (causes garbage escape sequences)
export NO_COLOR=1

# timeout_cmd - кроссплатформенный timeout (macOS + Linux)
# Использование: timeout_cmd DURATION COMMAND [ARGS...]
# Пример: timeout_cmd 5m claude -p "prompt"
timeout_cmd() {
    local duration="$1"
    shift

    # Use gtimeout on macOS (brew install coreutils)
    if command -v gtimeout &>/dev/null; then
        gtimeout "$duration" "$@"
        return $?
    fi

    # Use timeout on Linux
    if command -v timeout &>/dev/null; then
        timeout "$duration" "$@"
        return $?
    fi

    # Convert duration to seconds for fallback
    local seconds
    case "$duration" in
        *m) seconds=$((${duration%m} * 60)) ;;
        *s) seconds=${duration%s} ;;
        *h) seconds=$((${duration%h} * 3600)) ;;
        *) seconds=$duration ;;
    esac

    # Perl-based timeout (macOS native fallback)
    perl -e '
        my $timeout = shift @ARGV;
        my $pid = fork();
        if ($pid == 0) {
            exec @ARGV or die "exec failed: $!";
        }
        $SIG{ALRM} = sub { kill "TERM", $pid; exit 124; };
        alarm $timeout;
        waitpid $pid, 0;
        alarm 0;
        exit ($? >> 8);
    ' "$seconds" "$@"
}

# Экспортируем функцию для подоболочек
export -f timeout_cmd 2>/dev/null || true

# append_notes - добавляет к существующим notes вместо перезаписи
# Использование: append_notes TASK_ID "new note text"
# Сохраняет review feedback и другую важную информацию
append_notes() {
    local task_id="$1"
    local new_note="$2"
    local current_notes
    current_notes=$(bd show "$task_id" --json 2>/dev/null | jq -r '.[0].notes // ""' 2>/dev/null || echo "")

    if [ -n "$current_notes" ]; then
        echo "$current_notes

---
$new_note"
    else
        echo "$new_note"
    fi
}
export -f append_notes 2>/dev/null || true
