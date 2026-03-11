#!/usr/bin/env bash
set -uo pipefail

# =============================================================================
# Rig All-in-One Updater
# https://github.com/X-Zero-L/rig
#
# Usage:
#   bash update.sh                              # Interactive TUI
#   bash update.sh --all                        # Update all installed
#   bash update.sh --components codex,claude-code
#   curl -fsSL <url>/update.sh | bash           # Interactive via pipe
#   curl -fsSL <url>/update.sh | bash -s -- --all
#
# Environment variables:
#   GH_PROXY          - GitHub proxy URL (e.g. https://gh-proxy.org)
#   NODE_VERSION      - Pin Node.js version (e.g. 24); default: latest
# =============================================================================

# --- [A] Constants -----------------------------------------------------------

# Prevent gh-proxy.org from rewriting these URLs in proxied content
_GH="github.com"
_RAW="raw.githubusercontent.com"
REPO="X-Zero-L/rig"
BRANCH="master"
BASE_URL="https://${_RAW}/${REPO}/${BRANCH}"

export GH_PROXY="${GH_PROXY:-}"

# --- [A.1] OS / Package-Manager Libraries -----------------------------------

_load_lib() {
    local name="$1"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

    if [[ -f "${script_dir}/lib/${name}" ]]; then
        # Local clone: source directly
        # shellcheck disable=SC1090
        source "${script_dir}/lib/${name}"
    else
        # Remote (curl | bash): fetch from repo
        local url="${BASE_URL}/lib/${name}"
        [[ -n "${GH_PROXY:-}" ]] && url="${GH_PROXY}/${url}"
        local body
        body="$(curl -fsSL "$url")" || { echo "Failed to fetch lib/${name}" >&2; return 1; }
        eval "$body"
    fi
}

_load_lib "os-detect.sh"
_load_lib "pkg-maps.sh"
_load_lib "pkg-manager.sh"

# Restore shell options: lib files set -euo pipefail but update.sh must NOT use errexit
set +e
NON_INTERACTIVE=0
INTERACTIVE=0
VERBOSE=0
LOG_FILE=""
CURSOR_HIDDEN=0

# --- [B] ANSI Colors ---------------------------------------------------------

