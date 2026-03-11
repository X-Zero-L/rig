#!/usr/bin/env bash
set -euo pipefail

# Source library functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/os-detect.sh
source "$SCRIPT_DIR/lib/os-detect.sh"
# shellcheck source=lib/pkg-maps.sh
source "$SCRIPT_DIR/lib/pkg-maps.sh"
# shellcheck source=lib/pkg-manager.sh
source "$SCRIPT_DIR/lib/pkg-manager.sh"

# Usage:
#   ./setup-node.sh          # install nvm + Node.js 24
#   ./setup-node.sh 22       # install nvm + Node.js 22
#   NODE_VERSION=20 ./setup-node.sh

# Empty means user didn't specify — will use default 24 only for fresh installs
_USER_NODE_VERSION="${NODE_VERSION:-${1:-}}"
NODE_VERSION="${_USER_NODE_VERSION:-24}"
NVM_NODEJS_ORG_MIRROR="${NVM_NODEJS_ORG_MIRROR:-}"
NPM_REGISTRY="${NPM_REGISTRY:-}"
GH_PROXY="${GH_PROXY:-}"

# Auto-set mirrors when behind GH_PROXY (likely in China)
if [[ -n "$GH_PROXY" ]]; then
    [[ -z "$NVM_NODEJS_ORG_MIRROR" ]] && NVM_NODEJS_ORG_MIRROR="https://npmmirror.com/mirrors/node"
    [[ -z "$NPM_REGISTRY" ]]          && NPM_REGISTRY="https://registry.npmmirror.com"
fi

# Ensure dependencies
if ! command -v curl &>/dev/null; then
    pkg_install curl
fi

echo "=== Node.js Environment Setup ==="

# Install nvm
echo "[1/3] Installing nvm..."
export NVM_DIR="$HOME/.nvm"
if [ -f "$NVM_DIR/nvm.sh" ]; then
    echo "  nvm already installed, skipping."
else
    # Clean up partial install
    [ -d "$NVM_DIR" ] && rm -rf "$NVM_DIR"
    _GH="github.com"
    curl -fsSL "https://${_GH}/nvm-sh/nvm/raw/HEAD/install.sh" | bash
fi

# Load nvm into current shell
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

# Install Node.js
echo "[2/3] Installing Node.js ${NODE_VERSION}..."
if [[ -n "$NVM_NODEJS_ORG_MIRROR" ]]; then
    export NVM_NODEJS_ORG_MIRROR
    echo "  Node mirror: $NVM_NODEJS_ORG_MIRROR"
fi

# Check if Node.js is already available
_current=$(nvm current 2>/dev/null || echo "none")

if [[ "$_current" != "none" && "$_current" != "system" && -z "$_USER_NODE_VERSION" ]]; then
    # User already has Node.js and didn't specify a version, skip entirely
    echo "  Node.js $_current already installed, skipping."
else
    # User specified a version, or no Node.js at all — install target
    # Use `nvm ls` to check only nvm-managed versions, not system node
    _target_version=$(nvm ls --no-colors "$NODE_VERSION" 2>/dev/null | grep -E 'v[0-9]' | head -1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "N/A")
    if [[ "$_target_version" != "N/A" && -n "$_target_version" ]]; then
        echo "  Node.js $NODE_VERSION already installed ($_target_version) via nvm, skipping."
    else
        echo "  Installing Node.js $NODE_VERSION..."
        nvm install "$NODE_VERSION"
    fi
    nvm use "$NODE_VERSION"
    nvm alias default "$NODE_VERSION"
fi

# Configure npm registry
echo "[3/3] Configuring npm..."
if [[ -n "$NPM_REGISTRY" ]]; then
    npm config set registry "$NPM_REGISTRY"
    echo "  npm registry: $NPM_REGISTRY"
else
    echo "  npm registry: (default)"
fi

echo ""
echo "=== Done! ==="
echo "Node.js: $(node -v)"
echo "npm:     $(npm -v)"
echo "Run 'source ~/.zshrc' or open a new terminal to use nvm."
