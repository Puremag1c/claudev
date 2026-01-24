#!/bin/bash
#
# Claudev Invite Script
# One-liner установка виртуального отдела разработки
#
# Использование:
#   curl -fsSL https://raw.githubusercontent.com/Puremag1c/claudev/main/invite.sh | bash
#
# Или с конкретной веткой/тегом:
#   curl -fsSL https://raw.githubusercontent.com/Puremag1c/claudev/main/invite.sh | bash -s -- v0.1
#

set -euo pipefail

REPO="${CLAUDEV_REPO:-https://github.com/Puremag1c/claudev.git}"
BRANCH="${1:-main}"
TARGET=".claudev"

echo "=== Claudev Invite ==="
echo ""

# Проверяем git
if ! command -v git &>/dev/null; then
    echo "Error: git не установлен"
    echo "  brew install git  # macOS"
    echo "  apt install git   # Ubuntu/Debian"
    exit 1
fi

# Проверяем что не в корне системы
if [ "$PWD" = "/" ] || [ "$PWD" = "$HOME" ]; then
    echo "Error: запустите из директории проекта, не из / или ~"
    exit 1
fi

# Проверяем существующую установку
if [ -d "$TARGET" ]; then
    echo "Claudev уже установлен в $TARGET/"
    echo ""
    read -p "Переустановить? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Отменено"
        exit 0
    fi
    rm -rf "$TARGET"
fi

# Клонируем
echo "Клонирую claudev ($BRANCH)..."
git clone --depth 1 --branch "$BRANCH" "$REPO" "$TARGET" 2>/dev/null || \
git clone --depth 1 "$REPO" "$TARGET"

# Удаляем .git (не нужен, обновления через переустановку)
rm -rf "$TARGET/.git"

echo ""
echo "Запускаю установщик..."
echo ""

# Запускаем install.sh
"$TARGET/install.sh"