setup_colors() {
    if [[ -t 1 ]] || [[ "${FORCE_COLOR:-}" == "1" ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[0;33m'
        BLUE='\033[0;34m'
        MAGENTA='\033[0;35m'
        CYAN='\033[0;36m'
        WHITE='\033[1;37m'
        BOLD='\033[1m'
        DIM='\033[2m'
        ITALIC='\033[3m'
        NC='\033[0m'
        HIDE_CURSOR='\033[?25l'
        SHOW_CURSOR='\033[?25h'
        CLEAR_LINE='\033[2K'
        # Symbols
        SYM_CHECK="${GREEN}✔${NC}"
        SYM_CROSS="${RED}✘${NC}"
        SYM_ARROW="${CYAN}▸${NC}"
        SYM_DOT="${DIM}○${NC}"
        SYM_FILL="${GREEN}●${NC}"
        SYM_WARN="${YELLOW}▲${NC}"
        SYM_PLAY="${CYAN}▶${NC}"
    else
        RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' WHITE=''
        BOLD='' DIM='' ITALIC='' NC=''
        HIDE_CURSOR='' SHOW_CURSOR='' CLEAR_LINE=''
        SYM_CHECK='[ok]' SYM_CROSS='[fail]' SYM_ARROW='>' SYM_DOT='[ ]'
        SYM_FILL='[x]' SYM_WARN='[!]' SYM_PLAY='[>]'
    fi
}

# --- [C] Component Registry --------------------------------------------------

COMP_IDS=(shell tmux git tools node uv go docker tailscale ssh claude-code codex gemini skills)

COMP_NAMES=(
    "Shell Environment"
    "Tmux"
    "Git"
    "Essential Tools"
    "Clash Proxy"
    "Node.js (nvm)"
    "uv + Python"
    "Go (goenv)"
    "Docker"
    "Tailscale"
    "SSH"
    "Claude Code"
    "Codex CLI"
    "Gemini CLI"
    "Agent Skills"
)

COMP_DESCS=(
    "zsh, Oh My Zsh, plugins, Starship"
    "tmux + Catppuccin + TPM plugins"
    "user.name + user.email + defaults"
    "rg, jq, fd, bat, gh, build tools"
    "clash-for-linux with subscription"
    "nvm + Node.js 24"
    "uv package manager"
    "goenv + Go"
    "Docker Engine + Compose + mirrors"
    "Tailscale VPN mesh network"
    "SSH port + key-only + GitHub proxy"
    "Claude Code CLI"
    "OpenAI Codex CLI"
    "Gemini CLI"
    "Skills for all coding agents"
)

# Whether component update needs sudo
COMP_NEEDS_SUDO=(0 1 1 1 1 0 0 0 1 1 1 0 0 0 0)

# Detection / selection / version state
COMP_INSTALLED=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
COMP_SELECTED=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
VERSION_BEFORE=()
VERSION_AFTER=()

# Visible menu mapping: menu position -> component index
VISIBLE=()

# --- [D] Utility Functions ---------------------------------------------------

SUDO_KEEPALIVE_PID=""
SPINNER_PID=""

cleanup() {
    [[ "$CURSOR_HIDDEN" -eq 1 ]] && printf '\033[?25h' 2>/dev/null
    [[ -n "${SPINNER_PID:-}" ]] && kill "$SPINNER_PID" 2>/dev/null || true
    [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

start_spinner() {
    local msg="$1"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

    # Fallback for non-unicode terminals
    if [[ -z "$BOLD" ]]; then
        frames=('-' '\' '|' '/')
    fi

    printf "${HIDE_CURSOR}" 2>/dev/null
    (
        local i=0
        while true; do
            printf "\r  ${CYAN}%s${NC} ${DIM}%s${NC}  " "${frames[$i]}" "$msg"
            i=$(( (i + 1) % ${#frames[@]} ))
            sleep 0.1
        done
    ) &
    SPINNER_PID=$!
}

stop_spinner() {
    if [[ -n "${SPINNER_PID:-}" ]]; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null || true
        SPINNER_PID=""
    fi
    printf "\r${CLEAR_LINE}"
    printf "${SHOW_CURSOR}" 2>/dev/null
}

cache_sudo() {
    local needs_sudo=0
    for i in "${!COMP_SELECTED[@]}"; do
        if [[ "${COMP_SELECTED[$i]}" -eq 1 && "${COMP_NEEDS_SUDO[$i]}" -eq 1 ]]; then
            needs_sudo=1
            break
        fi
    done

    if [[ $needs_sudo -eq 1 ]]; then
        printf "  ${DIM}Some components require sudo. Caching credentials...${NC}\n"
        sudo -v
        # Keep sudo alive in background
        ( while true; do sudo -n true 2>/dev/null; sleep 50; done ) &
        SUDO_KEEPALIVE_PID=$!
    fi
}

print_banner() {
    printf "\n"
    printf "  ${CYAN}${BOLD}┌──────────────────────────────────────────┐${NC}\n"
    printf "  ${CYAN}${BOLD}│${NC}  ${BOLD}${WHITE}Rig Updater${NC}                             ${CYAN}${BOLD}│${NC}\n"
    printf "  ${CYAN}${BOLD}│${NC}  ${DIM}${_GH}/${REPO}${NC}                 ${CYAN}${BOLD}│${NC}\n"
    printf "  ${CYAN}${BOLD}└──────────────────────────────────────────┘${NC}\n"
    printf "\n"
}

hr() {
    printf "  ${DIM}──────────────────────────────────────────${NC}\n"
}

show_help() {
    cat << 'HELP'
Usage: update.sh [OPTIONS]

Interactive rig updater with checkbox selection.
Only installed components are shown; all are selected by default.

Options:
  --all                  Update all installed components
  --components LIST      Comma-separated component list:
                         shell,tmux,git,tools,clash,node,uv,go,docker,tailscale,ssh,claude-code,codex,gemini,skills
  --gh-proxy URL         GitHub proxy URL (e.g., https://gh-proxy.org)
  -v, --verbose          Show raw command output (default: clean spinner)
  -h, --help             Show this help

Environment variables:
  GH_PROXY               Same as --gh-proxy
  NODE_VERSION           Pin Node.js version for update (default: latest)

Examples:
  bash update.sh                                    # Interactive
  bash update.sh --all                              # Update everything installed
  bash update.sh --components codex,claude-code      # Specific components
  bash update.sh --all --gh-proxy https://gh-proxy.org

  # Via curl
  curl -fsSL URL/update.sh | bash
  curl -fsSL URL/update.sh | bash -s -- --all
HELP
}

load_env() {
    # Load nvm if available
    if [[ -d "$HOME/.nvm" ]]; then
        export NVM_DIR="$HOME/.nvm"
        # shellcheck disable=SC1091
        [[ -f "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
    fi
    # Add uv to PATH
    [[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"
    # Load goenv if available
    if [[ -d "$HOME/.goenv" ]]; then
        export GOENV_ROOT="$HOME/.goenv"
        export PATH="$GOENV_ROOT/bin:$PATH"
        eval "$(goenv init -)" 2>/dev/null || true
    fi
}

# --- [E] Detection -----------------------------------------------------------

detect_installed() {
    local checks=(
        "test -d $HOME/.oh-my-zsh"
        "command -v tmux"
        "command -v git"
        "command -v rg && command -v jq"
        "test -d $HOME/clash-for-linux"
        "command -v nvm || [[ -f $HOME/.nvm/nvm.sh ]]"
        "command -v uv"
        "command -v goenv || [[ -d $HOME/.goenv/bin ]]"
        "command -v docker"
        "command -v tailscale"
        "test -f /etc/ssh/sshd_config"
        "command -v claude"
        "command -v codex"
        "command -v gemini"
        "test -d $HOME/.local/share/skills || test -d $HOME/.claude/skills"
    )

    for i in "${!checks[@]}"; do
        if eval "${checks[$i]}" &>/dev/null; then
            COMP_INSTALLED[$i]=1
        fi
    done
}

get_version() {
    local idx=$1
    local ver=""
    case "${COMP_IDS[$idx]}" in
        shell)
            ver=$(starship --version 2>/dev/null | head -1 | awk '{print $2}') || true
            ;;
        tmux)
            ver=$(tmux -V 2>/dev/null | awk '{print $2}') || true
            ;;
        git)
            ver=$(git --version 2>/dev/null | awk '{print $3}') || true
            ;;
        tools)
            ver=$(rg --version 2>/dev/null | head -1 | awk '{print $2}') || true
            ;;
        clash)
            ver="installed"
            ;;
        node)
            ver=$(node -v 2>/dev/null) || true
            ;;
        uv)
            ver=$(uv --version 2>/dev/null | awk '{print $2}') || true
            ;;
        go)
            ver=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//') || true
            ;;
        docker)
            ver=$(docker --version 2>/dev/null | sed 's/Docker version //' | sed 's/,.*//') || true
            ;;
        tailscale)
            ver=$(tailscale version 2>/dev/null | head -1) || true
            ;;
        ssh)
            ver=$(ssh -V 2>&1 | awk '{print $1}' | sed 's/OpenSSH_//; s/,.*//') || true
            ;;
        claude-code)
            ver=$(claude --version 2>/dev/null | head -1) || true
            ;;
        codex)
            ver=$(codex --version 2>/dev/null | head -1) || true
            ;;
        gemini)
            ver=$(gemini --version 2>/dev/null | head -1) || true
            ;;
        skills)
            ver="installed"
            ;;
    esac
    echo "${ver:-unknown}"
}

