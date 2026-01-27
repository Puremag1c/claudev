#!/usr/bin/env bash
#
# Claudev Installer
# Устанавливает систему в целевой проект
#
# Использование:
#   .claudev/install.sh              # Интерактивный режим
#   .claudev/install.sh --auto-install   # Автоустановка зависимостей
#

set -euo pipefail

# === Определяем директории ===

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$(dirname "$SCRIPT_DIR")"
CLAUDEV_DIR_NAME="$(basename "$SCRIPT_DIR")"
AUTO_INSTALL="${1:-}"

echo "=== Claudev Installer ==="
echo "Claudev dir: $SCRIPT_DIR"
echo "Target dir:  $TARGET_DIR"
echo ""

# === Проверка директории ===

if [[ "$SCRIPT_DIR" == "$TARGET_DIR" ]]; then
    echo "Error: claudev должен быть в подпапке проекта"
    echo ""
    echo "Правильно:"
    echo "  cd your-project"
    echo "  curl -fsSL https://raw.githubusercontent.com/Puremag1c/claudev/main/invite.sh | bash"
    exit 1
fi

if [[ ! -d "$SCRIPT_DIR/core" ]]; then
    echo "Error: не найдена папка core/ в $SCRIPT_DIR"
    exit 1
fi

# === Определяем систему ===

OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
fi

# === Функции установки ===

install_homebrew() {
    if ! command -v brew &>/dev/null; then
        echo "Homebrew не найден, устанавливаю..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Добавляем brew в PATH для текущей сессии
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f "/usr/local/bin/brew" ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        echo "  ✓ Homebrew установлен"
    fi
}

install_with_brew() {
    local pkg=$1
    local cmd=${2:-$1}

    if ! command -v "$cmd" &>/dev/null; then
        echo "  Устанавливаю $pkg через brew..."
        brew install "$pkg"
        echo "  ✓ $pkg установлен"
    fi
}

install_with_apt() {
    local pkg=$1
    local cmd=${2:-$1}

    if ! command -v "$cmd" &>/dev/null; then
        echo "  Устанавливаю $pkg через apt..."
        sudo apt install -y "$pkg"
        echo "  ✓ $pkg установлен"
    fi
}

install_claude_code() {
    if ! command -v claude &>/dev/null; then
        echo "  Устанавливаю Claude Code (официальный скрипт)..."
        curl -fsSL https://claude.ai/install.sh | bash
        echo "  ✓ Claude Code установлен"
    fi
}

# === Проверка и установка зависимостей ===

echo "Проверяю зависимости..."
echo ""

if [[ "$AUTO_INSTALL" == "--auto-install" ]]; then

    # === macOS ===
    if [[ "$OS" == "macos" ]]; then
        install_homebrew

        echo "Устанавливаю зависимости (macOS)..."
        install_with_brew "beads" "bd"
        install_with_brew "gh"
        install_with_brew "jq"
        install_claude_code

        # gitleaks опционально
        if ! command -v gitleaks &>/dev/null; then
            echo "  Устанавливаю gitleaks (опционально)..."
            brew install gitleaks || echo "  - gitleaks пропущен"
        fi

    # === Linux ===
    elif [[ "$OS" == "linux" ]]; then
        if command -v apt &>/dev/null; then
            echo "Устанавливаю зависимости (Linux/apt)..."
            sudo apt update

            install_with_apt "gh"
            install_with_apt "jq"
            install_claude_code

            # beads через npm на Linux (если нет brew)
            if ! command -v bd &>/dev/null; then
                if command -v npm &>/dev/null; then
                    echo "  Устанавливаю beads через npm..."
                    npm install -g beads
                    echo "  ✓ beads установлен"
                else
                    echo "  Warning: npm не найден, beads нужно установить вручную"
                fi
            fi
        else
            echo "Error: apt не найден. Установите зависимости вручную."
            exit 1
        fi
    else
        echo "Error: неизвестная система ($OS)"
        exit 1
    fi

