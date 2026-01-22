#!/bin/bash
# Атомарно захватывает одну готовую задачу
# Использование: ./claim-task.sh [agent_id] [required_model]

set -e

LOCK_DIR="/tmp/beads-claim-lock"
AGENT_ID="${1:-coder-$$-$(date +%s)}"
REQUIRED_MODEL="${2:-}"

cleanup() { rmdir "$LOCK_DIR" 2>/dev/null || true; }
trap cleanup EXIT

# Захват лока через mkdir (атомарно)
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then break; fi
    if [ "$attempt" -eq 10 ]; then
        echo '{"status":"locked","task":null}'
        exit 0
    fi
    sleep 0.$((RANDOM % 5 + 1))
done

# Получаем ready задачи
READY_JSON=$(bd ready --json 2>/dev/null || echo "[]")

# Фильтруем по модели
if [ -n "$REQUIRED_MODEL" ]; then
    FILTERED=$(echo "$READY_JSON" | jq -c --arg m "model:$REQUIRED_MODEL" '[.[] | select(.labels | index($m))]')
else
    FILTERED="$READY_JSON"
fi

# Исключаем in_progress
IN_PROGRESS_IDS=$(bd list --status in_progress --json 2>/dev/null | jq -r '.[].id' | tr '\n' '|' | sed 's/|$//')
[ -z "$IN_PROGRESS_IDS" ] && IN_PROGRESS_IDS="^$"

TASK=$(echo "$FILTERED" | jq -c --arg taken "$IN_PROGRESS_IDS" '
    [.[] | select(.status == "open")] |
    if ($taken == "^$") then .[0] else [.[] | select(.id | test($taken) | not)][0] end
')

if [ "$TASK" == "null" ] || [ -z "$TASK" ]; then
    echo '{"status":"no_tasks","task":null}'
    exit 0
fi

TASK_ID=$(echo "$TASK" | jq -r '.id')

# Двойная проверка
CURRENT=$(bd show "$TASK_ID" --json 2>/dev/null | jq -r '.status' || echo "unknown")
if [ "$CURRENT" != "open" ]; then
    echo '{"status":"already_taken","task":null}'
    exit 0
fi

# Захватываем
bd update "$TASK_ID" --status in_progress 2>/dev/null
bd label add "$TASK_ID" "assignee:$AGENT_ID" 2>/dev/null || true

echo "$TASK" | jq -c --arg a "$AGENT_ID" '. + {status:"claimed",assignee:$a}'
