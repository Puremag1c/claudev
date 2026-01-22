#!/usr/bin/env bash
#
# Claudev Installer
# Устанавливает систему в целевой проект
#
# Использование:
#   git clone git@github.com:user/claudev.git .claudev
#   .claudev/install.sh
#

set -euo pipefail

# Определяем директории
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$(dirname "$SCRIPT_DIR")"
CLAUDEV_DIR_NAME="$(basename "$SCRIPT_DIR")"

echo "=== Claudev Installer ==="
echo "Claudev dir: $SCRIPT_DIR"
echo "Target dir:  $TARGET_DIR"
echo ""

# Проверяем что запускаем из подпапки проекта
if [[ "$SCRIPT_DIR" == "$TARGET_DIR" ]]; then
    echo "Error: claudev должен быть клонирован в подпапку проекта"
    echo ""
    echo "Правильно:"
    echo "  cd your-project"
    echo "  git clone <repo> .claudev"
    echo "  .claudev/install.sh"
    exit 1
fi

# Проверяем наличие core/
if [[ ! -d "$SCRIPT_DIR/core" ]]; then
    echo "Error: не найдена папка core/ в $SCRIPT_DIR"
    exit 1
fi

# Создаём .claude/ с симлинками
echo "Creating .claude/ directory..."
mkdir -p "$TARGET_DIR/.claude"

# Симлинк на agents
if [[ -L "$TARGET_DIR/.claude/agents" ]]; then
    rm "$TARGET_DIR/.claude/agents"
fi
if [[ -d "$TARGET_DIR/.claude/agents" ]]; then
    echo "Warning: .claude/agents/ уже существует как папка, пропускаю"
else
    ln -s "../$CLAUDEV_DIR_NAME/core/agents" "$TARGET_DIR/.claude/agents"
    echo "  ✓ .claude/agents -> $CLAUDEV_DIR_NAME/core/agents"
fi

# Симлинк на commands
if [[ -L "$TARGET_DIR/.claude/commands" ]]; then
    rm "$TARGET_DIR/.claude/commands"
fi
if [[ -d "$TARGET_DIR/.claude/commands" ]]; then
    echo "Warning: .claude/commands/ уже существует как папка, пропускаю"
else
    ln -s "../$CLAUDEV_DIR_NAME/core/commands" "$TARGET_DIR/.claude/commands"
    echo "  ✓ .claude/commands -> $CLAUDEV_DIR_NAME/core/commands"
fi

# Симлинк на scripts
if [[ -L "$TARGET_DIR/scripts" ]]; then
    rm "$TARGET_DIR/scripts"
fi
if [[ -d "$TARGET_DIR/scripts" ]]; then
    echo "Warning: scripts/ уже существует как папка, пропускаю"
else
    ln -s "$CLAUDEV_DIR_NAME/core/scripts" "$TARGET_DIR/scripts"
    echo "  ✓ scripts -> $CLAUDEV_DIR_NAME/core/scripts"
fi

# Копируем шаблоны (если не существуют)
echo ""
echo "Copying templates..."

if [[ -f "$TARGET_DIR/SPEC.md" ]]; then
    echo "  - SPEC.md уже существует, пропускаю"
else
    cp "$SCRIPT_DIR/templates/SPEC.template.md" "$TARGET_DIR/SPEC.md"
    echo "  ✓ SPEC.md создан"
fi

# Создаём рабочие директории
echo ""
echo "Creating work directories..."
mkdir -p "$TARGET_DIR/logs" "$TARGET_DIR/worktrees"
echo "  ✓ logs/"
echo "  ✓ worktrees/"

echo ""
echo "=== Installation complete ==="
echo ""
echo "Следующие шаги:"
echo "  1. Заполните SPEC.md спецификацией проекта"
echo "  2. Запустите систему: ./scripts/orchestrator.sh"
echo ""
