#!/bin/bash
# Определяет текущую фазу проекта из состояния Beads

set -e

if ! command -v bd &> /dev/null; then
    echo "PHASE:ERROR"
    echo "ACTION:install-beads"
    echo "REASON:Beads (bd) не установлен"
    exit 1
fi

TOTAL=$(bd list --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
OPEN=$(bd list --status open --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
IN_PROGRESS=$(bd list --status in_progress --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
CLOSED=$(bd list --status closed --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
BLOCKED=$(bd list --status blocked --json 2>/dev/null | jq 'length' 2>/dev/null || echo "0")

HAS_PLANNING_DONE=$(bd list --json 2>/dev/null | jq '[.[] | select(.labels | index("milestone:planning-done"))] | length' 2>/dev/null || echo "0")
HAS_HELPERS_DONE=$(bd list --json 2>/dev/null | jq '[.[] | select(.labels | index("milestone:helpers-done"))] | length' 2>/dev/null || echo "0")
HAS_PLAN_REVIEWED=$(bd list --json 2>/dev/null | jq '[.[] | select(.labels | index("milestone:plan-reviewed"))] | length' 2>/dev/null || echo "0")
HAS_PROJECT_DONE=$(bd list --json 2>/dev/null | jq '[.[] | select(.labels | index("milestone:project-done"))] | length' 2>/dev/null || echo "0")

if [ "$TOTAL" -eq 0 ]; then
    echo "PHASE:INIT"
    echo "ACTION:run-architect"
    echo "REASON:План отсутствует"
elif [ "$HAS_PROJECT_DONE" -gt 0 ]; then
    echo "PHASE:DONE"
    echo "ACTION:none"
    echo "REASON:Проект завершён"
elif [ "$HAS_PLANNING_DONE" -eq 0 ]; then
    echo "PHASE:PLANNING"
    echo "ACTION:run-architect"
    echo "REASON:Нет milestone:planning-done"
elif [ "$HAS_HELPERS_DONE" -eq 0 ]; then
    echo "PHASE:HELPERS"
    echo "ACTION:run-helpers"
    echo "REASON:Нет milestone:helpers-done"
elif [ "$HAS_PLAN_REVIEWED" -eq 0 ]; then
    echo "PHASE:PLAN_REVIEW"
    echo "ACTION:run-architect-review"
    echo "REASON:Нет milestone:plan-reviewed"
elif [ "$OPEN" -gt 0 ] || [ "$IN_PROGRESS" -gt 0 ]; then
    echo "PHASE:IMPLEMENTATION"
    echo "ACTION:run-coders"
    echo "REASON:open=$OPEN, in_progress=$IN_PROGRESS, blocked=$BLOCKED"
elif [ "$CLOSED" -gt 0 ] && [ "$OPEN" -eq 0 ] && [ "$IN_PROGRESS" -eq 0 ]; then
    echo "PHASE:FINAL_REVIEW"
    echo "ACTION:run-final-review"
    echo "REASON:Все задачи закрыты"
else
    echo "PHASE:UNKNOWN"
    echo "ACTION:manual"
    echo "REASON:Не удалось определить"
fi

>&2 echo "---"
>&2 echo "Stats: total=$TOTAL, open=$OPEN, in_progress=$IN_PROGRESS, closed=$CLOSED, blocked=$BLOCKED"
>&2 echo "Milestones: planning=$HAS_PLANNING_DONE, helpers=$HAS_HELPERS_DONE, reviewed=$HAS_PLAN_REVIEWED, done=$HAS_PROJECT_DONE"
