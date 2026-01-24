#!/usr/bin/env bash
#
# Claudev Installer
# Устанавливает систему в целевой проект
#
# Использование:
#   git clone git@github.com:user/claudev.git .claudev
#   .claudev/install.sh
#
# Опции:
#   --auto-install   Автоматически установить npm зависимости

set -euo pipefail

# Определяем директории
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
    echo "Error: claudev должен быть клонирован в подпапку проекта"
    echo ""
    echo "Правильно:"
    echo "  cd your-project"
    echo "  git clone <repo> .claudev"
    echo "  .claudev/install.sh"
    exit 1
fi

if [[ ! -d "$SCRIPT_DIR/core" ]]; then
    echo "Error: не найдена папка core/ в $SCRIPT_DIR"
    exit 1
fi

# === Проверка зависимостей ===

echo "Checking dependencies..."
missing=()

command -v bd &>/dev/null || missing+=("beads")
command -v claude &>/dev/null || missing+=("claude-code")
command -v gh &>/dev/null || missing+=("gh")
command -v jq &>/dev/null || missing+=("jq")

# gitleaks опционален
GITLEAKS_AVAILABLE=false
command -v gitleaks &>/dev/null && GITLEAKS_AVAILABLE=true

if [ ${#missing[@]} -gt 0 ]; then
    echo ""
    echo "Missing dependencies: ${missing[*]}"
    echo ""
    echo "Install commands:"
    [[ " ${missing[*]} " =~ " beads " ]] && echo "  npm install -g @anthropic/beads"
    [[ " ${missing[*]} " =~ " claude-code " ]] && echo "  npm install -g @anthropic/claude-code"
    [[ " ${missing[*]} " =~ " gh " ]] && echo "  brew install gh  # or: apt install gh"
    [[ " ${missing[*]} " =~ " jq " ]] && echo "  brew install jq  # or: apt install jq"
    echo ""

    if [[ "$AUTO_INSTALL" == "--auto-install" ]]; then
        echo "Auto-installing npm packages..."
        [[ " ${missing[*]} " =~ " beads " ]] && npm install -g @anthropic/beads
        [[ " ${missing[*]} " =~ " claude-code " ]] && npm install -g @anthropic/claude-code
        echo "Note: gh and jq require manual install (brew/apt)"
    else
        echo "Run with --auto-install to install npm packages automatically"
        exit 1
    fi
fi

echo "  ✓ All critical dependencies found"
if [ "$GITLEAKS_AVAILABLE" = true ]; then
    echo "  ✓ gitleaks available (will add pre-commit hook)"
else
    echo "  - gitleaks not found (optional, for secret detection)"
fi

# === Git ===

echo ""
echo "Checking git..."

cd "$TARGET_DIR"

if [[ ! -d ".git" ]]; then
    echo "  Initializing git repository..."
    git init
    echo "  ✓ git init"
fi

# Проверяем remote
if ! git remote -v | grep -q origin; then
    echo "  Warning: No git remote configured"
    echo "  Add one later with: git remote add origin <url>"
fi

# === Beads ===

echo ""
echo "Checking beads..."

if [[ ! -d ".beads" ]]; then
    echo "  Initializing beads..."
    bd init
    echo "  ✓ bd init"
else
    echo "  ✓ .beads/ exists"
fi

# === Создаём .claude/ с симлинками ===

echo ""
echo "Creating .claude/ directory..."
mkdir -p "$TARGET_DIR/.claude"

# Симлинк на agents
if [[ -L "$TARGET_DIR/.claude/agents" ]]; then
    rm "$TARGET_DIR/.claude/agents"
fi
if [[ -d "$TARGET_DIR/.claude/agents" ]]; then
    echo "  Warning: .claude/agents/ уже существует как папка, пропускаю"
else
    ln -s "../$CLAUDEV_DIR_NAME/core/agents" "$TARGET_DIR/.claude/agents"
    echo "  ✓ .claude/agents -> $CLAUDEV_DIR_NAME/core/agents"
fi

# Симлинк на commands
if [[ -L "$TARGET_DIR/.claude/commands" ]]; then
    rm "$TARGET_DIR/.claude/commands"
fi
if [[ -d "$TARGET_DIR/.claude/commands" ]]; then
    echo "  Warning: .claude/commands/ уже существует как папка, пропускаю"
else
    ln -s "../$CLAUDEV_DIR_NAME/core/commands" "$TARGET_DIR/.claude/commands"
    echo "  ✓ .claude/commands -> $CLAUDEV_DIR_NAME/core/commands"
fi

# Симлинк на scripts
if [[ -L "$TARGET_DIR/scripts" ]]; then
    rm "$TARGET_DIR/scripts"
fi
if [[ -d "$TARGET_DIR/scripts" ]]; then
    echo "  Warning: scripts/ уже существует как папка, пропускаю"
else
    ln -s "$CLAUDEV_DIR_NAME/core/scripts" "$TARGET_DIR/scripts"
    echo "  ✓ scripts -> $CLAUDEV_DIR_NAME/core/scripts"
fi

# === Копируем config ===

echo ""
echo "Setting up config..."

mkdir -p "$TARGET_DIR/.claudev"

if [[ -f "$TARGET_DIR/.claudev/config.sh" ]]; then
    echo "  - config.sh already exists, keeping"
else
    cp "$SCRIPT_DIR/templates/config.template.sh" "$TARGET_DIR/.claudev/config.sh"
    echo "  ✓ .claudev/config.sh created"
fi

# === Рабочие директории ===

echo ""
echo "Creating work directories..."
mkdir -p "$TARGET_DIR/logs/archive"
mkdir -p "$TARGET_DIR/stats"
echo "  ✓ logs/"
echo "  ✓ logs/archive/"
echo "  ✓ stats/"

# === Pre-commit hook (если gitleaks есть) ===

if [ "$GITLEAKS_AVAILABLE" = true ]; then
    echo ""
    echo "Setting up pre-commit hook..."

    HOOK_FILE="$TARGET_DIR/.git/hooks/pre-commit"

    if [[ -f "$HOOK_FILE" ]]; then
        if grep -q "gitleaks" "$HOOK_FILE"; then
            echo "  - pre-commit hook already has gitleaks"
        else
            echo "  Adding gitleaks to existing pre-commit hook..."
            cat >> "$HOOK_FILE" << 'EOF'

# Gitleaks secret detection (added by claudev)
gitleaks protect --staged --verbose
EOF
            echo "  ✓ gitleaks added to pre-commit"
        fi
    else
        cat > "$HOOK_FILE" << 'EOF'
#!/bin/bash
# Pre-commit hook (added by claudev)

# Gitleaks secret detection
gitleaks protect --staged --verbose
EOF
        chmod +x "$HOOK_FILE"
        echo "  ✓ pre-commit hook created with gitleaks"
    fi
fi

# === .gitignore ===

echo ""
echo "Updating .gitignore..."

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
echo "=== Installation complete ==="
echo ""
echo "Следующие шаги:"
echo "  1. Запустите систему: ./scripts/orchestrator.sh"
echo "  2. Tech Writer спросит что вы хотите создать"
echo "  3. Или заполните SPEC.md вручную и перезапустите"
echo ""
echo "Полезные команды:"
echo "  bd ready                    # Посмотреть готовые задачи"
echo "  bd list                     # Все задачи"
echo "  ./scripts/orchestrator.sh   # Запустить систему"
echo ""
