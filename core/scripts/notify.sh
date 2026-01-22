#!/bin/bash
TITLE="${1:-AI Dev}"
MSG="${2:-Уведомление}"
osascript -e "display notification \"$MSG\" with title \"$TITLE\" sound name \"Glass\"" 2>/dev/null || true
echo "🔔 $TITLE: $MSG"
