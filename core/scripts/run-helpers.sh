#!/bin/bash
# Запускает помощников параллельно
# Использование: ./run-helpers.sh [helper1 helper2 ...]
# Примеры: ./run-helpers.sh          # все
#          ./run-helpers.sh ux ops   # только ux и ops

set -e

PROJECT_DIR=$(pwd)
LOGS_DIR="$PROJECT_DIR/logs"
TIMEOUT=1800

mkdir -p "$LOGS_DIR"

[ $# -gt 0 ] && HELPERS=("$@") || HELPERS=("arch" "rel" "ux" "ops")

declare -A NAMES=(["arch"]="architecture" ["rel"]="reliability" ["ux"]="ux" ["ops"]="ops")
declare -A PROMPTS=(
    ["arch"]="Проанализируй план на архитектурные проблемы"
    ["rel"]="Проанализируй план на проблемы надёжности и edge cases"
    ["ux"]="Проанализируй план на UX проблемы"
    ["ops"]="Проанализируй план на проблемы тестирования и деплоя"
)

echo "$(date '+%H:%M:%S') Запуск: ${HELPERS[*]}"
rm -f "$PROJECT_DIR"/.helper-done-* 2>/dev/null

for h in "${HELPERS[@]}"; do
    (
        claude --model sonnet -p "
Ты helper-${NAMES[$h]}. ${PROMPTS[$h]}
Следуй инструкциям из .claude/agents/helper-${NAMES[$h]}.md
Создавай задачи с label source:helper-$h
После завершения: bd sync
" > "$LOGS_DIR/helper-$h.log" 2>&1 || true
        touch "$PROJECT_DIR/.helper-done-$h"
    ) &
    echo "  Запущен helper-$h (PID: $!)"
done

START=$(date +%s)
while true; do
    DONE=0
    for h in "${HELPERS[@]}"; do [ -f "$PROJECT_DIR/.helper-done-$h" ] && ((DONE++)); done
    [ "$DONE" -eq "${#HELPERS[@]}" ] && break
    [ $(($(date +%s) - START)) -gt $TIMEOUT ] && { echo "TIMEOUT"; pkill -f claude || true; break; }
    sleep 5
done

rm -f "$PROJECT_DIR"/.helper-done-*
EPIC=$(bd list --json 2>/dev/null | jq -r '.[] | select(.type == "epic") | .id' | head -1)
[ -n "$EPIC" ] && bd label add "$EPIC" "milestone:helpers-done" 2>/dev/null || true
bd sync 2>/dev/null || true

echo "$(date '+%H:%M:%S') Помощники завершены"
./scripts/notify.sh "Помощники завершены" "${HELPERS[*]}" 2>/dev/null || true
