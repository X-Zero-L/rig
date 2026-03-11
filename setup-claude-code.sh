#!/usr/bin/env bash
set -euo pipefail

# Source OS detection and package manager libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/os-detect.sh
source "$SCRIPT_DIR/lib/os-detect.sh"
# shellcheck source=lib/pkg-maps.sh
source "$SCRIPT_DIR/lib/pkg-maps.sh"
# shellcheck source=lib/pkg-manager.sh
source "$SCRIPT_DIR/lib/pkg-manager.sh"

# Usage:
#   CLAUDE_API_URL=https://... CLAUDE_API_KEY=cr_... ./setup-claude-code.sh
#   ./setup-claude-code.sh --api-url https://... --api-key cr_...
#   ./setup-claude-code.sh                # install only, configure later
#
# Environment variables:
#   CLAUDE_API_URL    - API base URL (optional, skip config if empty)
#   CLAUDE_API_KEY    - Auth token (optional, skip config if empty)
#   CLAUDE_MODEL      - Model name (default: opus)
#   CLAUDE_NPM_MIRROR - npm registry mirror (auto-set when GH_PROXY is set)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --api-url)  CLAUDE_API_URL="$2"; shift 2 ;;
        --api-key)  CLAUDE_API_KEY="$2"; shift 2 ;;
        --model)    CLAUDE_MODEL="$2"; shift 2 ;;
        *) shift ;;
    esac
done

CLAUDE_API_URL="${CLAUDE_API_URL:-}"
CLAUDE_API_KEY="${CLAUDE_API_KEY:-}"
CLAUDE_MODEL="${CLAUDE_MODEL:-opus}"
GH_PROXY="${GH_PROXY:-}"
CLAUDE_NPM_MIRROR="${CLAUDE_NPM_MIRROR:-}"
[[ -n "$GH_PROXY" && -z "$CLAUDE_NPM_MIRROR" ]] && CLAUDE_NPM_MIRROR="https://registry.npmmirror.com"

HAS_KEYS=0
if [ -n "$CLAUDE_API_URL" ] && [ -n "$CLAUDE_API_KEY" ]; then
    HAS_KEYS=1
fi

echo "=== Claude Code Setup ==="

# Ensure node is available (load nvm if present)
if ! command -v node &>/dev/null; then
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    [ -f "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
fi

if ! command -v node &>/dev/null; then
    echo "Error: Node.js not found. Run setup-node.sh first."
    exit 1
fi

# [1] Install Claude Code
echo "[1/4] Installing Claude Code..."
if command -v claude &>/dev/null; then
    echo "  Already installed, skipping."
else
    npm install -g @anthropic-ai/claude-code ${CLAUDE_NPM_MIRROR:+--registry="$CLAUDE_NPM_MIRROR"}
fi

# [2] Skip onboarding
echo "[2/4] Configuring onboarding..."
CLAUDE_JSON="$HOME/.claude.json"
node -e "
const fs = require('fs');
const p = process.argv[1];
const data = fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, 'utf-8')) : {};
if (data.hasCompletedOnboarding === true) {
    console.log('  Already configured, skipping.');
} else {
    data.hasCompletedOnboarding = true;
    fs.writeFileSync(p, JSON.stringify(data, null, 2));
}
" "$CLAUDE_JSON"

# [3] Write settings (only if API keys provided)
echo "[3/4] Writing settings..."
if [ "$HAS_KEYS" -eq 1 ]; then
    CLAUDE_SETTINGS_DIR="$HOME/.claude"
    mkdir -p "$CLAUDE_SETTINGS_DIR"
    CLAUDE_SETTINGS="$CLAUDE_SETTINGS_DIR/settings.json"

    _CLAUDE_URL="$CLAUDE_API_URL" _CLAUDE_KEY="$CLAUDE_API_KEY" \
    _CLAUDE_MODEL="$CLAUDE_MODEL" node -e "
const fs = require('fs');
const p = process.argv[1];
const url = process.env._CLAUDE_URL;
const key = process.env._CLAUDE_KEY;
const model = process.env._CLAUDE_MODEL;
const settings = fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, 'utf-8')) : {};
const env = settings.env || {};
if (env.ANTHROPIC_BASE_URL === url && env.ANTHROPIC_AUTH_TOKEN === key && settings.model === model) {
    console.log('  Already configured, skipping.');
} else {
    settings.env = {
        ...env,
        ANTHROPIC_BASE_URL: url,
        ANTHROPIC_AUTH_TOKEN: key,
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: '1'
    };
    settings.permissions = settings.permissions || { allow: [], deny: [] };
    settings.alwaysThinkingEnabled = true;
    settings.model = model;
    fs.writeFileSync(p, JSON.stringify(settings, null, 2));
}
" "$CLAUDE_SETTINGS"
else
    echo "  Skipped (no API keys provided). Configure later with:"
    echo "    claude config set env.ANTHROPIC_BASE_URL <url>"
    echo "    claude config set env.ANTHROPIC_AUTH_TOKEN <key>"
fi

# [4] Add alias and root env vars
echo "[4/4] Adding alias..."
ALIAS_LINE="alias cc='claude --dangerously-skip-permissions'"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc" ] && ! grep -qF "$ALIAS_LINE" "$rc"; then
        echo "" >> "$rc"
        echo "$ALIAS_LINE" >> "$rc"
    fi
done

# When running as root, Claude Code requires IS_SANDBOX=1 to bypass permission checks
if [ "$(id -u)" -eq 0 ]; then
    SANDBOX_LINE="export IS_SANDBOX=1"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ] && ! grep -qF "$SANDBOX_LINE" "$rc"; then
            echo "$SANDBOX_LINE" >> "$rc"
            echo "  Added IS_SANDBOX=1 to $rc (required for root)"
        fi
    done
fi

echo ""
echo "=== Done! ==="
echo "Claude Code: $(claude --version 2>/dev/null || echo 'installed')"
if [ "$HAS_KEYS" -eq 1 ]; then
    echo "Model:       $CLAUDE_MODEL"
    echo "API URL:     $CLAUDE_API_URL"
fi
echo "Run 'source ~/.zshrc' or open a new terminal to use the 'cc' alias."
