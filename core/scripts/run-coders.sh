#!/bin/bash
# Запускает кодеров параллельно
# Использование: ./run-coders.sh [num_coders]

set -e

PROJECT_DIR=$(pwd)
LOGS_DIR="$PROJECT_DIR/logs"
NUM="${1:-2}"
MAX_TASKS=20

mkdir -p "$LOGS_DIR"

run_coder() {
    local id=$1
    local done=0
    
    while [ $done -lt $MAX_TASKS ]; do
        CLAIM=$("$PROJECT_DIR/scripts/claim-task.sh" "coder-$id")
        STATUS=$(echo "$CLAIM" | jq -r '.status')
        
        [ "$STATUS" != "claimed" ] && break
        
        TASK_ID=$(echo "$CLAIM" | jq -r '.id')
        MODEL=$(echo "$CLAIM" | jq -r '.labels | map(select(startswith("model:"))) | .[0] | split(":")[1] // "sonnet"')
        
        echo "[coder-$id] $TASK_ID ($MODEL)"
        
        claude --model "$MODEL" -p "
Ты Кодер (coder-$id). Задача: $TASK_ID
Следуй .claude/agents/coder.md
После завершения: bd close $TASK_ID --reason \"...\" && bd sync
ОСТАНОВИСЬ после закрытия.
" > "$LOGS_DIR/coder-$id-$TASK_ID.log" 2>&1 || true
        
        # Ревью
        claude --model sonnet -p "Ты Ревьюер. Проверь $TASK_ID. Следуй .claude/agents/reviewer.md" \
            > "$LOGS_DIR/review-$TASK_ID.log" 2>&1 || true
        bd label add "$TASK_ID" reviewed 2>/dev/null || true
        
        ((done++))
        sleep 2
    done
    
    touch "$PROJECT_DIR/.coder-done-$id"
    echo "[coder-$id] Завершён ($done задач)"
}

echo "$(date '+%H:%M:%S') Запуск $NUM кодеров"

for i in $(seq 1 $NUM); do run_coder $i & done

while true; do
    DONE=0
    for i in $(seq 1 $NUM); do [ -f "$PROJECT_DIR/.coder-done-$i" ] && ((DONE++)); done
    [ "$DONE" -eq "$NUM" ] && break
    sleep 10
done

rm -f "$PROJECT_DIR"/.coder-done-*
bd sync 2>/dev/null || true

echo "$(date '+%H:%M:%S') Кодеры завершены"
bd list --json | jq 'group_by(.status) | map({status: .[0].status, count: length})'
./scripts/notify.sh "Кодеры завершены" "Проверьте статус" 2>/dev/null || true
