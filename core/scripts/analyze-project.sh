#!/bin/bash
# analyze-project.sh — анализ существующего проекта для создания контекста
#
# Выход: PROJECT_CONTEXT.md с информацией о стеке и структуре проекта
# Вызывается из cmd_init когда проект не пустой

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
OUTPUT_FILE="$PROJECT_ROOT/PROJECT_CONTEXT.md"

# === Stack Detection ===

detect_stack() {
    local stack=""
    local language=""
    local framework=""
    local deps=""

    # Node.js / TypeScript
    if [[ -f "package.json" ]]; then
        language="JavaScript/TypeScript"
        deps=$(jq -r '.dependencies // {} | keys | join(", ")' package.json 2>/dev/null || echo "")

        if [[ -f "tsconfig.json" ]]; then
            language="TypeScript"
        fi

        # Detect framework
        if echo "$deps" | grep -q "next"; then
            framework="Next.js"
        elif echo "$deps" | grep -q "react"; then
            framework="React"
        elif echo "$deps" | grep -q "vue"; then
            framework="Vue.js"
        elif echo "$deps" | grep -q "express"; then
            framework="Express"
        elif echo "$deps" | grep -q "fastify"; then
            framework="Fastify"
        fi

        stack="Node.js"
    fi

    # Elixir / Phoenix
    if [[ -f "mix.exs" ]]; then
        language="Elixir"
        stack="Elixir"

        if grep -q "phoenix" mix.exs 2>/dev/null; then
            framework="Phoenix"
        fi

        deps=$(grep -E '^\s*{:' mix.exs 2>/dev/null | sed 's/.*{:\([^,]*\).*/\1/' | tr '\n' ', ' | sed 's/, $//' || echo "")
    fi

    # Go
    if [[ -f "go.mod" ]]; then
        language="Go"
        stack="Go"

        if grep -q "gin-gonic" go.mod 2>/dev/null; then
            framework="Gin"
        elif grep -q "echo" go.mod 2>/dev/null; then
            framework="Echo"
        elif grep -q "fiber" go.mod 2>/dev/null; then
            framework="Fiber"
        fi

        deps=$(grep -E '^\s+' go.mod 2>/dev/null | awk '{print $1}' | head -10 | tr '\n' ', ' | sed 's/, $//' || echo "")
    fi

    # Rust
    if [[ -f "Cargo.toml" ]]; then
        language="Rust"
        stack="Rust"

        if grep -q "actix" Cargo.toml 2>/dev/null; then
            framework="Actix"
        elif grep -q "axum" Cargo.toml 2>/dev/null; then
            framework="Axum"
        elif grep -q "rocket" Cargo.toml 2>/dev/null; then
            framework="Rocket"
        fi

        deps=$(grep -E '^\w+\s*=' Cargo.toml 2>/dev/null | grep -A100 '\[dependencies\]' | grep -v '\[' | awk -F'=' '{print $1}' | tr -d ' ' | head -10 | tr '\n' ', ' | sed 's/, $//' || echo "")
    fi

    # Python
    if [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]]; then
        language="Python"
        stack="Python"

        if [[ -f "pyproject.toml" ]]; then
            if grep -q "django" pyproject.toml 2>/dev/null; then
                framework="Django"
            elif grep -q "fastapi" pyproject.toml 2>/dev/null; then
                framework="FastAPI"
            elif grep -q "flask" pyproject.toml 2>/dev/null; then
                framework="Flask"
            fi
            deps=$(grep -E '^\s*"[^"]+' pyproject.toml 2>/dev/null | grep -A50 'dependencies' | grep -E '^\s*"' | sed 's/.*"\([^"]*\)".*/\1/' | head -10 | tr '\n' ', ' | sed 's/, $//' || echo "")
        elif [[ -f "requirements.txt" ]]; then
            if grep -qi "django" requirements.txt 2>/dev/null; then
                framework="Django"
            elif grep -qi "fastapi" requirements.txt 2>/dev/null; then
                framework="FastAPI"
            elif grep -qi "flask" requirements.txt 2>/dev/null; then
                framework="Flask"
            fi
            deps=$(head -10 requirements.txt 2>/dev/null | sed 's/[<>=].*//' | tr '\n' ', ' | sed 's/, $//' || echo "")
        fi
    fi

    # Output
    echo "LANGUAGE=$language"
    echo "STACK=$stack"
    echo "FRAMEWORK=$framework"
    echo "DEPENDENCIES=$deps"
}

# === Structure Analysis ===

analyze_structure() {
    echo "## Project Structure"
    echo ""

    # Basic structure (top level)
    echo '```'
    ls -la "$PROJECT_ROOT" | grep -v '^total' | head -20
    echo '```'
    echo ""

    # Count files by type
    local code_files=0
    local test_files=0

    # Count source files
    code_files=$(find "$PROJECT_ROOT" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.ex" -o -name "*.exs" -o -name "*.go" -o -name "*.rs" \) 2>/dev/null | wc -l | tr -d ' ')

    # Count test files
    test_files=$(find "$PROJECT_ROOT" -type f \( -name "*_test.*" -o -name "*.test.*" -o -name "*_spec.*" -o -name "*.spec.*" -o -name "test_*" \) 2>/dev/null | wc -l | tr -d ' ')

    echo "**Files:** ~$code_files source files, ~$test_files test files"
    echo ""

    # Entry points
    echo "### Entry Points"
    echo ""

    local found_entry=false

    for entry in "main.ts" "main.tsx" "main.js" "index.ts" "index.tsx" "index.js" "app.ts" "app.js" "main.go" "main.py" "app.py" "lib/application.ex" "main.rs"; do
        if [[ -f "$PROJECT_ROOT/$entry" ]] || [[ -f "$PROJECT_ROOT/src/$entry" ]]; then
            echo "- \`$entry\`"
            found_entry=true
        fi
    done

    if [[ "$found_entry" = false ]]; then
        echo "- _(entry points not detected)_"
    fi
    echo ""
}

# === README extraction ===

extract_readme() {
    local readme=""

    for f in "README.md" "README" "readme.md" "Readme.md"; do
        if [[ -f "$PROJECT_ROOT/$f" ]]; then
            readme="$PROJECT_ROOT/$f"
            break
        fi
    done

    if [[ -n "$readme" ]]; then
        echo "## From README"
        echo ""
        head -50 "$readme" | sed 's/^/> /'
        echo ""
    fi
}

# === Main ===

main() {
    # Detect stack
    cd "$PROJECT_ROOT"
    eval "$(detect_stack)"

    # Generate output
    cat > "$OUTPUT_FILE" << EOF
# Project Context

> Auto-generated by hype analyze-project.sh
> Delete this file after Tech Writer processes it

## Tech Stack

| Attribute | Value |
|-----------|-------|
| Language | ${LANGUAGE:-_unknown_} |
| Stack | ${STACK:-_unknown_} |
| Framework | ${FRAMEWORK:-_none detected_} |
| Dependencies | ${DEPENDENCIES:-_none detected_} |

EOF

    analyze_structure >> "$OUTPUT_FILE"
    extract_readme >> "$OUTPUT_FILE"

    echo "PROJECT_CONTEXT.md created"
}

main "$@"
