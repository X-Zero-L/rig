#!/usr/bin/env bash
set -euo pipefail

# Source library dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/os-detect.sh
source "$SCRIPT_DIR/lib/os-detect.sh"
# shellcheck source=lib/pkg-maps.sh
source "$SCRIPT_DIR/lib/pkg-maps.sh"
# shellcheck source=lib/pkg-manager.sh
source "$SCRIPT_DIR/lib/pkg-manager.sh"

# Usage:
#   ./setup-tmux.sh                    # default (no custom keybindings)
#   TMUX_KEYBINDS=1 ./setup-tmux.sh    # enable custom keybindings
#   ./setup-tmux.sh --keybinds         # same as above
#
# Environment variables:
#   TMUX_KEYBINDS    - Enable custom keybindings (default: 0)
#                      Adds: Ctrl+a prefix, | and - splits, vim-style resize
#   TMUX_MOUSE       - Enable mouse support (default: 1)
#   TMUX_STATUS_POS  - Status bar position: top/bottom (default: top)
#   GH_PROXY         - GitHub proxy URL for git clone

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --keybinds)    TMUX_KEYBINDS=1; shift ;;
        --no-mouse)    TMUX_MOUSE=0; shift ;;
        --status-pos)  TMUX_STATUS_POS="$2"; shift 2 ;;
        *) shift ;;
    esac
done

TMUX_KEYBINDS="${TMUX_KEYBINDS:-0}"
TMUX_MOUSE="${TMUX_MOUSE:-1}"
TMUX_STATUS_POS="${TMUX_STATUS_POS:-top}"
GH_PROXY="${GH_PROXY:-}"
_GH="github.com"

# Ensure dependencies
if ! command -v git &>/dev/null; then
    pkg_install git
fi

echo "=== Tmux Setup ==="

# [1/4] Install tmux
echo "[1/4] Installing tmux..."
if command -v tmux &>/dev/null; then
    echo "  Already installed, skipping."
else
    pkg_install tmux
fi

# [2/4] Install TPM
echo "[2/4] Installing TPM..."
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ -d "$TPM_DIR" ]; then
    echo "  Already installed, skipping."
else
    CLONE_URL="https://${_GH}/tmux-plugins/tpm"
    [ -n "$GH_PROXY" ] && CLONE_URL="${GH_PROXY%/}/https://${_GH}/tmux-plugins/tpm"
    git clone --depth 1 "$CLONE_URL" "$TPM_DIR"
fi

# [3/4] Write config
echo "[3/4] Writing config..."
TMUX_CONF="$HOME/.tmux.conf"

