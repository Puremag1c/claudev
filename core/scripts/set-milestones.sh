#!/bin/bash
# Проставляет milestones для пропуска фаз планирования
# Использование: ./set-milestones.sh [milestone1 milestone2 ...]
# Пример: ./set-milestones.sh planning-done helpers-done plan-reviewed

EPIC=$(bd list --json | jq -r '.[] | select(.type == "epic") | .id' | head -1)

if [ -z "$EPIC" ]; then
    echo "Эпик не найден. Создаю..."
    bd create "EPIC: Project" -t epic -p 0
    EPIC=$(bd list --json | jq -r '.[] | select(.type == "epic") | .id' | head -1)
fi

if [ $# -gt 0 ]; then
    MILESTONES=("$@")
else
    # По умолчанию все milestones планирования
    MILESTONES=("planning-done" "helpers-done" "plan-reviewed")
fi

for m in "${MILESTONES[@]}"; do
    bd label add "$EPIC" "milestone:$m" 2>/dev/null && echo "✓ milestone:$m"
done

echo ""
./scripts/detect-phase.sh