# --- [F] Update Functions ----------------------------------------------------

update_shell() {
    # Oh My Zsh
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        env ZSH="$HOME/.oh-my-zsh" DISABLE_UPDATE_PROMPT=true \
            bash "$HOME/.oh-my-zsh/tools/upgrade.sh" 2>/dev/null || true
    fi

    # Custom plugins (git pull each)
    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    if [[ -d "$zsh_custom/plugins" ]]; then
        for plugin_dir in "$zsh_custom/plugins/"*/; do
            [[ -d "$plugin_dir/.git" ]] && git -C "$plugin_dir" pull --ff-only 2>/dev/null || true
        done
    fi

    # Custom themes (git pull each)
    if [[ -d "$zsh_custom/themes" ]]; then
        for theme_dir in "$zsh_custom/themes/"*/; do
            [[ -d "$theme_dir/.git" ]] && git -C "$theme_dir" pull --ff-only 2>/dev/null || true
        done
    fi

    # Starship
    if command -v starship &>/dev/null; then
        sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- -y 2>/dev/null || true
    fi
}

update_tmux() {
    pkg_update tmux 2>/dev/null || true

    # TPM plugin update
    if [[ -x "$HOME/.tmux/plugins/tpm/bin/update_plugins" ]]; then
        "$HOME/.tmux/plugins/tpm/bin/update_plugins" all 2>/dev/null || true
    fi
}

