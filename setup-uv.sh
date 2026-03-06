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
#   ./setup-uv.sh
#   UV_PYTHON=3.12 ./setup-uv.sh

UV_PYTHON="${UV_PYTHON:-${1:-}}"

# Ensure dependencies
if ! command -v curl &>/dev/null; then
    pkg_install curl
fi

echo "=== uv Setup ==="

# Install uv
echo "[1/2] Installing uv..."
if command -v uv &>/dev/null; then
    echo "  uv already installed, upgrading..."
    uv self update || echo "  Warning: uv self update failed, continuing with existing version."
else
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Load uv into current shell
export PATH="$HOME/.local/bin:$PATH"

# Ensure ~/.local/bin is in shell PATH for both zsh and bash
_ensure_local_bin_path() {
    local rc="$1"
    local line='export PATH="$HOME/.local/bin:$PATH"'
    # Skip if the shell isn't installed
    [[ -f "$rc" ]] || return 0
    # Check for explicit PATH export (not just env sourcing)
    grep -qF "$line" "$rc" 2>/dev/null && return 0
    printf '\n# uv / rig: ensure ~/.local/bin in PATH\n%s\n' "$line" >> "$rc"
    echo "  Added ~/.local/bin to PATH in $(basename "$rc")"
}
_ensure_local_bin_path "$HOME/.zshrc"
_ensure_local_bin_path "$HOME/.bashrc"

# Install Python if requested
if [ -n "$UV_PYTHON" ]; then
    echo "[2/2] Installing Python ${UV_PYTHON}..."
    uv python install "$UV_PYTHON"
else
    echo "[2/2] Skipping Python install (set UV_PYTHON to install a version)."
fi

echo ""
echo "=== Done! ==="
echo "uv: $(uv --version)"
[ -n "$UV_PYTHON" ] && echo "Python: $(uv python find "$UV_PYTHON" 2>/dev/null || echo "$UV_PYTHON installed")"
echo "Run 'source ~/.zshrc' or open a new terminal to use uv."
