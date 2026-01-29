#!/usr/bin/env bash
#
# Claudev Global Installer
# Устанавливает claudev в ~/.claudev/ для использования в любых проектах
#
# Использование:
#   curl -fsSL https://raw.githubusercontent.com/Puremag1c/claudev/main/install.sh | bash
#

set -euo pipefail

CLAUDEV_HOME="${CLAUDEV_HOME:-$HOME/.claudev}"
REPO_URL="https://github.com/Puremag1c/claudev.git"

# === Colors ===

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}▸${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}!${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1" >&2; }

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       Claudev Global Installer       ║"
echo "╚══════════════════════════════════════╝"
echo ""

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
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Добавляем brew в PATH для текущей сессии
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f "/usr/local/bin/brew" ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        success "Homebrew installed"
    fi
}

install_with_brew() {
    local pkg=$1
    local cmd=${2:-$1}

    if ! command -v "$cmd" &>/dev/null; then
        info "Installing $pkg..."
        brew install "$pkg"
        success "$pkg installed"
    else
        success "$pkg already installed"
    fi
}

install_with_apt() {
    local pkg=$1
    local cmd=${2:-$1}

    if ! command -v "$cmd" &>/dev/null; then
        info "Installing $pkg..."
        sudo apt install -y "$pkg"
        success "$pkg installed"
    else
        success "$pkg already installed"
    fi
}

install_beads_macos() {
    if ! command -v bd &>/dev/null; then
        info "Installing beads..."
        brew tap steveyegge/beads
        brew install bd
        success "beads installed"
    else
        success "beads already installed"
    fi
}

install_beads_linux() {
    if ! command -v bd &>/dev/null; then
        if command -v brew &>/dev/null; then
            info "Installing beads via brew..."
            brew tap steveyegge/beads
            brew install bd
            success "beads installed"
        elif command -v go &>/dev/null; then
            info "Installing beads via go..."
            go install github.com/steveyegge/beads/cmd/bd@latest
            success "beads installed"
        else
            warn "Cannot install beads: need brew or go"
            echo "  See: https://github.com/steveyegge/beads"
        fi
    else
        success "beads already installed"
    fi
}

install_claude_code() {
    if ! command -v claude &>/dev/null; then
        info "Installing Claude Code..."
        curl -fsSL https://claude.ai/install.sh | bash
        success "Claude Code installed"
    else
        success "Claude Code already installed"
    fi
}

# === Step 1: Install/Update claudev ===

echo "Step 1: Installing claudev to $CLAUDEV_HOME"
echo ""

if [[ -d "$CLAUDEV_HOME" ]]; then
    if [[ -d "$CLAUDEV_HOME/.git" ]]; then
        info "Updating existing installation..."
        cd "$CLAUDEV_HOME"
        git pull --ff-only
        success "Updated to $(cat VERSION)"
    else
        warn "$CLAUDEV_HOME exists but is not a git repo"
        info "Backing up and reinstalling..."
        mv "$CLAUDEV_HOME" "$CLAUDEV_HOME.backup.$(date +%s)"
        git clone --depth 1 "$REPO_URL" "$CLAUDEV_HOME"
        success "Installed $(cat "$CLAUDEV_HOME/VERSION")"
    fi
else
    info "Cloning claudev..."
    git clone --depth 1 "$REPO_URL" "$CLAUDEV_HOME"
    success "Installed $(cat "$CLAUDEV_HOME/VERSION")"
fi

# === Step 2: Install dependencies ===

echo ""
echo "Step 2: Installing dependencies"
echo ""

if [[ "$OS" == "macos" ]]; then
    install_homebrew
    install_beads_macos
    install_with_brew "gh"
    install_with_brew "jq"
    install_claude_code

    # gitleaks optional
    if ! command -v gitleaks &>/dev/null; then
        info "Installing gitleaks (optional)..."
        brew install gitleaks 2>/dev/null || warn "gitleaks skipped"
    fi

elif [[ "$OS" == "linux" ]]; then
    if command -v apt &>/dev/null; then
        sudo apt update -qq
        install_with_apt "gh"
        install_with_apt "jq"
        install_beads_linux
        install_claude_code

        # gitleaks (try multiple methods, skip silently if none work)
        if ! command -v gitleaks &>/dev/null; then
            # Try snap first (most reliable on Ubuntu)
            if command -v snap &>/dev/null; then
                info "Installing gitleaks via snap..."
                sudo snap install gitleaks 2>/dev/null && success "gitleaks installed" || true
            # Try go install if available
            elif command -v go &>/dev/null; then
                info "Installing gitleaks via go..."
                go install github.com/gitleaks/gitleaks/v8@latest 2>/dev/null && success "gitleaks installed" || true
            fi
        else
            success "gitleaks already installed"
        fi
    else
        warn "apt not found, install dependencies manually"
    fi
else
    error "Unknown OS: $OSTYPE"
    exit 1
fi

# === Step 3: Add to PATH ===

echo ""
echo "Step 3: Configuring PATH"
echo ""

add_to_path() {
    local shell_rc=$1

    if [[ -f "$shell_rc" ]]; then
        local changed=false

        # Add ~/.claudev/bin
        if ! grep -q '.claudev/bin' "$shell_rc"; then
            echo "" >> "$shell_rc"
            echo "# Claudev" >> "$shell_rc"
            echo 'export PATH="$HOME/.claudev/bin:$PATH"' >> "$shell_rc"
            changed=true
        fi

        # Add ~/.local/bin (for Claude Code)
        if ! grep -q '.local/bin' "$shell_rc"; then
            if [[ "$changed" == "false" ]]; then
                echo "" >> "$shell_rc"
                echo "# Claudev" >> "$shell_rc"
            fi
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
            changed=true
        fi

        if [[ "$changed" == "true" ]]; then
            success "Updated $shell_rc"
        else
            success "Already configured in $shell_rc"
        fi
    fi
}

# Detect shell and add to appropriate rc file
if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
    add_to_path "$HOME/.zshrc"
elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == *"bash"* ]]; then
    add_to_path "$HOME/.bashrc"
    [[ -f "$HOME/.bash_profile" ]] && add_to_path "$HOME/.bash_profile"
fi

# Add to current session
export PATH="$CLAUDEV_HOME/bin:$HOME/.local/bin:$PATH"

# === Step 4: Verify ===

echo ""
echo "Step 4: Verifying installation"
echo ""

check_cmd() {
    local cmd=$1
    local name=${2:-$1}
    if command -v "$cmd" &>/dev/null; then
        success "$name"
        return 0
    else
        error "$name NOT INSTALLED"
        return 1
    fi
}

check_cmd "claudev" "claudev CLI"
check_cmd "bd" "beads"
check_cmd "claude" "Claude Code"
check_cmd "gh" "GitHub CLI"
check_cmd "jq" "jq"

if command -v gitleaks &>/dev/null; then
    success "gitleaks (optional)"
else
    info "gitleaks (optional, not installed)"
fi

# === Done ===

echo ""
echo "╔══════════════════════════════════════╗"
echo "║         Installation complete!       ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "To initialize a project:"
echo ""
echo "  cd your-project"
echo "  claudev init"
echo ""
echo "Note: Restart your terminal or run:"
echo "  source ~/.zshrc  # or ~/.bashrc"
echo ""