update_git() {
    pkg_update git 2>/dev/null || true
}

update_tools() {
    pkg_update ripgrep jq fd bat tree shellcheck build-tools wget unzip xclip 2>/dev/null || true
    pkg_update gh 2>/dev/null || true
}

update_clash() {
    if [[ -d "$HOME/clash-for-linux" ]]; then
        (
            cd "$HOME/clash-for-linux" || exit 1
            git pull --ff-only || true
            sudo bash install.sh || true
        )
    fi
}

update_node() {
    load_env
    if ! command -v nvm &>/dev/null; then
        return 0
    fi

    local current
    current=$(nvm current 2>/dev/null)
    [[ -z "$current" || "$current" == "none" || "$current" == "system" ]] && return 0

    local target
    if [[ -n "${NODE_VERSION:-}" ]]; then
        target="$NODE_VERSION"
    else
        # Stay on current major version track (e.g., default=24 → update to latest 24.x)
        # This avoids jumping to a new major (e.g., 25) and orphaning global packages
        target=$(echo "$current" | sed 's/^v//' | cut -d. -f1)
    fi

    local latest
    latest=$(nvm version-remote "$target" 2>/dev/null)

    if [[ -z "$latest" || "$latest" == "N/A" ]]; then
        echo "Could not resolve latest version for Node.js $target"
        return 1
    fi

    if [[ "$latest" == "$current" ]]; then
        echo "Node.js $current is already the latest for $target"
        return 0
    fi

    nvm install "$target" --reinstall-packages-from="$current"
    nvm alias default "$target"
}

update_uv() {
    uv self update 2>/dev/null || true
}

update_go() {
    if [[ -d "$HOME/.goenv" ]]; then
        git -C "$HOME/.goenv" pull --ff-only 2>/dev/null || true
        load_env
        local latest
        latest=$(goenv install --list 2>/dev/null | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
        if [[ -n "$latest" ]]; then
            goenv install "$latest" 2>/dev/null || true
            goenv global "$latest"
        fi
    fi
}

update_docker() {
    if is_macos; then
        # Docker Desktop on macOS manages its own updates
        brew upgrade --cask docker 2>/dev/null || true
    else
        pkg_update docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null || true
    fi
}

update_tailscale() {
    if command -v tailscale &>/dev/null; then
        if is_macos; then
            brew upgrade --cask tailscale 2>/dev/null || true
        else
            sudo tailscale update 2>/dev/null || {
                pkg_update tailscale 2>/dev/null || true
            }
        fi
    fi
}

update_ssh() {
    if is_macos; then
        # macOS SSH is part of the OS; no package to upgrade
        return 0
    fi
    pkg_update openssh-server 2>/dev/null || true
}

update_claude_code() {
    load_env
    npm install -g @anthropic-ai/claude-code@latest
}

update_codex() {
    load_env
    npm install -g @openai/codex@latest
}

update_gemini() {
    load_env
    npm install -g @google/gemini-cli@latest
}

update_skills() {
    load_env
    local npm_mirror="${SKILLS_NPM_MIRROR:-}"
    [[ -n "$GH_PROXY" && -z "$npm_mirror" ]] && npm_mirror="https://registry.npmmirror.com"

    local flags=(-g -a '*' -y)
    local skills=(
        "vercel-labs/skills                --skill find-skills"
        "anthropics/skills                 --skill pdf"
        "X-Zero-L/agent-skills             --skill gemini-cli"
        "intellectronica/agent-skills      --skill context7"
        "obra/superpowers                  --skill writing-plans executing-plans"
        "softaworks/agent-toolkit          --skill codex"
    )

    for entry in "${skills[@]}"; do
        # shellcheck disable=SC2086
        npx ${npm_mirror:+--registry="$npm_mirror"} skills add $entry "${flags[@]}" 2>/dev/null || true
    done
}

run_update() {
    local idx=$1
    case "${COMP_IDS[$idx]}" in
        shell)       update_shell ;;
        tmux)        update_tmux ;;
        git)         update_git ;;
        tools)       update_tools ;;
        clash)       update_clash ;;
        node)        update_node ;;
        uv)          update_uv ;;
        go)          update_go ;;
        docker)      update_docker ;;
        tailscale)   update_tailscale ;;
        ssh)         update_ssh ;;
        claude-code) update_claude_code ;;
        codex)       update_codex ;;
        gemini)      update_gemini ;;
        skills)      update_skills ;;
    esac
}

