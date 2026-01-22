#!/bin/bash
# scripts/init-manager.sh
# Инициализирует или сбрасывает состояние менеджера в Beads
#
# Использование:
#   ./scripts/init-manager.sh              # Создать если нет
#   ./scripts/init-manager.sh --reset      # Сбросить в начальное состояние
#   ./scripts/init-manager.sh --phase X    # Установить конкретную фазу

set -e

RESET=false
PHASE="INIT"
HELPER_CYCLES=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --reset)
            RESET=true
            shift
            ;;
        --phase)
            PHASE="$2"
            shift 2
            ;;
        --helper-cycles)
            HELPER_CYCLES="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Найди существующую задачу менеджера
MANAGER_ID=$(bd list --json 2>/dev/null | jq -r '.[] | select(.labels | index("role:manager")) | .id' || echo "")

if [ "$RESET" = true ] && [ -n "$MANAGER_ID" ] && [ "$MANAGER_ID" != "null" ]; then
    echo "Удаление старого состояния: $MANAGER_ID"
    bd delete "$MANAGER_ID" 2>/dev/null || true
    MANAGER_ID=""
fi

if [ -z "$MANAGER_ID" ] || [ "$MANAGER_ID" == "null" ]; then
    echo "Создание состояния менеджера..."
    
    STATE=$(cat << STATEJSON
{
  "phase": "$PHASE",
  "cycle": 0,
  "helper_cycles": $HELPER_CYCLES,
  "last_action": null,
  "last_decision": "Initial state",
  "blockers_seen": [],
  "decisions": []
}
STATEJSON
)
    
    bd create "MANAGER: Project State" -t meta -p 0 -l role:manager -d "$STATE"
    
    MANAGER_ID=$(bd list --json | jq -r '.[] | select(.labels | index("role:manager")) | .id')
    echo "✓ Создано: $MANAGER_ID"
else
    echo "Состояние менеджера уже существует: $MANAGER_ID"
fi

echo ""
echo "=== MANAGER STATE ==="
bd show "$MANAGER_ID" --json | jq '.description | fromjson'