else
    # === Без автоустановки — только проверка ===

    missing=()

    command -v bd &>/dev/null || missing+=("beads")
    command -v claude &>/dev/null || missing+=("claude-code")
    command -v gh &>/dev/null || missing+=("gh")
    command -v jq &>/dev/null || missing+=("jq")

    if [ ${#missing[@]} -gt 0 ]; then
        echo "Не хватает: ${missing[*]}"
        echo ""
        echo "Установите вручную или запустите:"
        echo "  $SCRIPT_DIR/install.sh --auto-install"
        exit 1
    fi
fi

# === Проверяем что всё установлено ===

echo ""
echo "Проверяю установку..."

check_cmd() {
    local cmd=$1
    local name=${2:-$1}
    if command -v "$cmd" &>/dev/null; then
        echo "  ✓ $name"
    else
        echo "  ✗ $name НЕ УСТАНОВЛЕН"
        return 1
    fi
}

check_cmd "bd" "beads"
check_cmd "claude" "claude-code"
check_cmd "gh" "gh (GitHub CLI)"
check_cmd "jq" "jq"

GITLEAKS_AVAILABLE=false
command -v gitleaks &>/dev/null && GITLEAKS_AVAILABLE=true
if [ "$GITLEAKS_AVAILABLE" = true ]; then
    echo "  ✓ gitleaks (опционально)"
else
    echo "  - gitleaks (опционально, не установлен)"
fi

# === Git ===

echo ""
echo "Настраиваю git..."

cd "$TARGET_DIR"

if [[ ! -d ".git" ]]; then
    echo "  Инициализирую git репозиторий..."
    git init
    echo "  ✓ git init"
else
    echo "  ✓ .git/ существует"
fi

# Проверяем remote
if ! git remote -v | grep -q origin; then
    echo "  - Warning: нет git remote"
    echo "    Добавьте позже: git remote add origin <url>"
fi

# === Beads ===

echo ""
echo "Настраиваю beads..."

if [[ ! -d ".beads" ]]; then
    echo "  Инициализирую beads..."
    bd init
    echo "  ✓ bd init"
else
    echo "  ✓ .beads/ существует"
fi

# === Создаём .claude/ с симлинками ===

echo ""
echo "Создаю симлинки..."

mkdir -p "$TARGET_DIR/.claude"

# Симлинк на agents
if [[ -L "$TARGET_DIR/.claude/agents" ]]; then
    rm "$TARGET_DIR/.claude/agents"
fi
if [[ -d "$TARGET_DIR/.claude/agents" ]]; then
    echo "  - .claude/agents/ уже папка, пропускаю"
else
    ln -s "../$CLAUDEV_DIR_NAME/core/agents" "$TARGET_DIR/.claude/agents"
    echo "  ✓ .claude/agents -> $CLAUDEV_DIR_NAME/core/agents"
fi

# Симлинк на commands
if [[ -L "$TARGET_DIR/.claude/commands" ]]; then
    rm "$TARGET_DIR/.claude/commands"
fi
if [[ -d "$TARGET_DIR/.claude/commands" ]]; then
    echo "  - .claude/commands/ уже папка, пропускаю"
else
    ln -s "../$CLAUDEV_DIR_NAME/core/commands" "$TARGET_DIR/.claude/commands"
    echo "  ✓ .claude/commands -> $CLAUDEV_DIR_NAME/core/commands"
fi

# Симлинк на scripts
if [[ -L "$TARGET_DIR/scripts" ]]; then
    rm "$TARGET_DIR/scripts"
fi
if [[ -d "$TARGET_DIR/scripts" ]]; then
    echo "  - scripts/ уже папка, пропускаю"
else
    ln -s "$CLAUDEV_DIR_NAME/core/scripts" "$TARGET_DIR/scripts"
    echo "  ✓ scripts -> $CLAUDEV_DIR_NAME/core/scripts"
fi

# === Claude Code permissions ===

echo ""
echo "Настраиваю разрешения Claude Code..."

SETTINGS_FILE="$TARGET_DIR/.claude/settings.json"

if [[ -f "$SETTINGS_FILE" ]]; then
    echo "  - settings.json уже существует"
else
    cat > "$SETTINGS_FILE" << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(gh *)",
      "Bash(bd *)",
      "Bash(ls *)",
      "Bash(tree *)",
      "Bash(find *)",
      "Bash(grep *)",
      "Bash(cat *)",
      "Bash(head *)",
      "Bash(tail *)",
      "Bash(wc *)",
      "Bash(sort *)",
      "Bash(echo *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(mv *)",
      "Bash(touch *)",
      "Bash(chmod *)",
      "Bash(timeout *)",
      "Bash(./scripts/*)",
      "Bash(bash *)",
      "Bash(source *)",
      "Bash(jq *)",
      "Bash(date *)",
      "Bash(stat *)",
      "Bash(pkill *)",
      "Bash(kill *)",
      "Bash(sleep *)",
      "Read",
      "Edit",
      "Write",
      "Glob",
      "Grep"
    ],
    "deny": [
      "Bash(rm -rf /)",
      "Bash(sudo rm -rf *)"
    ]
  }
}
EOF
    echo "  ✓ .claude/settings.json создан (auto-allow git, gh, bd, scripts)"