generate_config() {
    echo '# ─── General ───'
    echo 'set -g default-terminal "tmux-256color"'
    echo 'set -ag terminal-overrides ",xterm-256color:RGB"'
    echo 'set -g base-index 1'
    echo 'setw -g pane-base-index 1'
    echo 'set -g renumber-windows on'
    echo 'set -g set-clipboard on'
    echo 'set -g detach-on-destroy off'

    if [ "$TMUX_MOUSE" -eq 1 ]; then
        echo ''
        echo '# ─── Mouse ───'
        echo 'set -g mouse on'
    fi

    echo ''
    echo '# ─── Status bar ───'
    echo "set -g status-position ${TMUX_STATUS_POS}"

    echo ''
    echo '# ─── Mouse enhancements ───'
    echo '# Click session name → session/window tree picker'
    echo 'bind -n MouseDown1StatusLeft choose-tree -Zs'
    echo '# Scroll wheel on status bar → cycle windows'
    echo 'bind -n WheelUpStatus previous-window'
    echo 'bind -n WheelDownStatus next-window'
    echo '# Double-click on pane → toggle zoom'
    echo 'bind -n DoubleClick1Pane resize-pane -Z'
    echo '# Middle-click on pane → paste buffer'
    echo 'bind -n MouseDown2Pane select-pane -t= \; paste-buffer'

    # Right-click context menus (heredoc for complex quoting)
cat << 'MOUSECONF'

# ─── Right-click context menus ───
# Right-click on pane
bind -n MouseDown3Pane display-menu -T "#[align=centre]Pane" -t = -x M -y M \
  "Horizontal Split" h "split-window -h -c '#{pane_current_path}'" \
  "Vertical Split" v "split-window -v -c '#{pane_current_path}'" \
  "" \
  "#{?window_zoomed_flag,Unzoom,Zoom}" z "resize-pane -Z" \
  "" \
  "Swap Up" u "swap-pane -U" \
  "Swap Down" d "swap-pane -D" \
  "" \
  "Kill" x "confirm-before -p 'kill pane? (y/n)' kill-pane"

# Right-click on window in status bar
bind -n MouseDown3Status display-menu -T "#[align=centre]#W" -t = -x W -y S \
  "Rename" r "command-prompt -I '#W' 'rename-window -- \"%%\"'" \
  "New Window" n "new-window -a -c '#{pane_current_path}'" \
  "" \
  "Kill" x "confirm-before -p 'kill #W? (y/n)' kill-window"

# Right-click on session name
bind -n MouseDown3StatusLeft display-menu -T "#[align=centre]#S" -t = -x M -y S \
  "New Session" n "command-prompt -p 'session name:' 'new-session -s \"%%\"'" \
  "Rename" r "command-prompt -I '#S' 'rename-session -- \"%%\"'" \
  "" \
  "Kill" x "confirm-before -p 'kill session #S? (y/n)' kill-session"
MOUSECONF

    echo ''
    echo '# ─── Quick navigation (no prefix needed) ───'
    echo '# Alt+1..9 → switch to window by number'
    echo 'bind -n M-1 select-window -t 1'
    echo 'bind -n M-2 select-window -t 2'
    echo 'bind -n M-3 select-window -t 3'
    echo 'bind -n M-4 select-window -t 4'
    echo 'bind -n M-5 select-window -t 5'
    echo 'bind -n M-6 select-window -t 6'
    echo 'bind -n M-7 select-window -t 7'
    echo 'bind -n M-8 select-window -t 8'
    echo 'bind -n M-9 select-window -t 9'
    echo '# Alt+n → new window'
    echo 'bind -n M-n new-window -c "#{pane_current_path}"'

    if [ "$TMUX_KEYBINDS" -eq 1 ]; then
        echo ''
        echo '# ─── Custom keybindings ───'
        echo '# Prefix: Ctrl+a'
        echo 'unbind C-b'
        echo 'set -g prefix C-a'
        echo 'bind C-a send-prefix'
        echo ''
        echo '# Intuitive splits'
        echo 'bind | split-window -h -c "#{pane_current_path}"'
        echo 'bind - split-window -v -c "#{pane_current_path}"'
        echo ''
        echo '# Vim-style pane resize'
        echo 'bind -r H resize-pane -L 5'
        echo 'bind -r J resize-pane -D 5'
        echo 'bind -r K resize-pane -U 5'
        echo 'bind -r L resize-pane -R 5'
    fi

    echo ''
    echo '# ─── Catppuccin theme ───'
    echo 'set -g @catppuccin_flavor "mocha"'
    echo 'set -g @catppuccin_window_status_style "rounded"'

    echo ''
    echo '# ─── Plugins ───'
    echo "set -g @plugin 'tmux-plugins/tpm'"
    echo "set -g @plugin 'tmux-plugins/tmux-sensible'"
    echo "set -g @plugin 'catppuccin/tmux'"
    echo "set -g @plugin 'christoomey/vim-tmux-navigator'"
    echo "set -g @plugin 'tmux-plugins/tmux-yank'"
    echo "set -g @plugin 'tmux-plugins/tmux-resurrect'"
    echo "set -g @plugin 'tmux-plugins/tmux-continuum'"

    echo ''
    echo '# ─── Plugin settings ───'
    echo "set -g @continuum-restore 'on'"

    echo ''
    echo '# ─── Initialize TPM (keep at bottom) ───'
    echo "run '~/.tmux/plugins/tpm/tpm'"
}

WANT_CONF=$(generate_config)
if [ -f "$TMUX_CONF" ] && [ "$(cat "$TMUX_CONF")" = "$WANT_CONF" ]; then
    echo "  Already configured, skipping."
else
    printf '%s\n' "$WANT_CONF" > "$TMUX_CONF"
    echo "  Config written."
fi

# [4/4] Install plugins
echo "[4/4] Installing plugins..."
PLUGIN_DIR="$HOME/.tmux/plugins"
PLUGINS=(
    "tmux-plugins/tmux-sensible"
    "catppuccin/tmux"
    "christoomey/vim-tmux-navigator"
    "tmux-plugins/tmux-yank"
    "tmux-plugins/tmux-resurrect"
    "tmux-plugins/tmux-continuum"
)

ALL_PRESENT=1
for plugin in "${PLUGINS[@]}"; do
    plugin_name=$(basename "$plugin")
    if [ ! -d "$PLUGIN_DIR/$plugin_name" ]; then
        ALL_PRESENT=0
        break
    fi
done

if [ "$ALL_PRESENT" -eq 1 ]; then
    echo "  All plugins already installed, skipping."
else
    for plugin in "${PLUGINS[@]}"; do
        plugin_name=$(basename "$plugin")
        if [ -d "$PLUGIN_DIR/$plugin_name" ]; then
            echo "  $plugin_name: already installed"
            continue
        fi
        CLONE_URL="https://${_GH}/$plugin"
        [ -n "$GH_PROXY" ] && CLONE_URL="${GH_PROXY%/}/https://${_GH}/$plugin"
        echo "  $plugin_name: installing..."
        git clone --depth 1 "$CLONE_URL" "$PLUGIN_DIR/$plugin_name" 2>/dev/null
    done
fi

echo ""
echo "=== Done! ==="
echo "Tmux: $(tmux -V 2>/dev/null || echo 'installed')"
echo "Theme: Catppuccin Mocha"
echo "Plugins: sensible, catppuccin, vim-tmux-navigator, yank, resurrect, continuum"
if [ "$TMUX_KEYBINDS" -eq 1 ]; then
    echo "Keybinds: custom (Ctrl+a prefix, | and - splits)"
else
    echo "Keybinds: default (set TMUX_KEYBINDS=1 to customize)"
fi
