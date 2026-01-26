#!/bin/bash
# core/scripts/detect-phase.sh
# Определяет текущую фазу проекта из состояния Beads и файлов.
#
# Фазы: INIT → PLANNING → HELPERS → PLAN_REVIEW → IMPLEMENTATION → FINAL_REVIEW → DONE
#
# Использование: ./scripts/detect-phase.sh
# Выводит: PHASE_NAME (одно слово, для использования в скриптах)

set -euo pipefail

# Находим корень проекта
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

# Проверяем beads
if ! command -v bd &> /dev/null; then
    echo "ERROR"
    >&2 echo "Beads (bd) не установлен"
    exit 1
fi

# Собираем статистику из beads
get_count() {
    local filter=$1
    bd list $filter --format=json 2>/dev/null | jq 'length' 2>/dev/null || echo "0"
}

has_label() {
    local label=$1
    bd list --format=json 2>/dev/null | jq "[.[] | select(.labels[]? == \"$label\")] | length" 2>/dev/null || echo "0"
}

has_open_task() {
    local title_pattern=$1
    bd list --status=open --format=json 2>/dev/null | jq "[.[] | select(.title | test(\"$title_pattern\"))] | length" 2>/dev/null || echo "0"
}

# Статистика
TOTAL=$(get_count "")
OPEN=$(get_count "--status=open")
IN_PROGRESS=$(get_count "--status=in_progress")
CLOSED=$(get_count "--status=closed")

# Milestones (через labels)
HAS_PLANNING_DONE=$(has_label "milestone:planning-done")
HAS_ANALYSTS_DONE=$(has_label "milestone:analysts-done")
HAS_PLAN_REVIEWED=$(has_label "milestone:plan-reviewed")
HAS_PROJECT_DONE=$(has_label "milestone:project-done")

# Trigger tasks для analysts
ANALYST_TRIGGERS_OPEN=$(has_open_task "^run-analyst-")
PLAN_REVIEW_OPEN=$(has_open_task "^run-plan-review$")

# === Определение фазы ===

# DONE: проект завершён
if [ "$HAS_PROJECT_DONE" -gt 0 ]; then
    echo "DONE"
    exit 0
fi

# INIT: нет SPEC.md → нужен Tech Writer
if [ ! -f "$PROJECT_ROOT/SPEC.md" ]; then
    # Проверяем есть ли draft
    if [ -f "$PROJECT_ROOT/SPEC.draft.md" ]; then
        echo "INIT"  # Продолжаем с draft
    else
        echo "INIT"  # Начинаем с нуля
    fi
    exit 0
fi

# PLANNING: есть SPEC.md, но нет плана (milestone:planning-done)
if [ "$HAS_PLANNING_DONE" -eq 0 ]; then
    echo "PLANNING"
    exit 0
fi

# HELPERS (Analysts): план есть, но analysts не завершили
if [ "$HAS_ANALYSTS_DONE" -eq 0 ]; then
    echo "HELPERS"
    exit 0
fi

# PLAN_REVIEW: analysts закончили, Architect ревьюит
if [ "$HAS_PLAN_REVIEWED" -eq 0 ]; then
    echo "PLAN_REVIEW"
    exit 0
fi

# IMPLEMENTATION: есть открытые или in_progress задачи
if [ "$OPEN" -gt 0 ] || [ "$IN_PROGRESS" -gt 0 ]; then
    echo "IMPLEMENTATION"
    exit 0
fi

# FINAL_REVIEW: все задачи closed, финальная проверка
if [ "$CLOSED" -gt 0 ] && [ "$OPEN" -eq 0 ] && [ "$IN_PROGRESS" -eq 0 ]; then
    echo "FINAL_REVIEW"
    exit 0
fi

# UNKNOWN: не удалось определить
echo "UNKNOWN"
>&2 echo "Stats: total=$TOTAL, open=$OPEN, in_progress=$IN_PROGRESS, closed=$CLOSED"
>&2 echo "Milestones: planning=$HAS_PLANNING_DONE, analysts=$HAS_ANALYSTS_DONE, reviewed=$HAS_PLAN_REVIEWED, done=$HAS_PROJECT_DONE"
exit 1
