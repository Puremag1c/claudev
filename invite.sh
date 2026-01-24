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

# === Определяем систему ===

OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="windows"
fi

# === Windows: требуется WSL ===

if [[ "$OS" == "windows" ]]; then
    echo "Windows detected."
    echo ""
    echo "Claudev требует WSL (Windows Subsystem for Linux)."
    echo ""
    echo "1. Установите WSL (откройте PowerShell как администратор):"
    echo "   wsl --install"
    echo ""
    echo "2. Перезагрузите компьютер"
    echo ""
    echo "3. Откройте Ubuntu из меню Пуск и запустите:"
    echo "   curl -fsSL https://raw.githubusercontent.com/Puremag1c/claudev/main/invite.sh | bash"
    echo ""
    exit 1
fi

echo "Система: $OS"
echo ""

# === Устанавливаем git если нужно ===

if ! command -v git &>/dev/null; then
    echo "Git не найден, устанавливаю..."

    if [[ "$OS" == "macos" ]]; then
        # macOS: через Xcode Command Line Tools
        echo "Запускаю xcode-select --install..."
        echo "Следуйте инструкциям в появившемся окне."
        xcode-select --install 2>/dev/null || true

        # Ждём установки
        echo "Ожидаю завершения установки Xcode CLI..."
        until command -v git &>/dev/null; do
            sleep 5
        done
        echo "  ✓ Git установлен"

    elif [[ "$OS" == "linux" ]]; then
        # Linux: через apt
        if command -v apt &>/dev/null; then
            echo "Устанавливаю через apt..."
            sudo apt update && sudo apt install -y git
            echo "  ✓ Git установлен"
        else
            echo "Error: apt не найден. Установите git вручную."
            exit 1
        fi
    else
        echo "Error: неизвестная система. Установите git вручную."
        exit 1
    fi
fi

echo "  ✓ Git: $(git --version)"

# === Проверяем что не в корне системы ===

if [ "$PWD" = "/" ] || [ "$PWD" = "$HOME" ]; then
    echo ""
    echo "Error: запустите из директории проекта, не из / или ~"
    echo ""
    echo "Пример:"
    echo "  mkdir my-project && cd my-project"
    echo "  curl -fsSL https://raw.githubusercontent.com/Puremag1c/claudev/main/invite.sh | bash"
    exit 1
fi

# === Проверяем существующую установку ===

if [ -d "$TARGET" ]; then
    echo ""
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

# === Клонируем ===

echo ""
echo "Клонирую claudev ($BRANCH)..."
git clone --depth 1 --branch "$BRANCH" "$REPO" "$TARGET" 2>/dev/null || \
git clone --depth 1 "$REPO" "$TARGET"

# Удаляем .git (не нужен, обновления через переустановку)
rm -rf "$TARGET/.git"

echo ""
echo "Запускаю установщик..."
echo ""

# === Запускаем install.sh ===

"$TARGET/install.sh" --auto-install