fi

# === Копируем config ===

echo ""
echo "Настраиваю конфиг..."

mkdir -p "$TARGET_DIR/.claudev"

if [[ -f "$TARGET_DIR/.claudev/config.sh" ]]; then
    echo "  - config.sh уже существует"
else
    cp "$SCRIPT_DIR/templates/config.template.sh" "$TARGET_DIR/.claudev/config.sh"
    echo "  ✓ .claudev/config.sh создан"
fi

# === Рабочие директории ===

echo ""
echo "Создаю рабочие директории..."
mkdir -p "$TARGET_DIR/logs/archive"
mkdir -p "$TARGET_DIR/stats"
echo "  ✓ logs/"
echo "  ✓ stats/"

# === Pre-commit hook (если gitleaks есть) ===

if [ "$GITLEAKS_AVAILABLE" = true ]; then
    echo ""
    echo "Настраиваю pre-commit hook..."

    HOOK_FILE="$TARGET_DIR/.git/hooks/pre-commit"

    if [[ -f "$HOOK_FILE" ]] && grep -q "gitleaks" "$HOOK_FILE"; then
        echo "  - gitleaks уже в pre-commit"
    else
        mkdir -p "$TARGET_DIR/.git/hooks"
        cat >> "$HOOK_FILE" << 'EOF'
#!/bin/bash
# Gitleaks secret detection (added by claudev)
gitleaks protect --staged --verbose
EOF
        chmod +x "$HOOK_FILE"
        echo "  ✓ pre-commit hook с gitleaks"
    fi
fi

# === .gitignore ===

echo ""
echo "Обновляю .gitignore..."

GITIGNORE="$TARGET_DIR/.gitignore"
touch "$GITIGNORE"

add_to_gitignore() {
    local pattern=$1
    if ! grep -q "^${pattern}$" "$GITIGNORE" 2>/dev/null; then
        echo "$pattern" >> "$GITIGNORE"
        echo "  + $pattern"
    fi
}

add_to_gitignore ".env"
add_to_gitignore ".env.*"
add_to_gitignore "*.pem"
add_to_gitignore "*.key"
add_to_gitignore "credentials.*"
add_to_gitignore "secrets/"
add_to_gitignore "logs/"
add_to_gitignore ".claudev/orchestrator.lock"

# === Финиш ===

echo ""
echo "=========================================="
echo "  Claudev установлен!"
echo "=========================================="
echo ""
echo "Запустите систему:"
echo "  ./scripts/orchestrator.sh"
echo ""
echo "Tech Writer спросит что вы хотите создать."
echo ""
