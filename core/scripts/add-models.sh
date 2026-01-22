#!/bin/bash
# Добавляет model labels к существующим задачам
# Использование: ./add-models.sh [default_model]
# Пример: ./add-models.sh sonnet

DEFAULT_MODEL="${1:-sonnet}"

echo "Добавление model:$DEFAULT_MODEL ко всем задачам без модели..."

for id in $(bd list --json | jq -r '.[] | select(.labels | any(startswith("model:")) | not) | .id'); do
    bd label add "$id" "model:$DEFAULT_MODEL" 2>/dev/null && echo "  $id <- model:$DEFAULT_MODEL"
done

echo ""
echo "Готово. Теперь измени конкретные задачи на opus/haiku:"
echo "  bd label remove bd-XXXX model:sonnet"
echo "  bd label add bd-XXXX model:opus"
