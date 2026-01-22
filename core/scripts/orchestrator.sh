#!/bin/bash
# scripts/orchestrator.sh
# Пинает менеджера в цикле. Менеджер сам решает что делать.
#
# Использование:
#   ./scripts/orchestrator.sh           # Интерактивно
#   ./scripts/orchestrator.sh &         # В фоне
#   nohup ./scripts/orchestrator.sh &   # Переживёт закрытие терминала

set -e

PROJECT_DIR=$(pwd)
LOGS_DIR="$PROJECT_DIR/logs"
MAX_CYCLES="${MAX_CYCLES:-100}"
PAUSE_SECONDS="${PAUSE_SECONDS:-10}"

mkdir -p "$LOGS_DIR"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOGS_DIR/orchestrator.log"
}

log "=========================================="
log "ORCHESTRATOR STARTED"
log "Project: $PROJECT_DIR"
log "Max cycles: $MAX_CYCLES"
log "Pause: ${PAUSE_SECONDS}s"
log "=========================================="

CYCLE=0

while [ $CYCLE -lt $MAX_CYCLES ]; do
    ((CYCLE++))
    
    log "--- Cycle $CYCLE ---"
    log "Вызов менеджера..."
    
    # Вызываем менеджера
    MANAGER_OUT=$(claude --model sonnet -p "
Ты Менеджер проекта. Продолжи работу.

Следуй инструкциям из .claude/agents/manager.md

КРИТИЧНО:
1. СНАЧАЛА прочитай своё состояние из Beads (задача с label role:manager)
2. Определи текущую фазу и что делать
3. Выполни ОДНО действие
4. ОБЯЗАТЕЛЬНО сохрани новое состояние в Beads
5. Если проект завершён — напиши PROJECT_COMPLETE

Не забудь вывести своё решение в формате:
=== MANAGER DECISION ===
Cycle: N
Phase: OLD → NEW
Action: что делаешь
Reason: почему
========================
" 2>&1 | tee "$LOGS_DIR/manager-$CYCLE.log")
    
    # Проверяем завершение
    if echo "$MANAGER_OUT" | grep -q "PROJECT_COMPLETE"; then
        log "=========================================="
        log "PROJECT COMPLETE"
        log "=========================================="
        ./scripts/notify.sh "Проект завершён! 🎉" "Все задачи выполнены" 2>/dev/null || true
        
        # Показываем финальную статистику
        echo ""
        echo "=== ФИНАЛЬНАЯ СТАТИСТИКА ==="
        bd list --json 2>/dev/null | jq 'group_by(.status) | map({status: .[0].status, count: length})' || true
        
        exit 0
    fi
    
    # Проверяем критические ошибки
    if echo "$MANAGER_OUT" | grep -qi "CRITICAL_ERROR\|FATAL"; then
        log "CRITICAL ERROR detected!"
        ./scripts/notify.sh "Критическая ошибка" "Смотри logs/manager-$CYCLE.log" 2>/dev/null || true
        exit 1
    fi
    
    # Логируем решение менеджера
    DECISION=$(echo "$MANAGER_OUT" | grep -A5 "MANAGER DECISION" | head -6 || echo "No decision found")
    log "Decision: $(echo "$DECISION" | tr '\n' ' ')"
    
    log "Пауза ${PAUSE_SECONDS}s..."
    sleep $PAUSE_SECONDS
done

log "Достигнут лимит циклов ($MAX_CYCLES)"
./scripts/notify.sh "Лимит циклов" "Orchestrator остановлен после $MAX_CYCLES циклов" 2>/dev/null || true
exit 1