# --- [G] TUI Menu ------------------------------------------------------------

read_key() {
    local key=""
    IFS= read -rsn1 key 2>/dev/null </dev/tty || true

    if [[ "$key" == $'\x1b' ]]; then
        local seq
        IFS= read -rsn2 -t 0.1 seq 2>/dev/null </dev/tty
        case "$seq" in
            '[A') echo "UP" ;;
            '[B') echo "DOWN" ;;
            *)    echo "ESC" ;;
        esac
    elif [[ "$key" == "" ]]; then
        echo "ENTER"
    elif [[ "$key" == " " ]]; then
        echo "SPACE"
    elif [[ "$key" == "a" || "$key" == "A" ]]; then
        echo "A"
    elif [[ "$key" == "q" || "$key" == "Q" ]]; then
        echo "Q"
    else
        echo "$key"
    fi
}

render_menu() {
    local cursor_pos=$1
    local total=${#VISIBLE[@]}
    local selected_count=0

    for vi in "${!VISIBLE[@]}"; do
        local ci="${VISIBLE[$vi]}"
        [[ "${COMP_SELECTED[$ci]}" -eq 1 ]] && ((selected_count++))
    done

    # Move cursor to top of menu area
    local menu_height=$((total + 4))
    printf "\033[%dA" "$menu_height"

    # Header
    printf "${CLEAR_LINE}\n"
    printf "${CLEAR_LINE}  ${DIM}↑↓${NC} navigate  ${DIM}space${NC} toggle  ${DIM}a${NC} all  ${DIM}enter${NC} confirm  ${DIM}q${NC} quit\n"

    # Component lines
    for vi in $(seq 0 $((total - 1))); do
        local ci="${VISIBLE[$vi]}"
        printf "${CLEAR_LINE}"

        # Cursor indicator
        if [[ $vi -eq $cursor_pos ]]; then
            printf "  ${SYM_ARROW} "
        else
            printf "    "
        fi

        # Checkbox
        if [[ "${COMP_SELECTED[$ci]}" -eq 1 ]]; then
            printf "${SYM_FILL} "
        else
            printf "${SYM_DOT} "
        fi

        # Name (padded) - highlight current row
        if [[ $vi -eq $cursor_pos ]]; then
            printf "${BOLD}${WHITE}%-22s${NC} " "${COMP_NAMES[$ci]}"
        else
            printf "${BOLD}%-22s${NC} " "${COMP_NAMES[$ci]}"
        fi

        # Description
        printf "${DIM}%-34s${NC}" "${COMP_DESCS[$ci]}"

        # Tags
        if [[ "${COMP_NEEDS_SUDO[$ci]}" -eq 1 ]]; then
            printf " ${DIM}[${NC} ${YELLOW}sudo${NC} ${DIM}]${NC}"
        fi

        printf "\n"
    done

    # Footer
    printf "${CLEAR_LINE}\n"
    if [[ $selected_count -gt 0 ]]; then
        printf "${CLEAR_LINE}  ${GREEN}${BOLD}%d${NC}${DIM} component(s) selected${NC}\n" "$selected_count"
    else
        printf "${CLEAR_LINE}  ${DIM}No components selected${NC}\n"
    fi
}

show_checkbox_menu() {
    local cursor=0
    local total=${#VISIBLE[@]}

    printf "${HIDE_CURSOR}"
    CURSOR_HIDDEN=1

    # Reserve space
    local menu_height=$((total + 4))
    for ((i = 0; i < menu_height; i++)); do
        printf "\n"
    done

    render_menu $cursor

    while true; do
        local key
        key=$(read_key)

        case "$key" in
            UP)
                ((cursor > 0)) && ((cursor--))
                ;;
            DOWN)
                ((cursor < total - 1)) && ((cursor++))
                ;;
            SPACE)
                local ci="${VISIBLE[$cursor]}"
                if [[ "${COMP_SELECTED[$ci]}" -eq 1 ]]; then
                    COMP_SELECTED[$ci]=0
                else
                    COMP_SELECTED[$ci]=1
                fi
                ;;
            A)
                local any_selected=0
                for vi in "${!VISIBLE[@]}"; do
                    local ci="${VISIBLE[$vi]}"
                    [[ "${COMP_SELECTED[$ci]}" -eq 1 ]] && any_selected=1 && break
                done
                local new_val=$((1 - any_selected))
                for vi in "${!VISIBLE[@]}"; do
                    local ci="${VISIBLE[$vi]}"
                    COMP_SELECTED[$ci]=$new_val
                done
                ;;
            ENTER)
                break
                ;;
            Q)
                printf "${SHOW_CURSOR}"; CURSOR_HIDDEN=0
                printf "\n  ${DIM}Aborted.${NC}\n\n"
                exit 0
                ;;
        esac

        render_menu $cursor
    done

    printf "${SHOW_CURSOR}"; CURSOR_HIDDEN=0
}

# --- [H] Update Engine -------------------------------------------------------

run_component_update() {
    local idx=$1
    local step=$2
    local total=$3
    local comp_log="${LOG_FILE}.${COMP_IDS[$idx]}"

    # Reload env between components
    load_env

    if [[ "$VERBOSE" -eq 1 ]]; then
        # Verbose: show raw output
        printf "\n"
        printf "  ${BOLD}${CYAN}[%d/%d]${NC} ${BOLD}${WHITE}%s${NC}\n" "$step" "$total" "${COMP_NAMES[$idx]}"
        printf "  ${CYAN}────────────────────────────────────────${NC}\n"

        if run_update "$idx" 2>&1 | tee "$comp_log"; then
            printf "  ${CYAN}────────────────────────────────────────${NC}\n"
            printf "  ${SYM_CHECK} ${GREEN}%s${NC}\n" "${COMP_NAMES[$idx]}"
            return 0
        else
            printf "  ${CYAN}────────────────────────────────────────${NC}\n"
            printf "  ${SYM_CROSS} ${RED}%s${NC}\n" "${COMP_NAMES[$idx]}"
            return 1
        fi
    else
        # Clean mode: spinner in background
        start_spinner "Updating ${COMP_NAMES[$idx]}..."

        run_update "$idx" > "$comp_log" 2>&1
        local result=$?

        stop_spinner

        if [[ $result -eq 0 ]]; then
            printf "  ${SYM_CHECK} ${BOLD}${CYAN}[%d/%d]${NC} %s\n" "$step" "$total" "${COMP_NAMES[$idx]}"
            return 0
        else
            printf "  ${SYM_CROSS} ${BOLD}${CYAN}[%d/%d]${NC} ${RED}%s${NC}\n" "$step" "$total" "${COMP_NAMES[$idx]}"
            # Show last lines of log on failure
            printf "  ${DIM}── last 15 lines ──${NC}\n"
            tail -n 15 "$comp_log" 2>/dev/null | sed 's/^/    /'
            printf "  ${DIM}── full log: %s ──${NC}\n" "$comp_log"
            return 1
        fi
    fi
}

run_all_selected() {
    local ordered=("$@")
    local total=${#ordered[@]}
    local step=0
    local succeeded=0
    local failed=0
    local failed_names=()
    local succeeded_names=()
    local succeeded_indices=()

    # Capture before versions
    for idx in "${ordered[@]}"; do
        load_env
        VERSION_BEFORE[$idx]=$(get_version "$idx")
    done

    printf "\n"
    for idx in "${ordered[@]}"; do
        ((step++))
        if run_component_update "$idx" "$step" "$total"; then
            ((succeeded++))
            succeeded_names+=("${COMP_NAMES[$idx]}")
            succeeded_indices+=("$idx")
        else
            ((failed++))
            failed_names+=("${COMP_NAMES[$idx]}")
        fi
        # Capture after version
        load_env
        VERSION_AFTER[$idx]=$(get_version "$idx")
    done

    # Summary
    printf "\n"
    printf "  ${BOLD}${CYAN}┌──────────────────────────────────────────┐${NC}\n"
    printf "  ${BOLD}${CYAN}│${NC}  ${BOLD}${WHITE}Update Summary${NC}                          ${BOLD}${CYAN}│${NC}\n"
    printf "  ${BOLD}${CYAN}└──────────────────────────────────────────┘${NC}\n"
    printf "\n"

    for idx in "${ordered[@]}"; do
        local before="${VERSION_BEFORE[$idx]:-unknown}"
        local after="${VERSION_AFTER[$idx]:-unknown}"
        local name="${COMP_NAMES[$idx]}"

        # Check if this component succeeded
        local was_ok=0
        for si in "${succeeded_indices[@]}"; do
            [[ "$si" -eq "$idx" ]] && was_ok=1 && break
        done

        if [[ $was_ok -eq 1 ]]; then
            if [[ "$before" != "$after" && "$before" != "unknown" && "$after" != "unknown" && "$before" != "installed" ]]; then
                printf "  ${SYM_CHECK} %-22s ${DIM}%s → %s${NC}\n" "$name" "$before" "$after"
            else
                printf "  ${SYM_CHECK} %-22s ${DIM}(no change)${NC}\n" "$name"
            fi
        else
            printf "  ${SYM_CROSS} %-22s ${RED}failed${NC}\n" "$name"
        fi
    done

    printf "\n"
    printf "  ${DIM}Result: ${GREEN}${BOLD}%d passed${NC}" "$succeeded"
    if [[ $failed -gt 0 ]]; then
        printf " ${DIM}/${NC} ${RED}${BOLD}%d failed${NC}" "$failed"
    fi
    printf "\n"

    if [[ $failed -gt 0 ]]; then
        printf "\n  ${DIM}Logs: ${NC}${CYAN}${LOG_FILE}.*${NC}\n"
    fi

    printf "\n"
    return "$failed"
}

# --- [I] Argument Parser -----------------------------------------------------

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)
                NON_INTERACTIVE=1
                shift
                ;;
            --components)
                if [[ $# -lt 2 ]]; then
                    echo "error: --components requires an argument" >&2
                    exit 1
                fi
                IFS=',' read -ra REQUESTED <<< "$2"
                for req in "${REQUESTED[@]}"; do
                    req=$(echo "$req" | tr -d ' ')
                    for i in "${!COMP_IDS[@]}"; do
                        if [[ "${COMP_IDS[$i]}" == "$req" ]]; then
                            COMP_SELECTED[$i]=1
                        fi
                    done
                done
                NON_INTERACTIVE=1
                shift 2
                ;;
            --gh-proxy)
                if [[ $# -lt 2 ]]; then
                    echo "error: --gh-proxy requires an argument" >&2
                    exit 1
                fi
                GH_PROXY="$2"
                shift 2
                ;;
            --verbose|-v)
                VERBOSE=1
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                printf "${RED}Unknown option: %s${NC}\n" "$1"
                show_help
                exit 1
                ;;
        esac
    done
}

# --- [J] Main ----------------------------------------------------------------

main() {
    setup_colors

    # Parse CLI arguments
    parse_args "$@"

    # Load env early so detection can find nvm, goenv, etc.
    load_env

    # Determine interactive mode
    if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
        if [[ -e /dev/tty ]]; then
            INTERACTIVE=1
        else
            echo "Error: No terminal available. Use --all or --components to specify what to update."
            echo "  Example: curl ... | bash -s -- --all"
            echo "  Example: curl ... | bash -s -- --components codex,claude-code"
            exit 1
        fi
    fi

    LOG_FILE="/tmp/rig-update-$(date +%Y%m%d-%H%M%S)"

    # Banner
    print_banner

    # Detect installed components
    detect_installed

    local installed_count=0
    for v in "${COMP_INSTALLED[@]}"; do
        [[ "$v" -eq 1 ]] && ((installed_count++))
    done

    if [[ $installed_count -eq 0 ]]; then
        printf "  ${DIM}No rig components detected. Run${NC} ${CYAN}install.sh${NC} ${DIM}first.${NC}\n\n"
        exit 0
    fi

    printf "  ${DIM}Found ${BOLD}%d${NC}${DIM} installed component(s):${NC}\n" "$installed_count"

    # Build visible mapping (menu position -> component index)
    VISIBLE=()
    for i in "${!COMP_IDS[@]}"; do
        if [[ "${COMP_INSTALLED[$i]}" -eq 1 ]]; then
            VISIBLE+=("$i")
        fi
    done

    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
        # Check if --components was used (explicit selection)
        local has_explicit=0
        for s in "${COMP_SELECTED[@]}"; do
            [[ "$s" -eq 1 ]] && has_explicit=1 && break
        done

        if [[ $has_explicit -eq 0 ]]; then
            # --all mode: select all installed
            for i in "${!COMP_INSTALLED[@]}"; do
                COMP_SELECTED[$i]=${COMP_INSTALLED[$i]}
            done
        else
            # --components mode: warn about non-installed selections
            for i in "${!COMP_SELECTED[@]}"; do
                if [[ "${COMP_SELECTED[$i]}" -eq 1 && "${COMP_INSTALLED[$i]}" -eq 0 ]]; then
                    printf "  ${SYM_WARN} ${YELLOW}%s${NC} ${DIM}is not installed, skipping${NC}\n" "${COMP_NAMES[$i]}"
                    COMP_SELECTED[$i]=0
                fi
            done
        fi
    else
        # Interactive: default all installed to selected
        for i in "${!COMP_INSTALLED[@]}"; do
            COMP_SELECTED[$i]=${COMP_INSTALLED[$i]}
        done
        show_checkbox_menu
    fi

    # Check that at least one component is selected
    local any_selected=0
    for s in "${COMP_SELECTED[@]}"; do
        [[ "$s" -eq 1 ]] && any_selected=1 && break
    done
    if [[ "$any_selected" -eq 0 ]]; then
        printf "  ${DIM}No components selected. Exiting.${NC}\n\n"
        exit 0
    fi

    # Build ordered list
    local ordered=()
    for i in "${!COMP_SELECTED[@]}"; do
        [[ "${COMP_SELECTED[$i]}" -eq 1 ]] && ordered+=("$i")
    done

    # Show plan
    printf "\n"
    printf "  ${BOLD}${SYM_PLAY} Update plan${NC}\n"
    hr

    local step=0
    for idx in "${ordered[@]}"; do
        ((step++))
        local suffix=""
        if [[ "${COMP_NEEDS_SUDO[$idx]}" -eq 1 ]]; then
            suffix+=" ${YELLOW}sudo${NC}"
        fi
        printf "  ${CYAN}%2d${NC} ${DIM}│${NC} %-24s${DIM}%s${NC}%b\n" \
            "$step" "${COMP_NAMES[$idx]}" "${COMP_DESCS[$idx]}" "$suffix"
    done

    hr
    printf "  ${DIM}Total: ${BOLD}%d${NC}${DIM} component(s)${NC}\n" "${#ordered[@]}"
    printf "\n"

    # Confirm in interactive mode
    if [[ "$INTERACTIVE" -eq 1 ]]; then
        printf "  ${BOLD}Proceed?${NC} ${DIM}[Y/n]${NC} "
        local confirm
        read -r confirm </dev/tty
        if [[ "$confirm" =~ ^[Nn] ]]; then
            printf "\n  ${DIM}Aborted.${NC}\n\n"
            exit 0
        fi
        printf "\n"
    fi

    # Pre-cache sudo credentials
    cache_sudo

    # Execute updates
    run_all_selected "${ordered[@]}"
    local result=$?

    # Final message
    if [[ $result -eq 0 ]]; then
        printf "  ${SYM_CHECK} ${GREEN}${BOLD}All done!${NC}\n\n"
    else
        printf "  ${SYM_WARN} ${YELLOW}${BOLD}Some components failed. See logs above.${NC}\n\n"
    fi

    exit "$result"
}

main "$@"
