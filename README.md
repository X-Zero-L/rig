# rig

[中文](README_CN.md)

Automated setup scripts for Linux and macOS systems.

## Supported Operating Systems

| OS | Package Manager | Status |
|----|----------------|--------|
| Debian/Ubuntu | `apt` | ✓ Full support |
| CentOS/RHEL | `yum`/`dnf` | ✓ Full support |
| Fedora | `dnf` | ✓ Full support |
| Arch Linux | `pacman` | ✓ Full support |
| macOS | `brew` | ✓ Full support (see [macOS notes](#macos-notes)) |

> All scripts are **idempotent** — safe to run multiple times. Already installed components are skipped automatically. Requires `curl`, `git`, and `sudo` (except some macOS operations).

## Quick Start

Use `install.sh` for a one-stop interactive or non-interactive installation.

> **Note:** After installation, the `rig` CLI will be automatically installed to `~/.local/bin/rig`. You can then use commands like `rig status`, `rig export`, `rig uninstall`, etc. See [Management Tools](docs/rig-management.md) for details.

<p align="center">
  <img src="assets/demo.gif" alt="install.sh demo" width="700">
</p>

Interactive TUI — select what to install:

```bash
curl -fsSL https://ba.sh/rig | bash
# or: curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/install.sh | bash
```

Via proxy (recommended for China):

```bash
curl -fsSL https://z.ls/rig | bash -s -- --gh-proxy https://gh-proxy.org
# or: curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/X-Zero-L/rig/master/install.sh | bash -s -- --gh-proxy https://gh-proxy.org
```

> **💡 China users:** For the best experience, install Clash **first** — the setup script adds `clashctl` and `watch_proxy` to your shell rc, so proxy env vars are automatically active in every new terminal. Once Clash is running (`clashctl on`), all subsequent rig scripts work without `GH_PROXY`.
> ```bash
> curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-clash.sh | bash -s -- 'https://your-subscription-url'
> # Then enable proxy:
> source ~/.bashrc && clashctl on
> ```

Install everything non-interactively:

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/install.sh | bash -s -- --all
```

Specific components only:

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/install.sh | bash -s -- --components shell,node,docker
```

With pre-configured API keys:

```bash
export CLAUDE_API_URL=https://your-api-url CLAUDE_API_KEY=your-key
export CODEX_API_URL=https://your-api-url  CODEX_API_KEY=your-key
export GEMINI_API_URL=https://your-api-url GEMINI_API_KEY=your-key
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/install.sh | bash -s -- --all
```

Verbose mode (show raw script output instead of spinner):

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/install.sh | bash -s -- --all --verbose
```

Available components: `shell`, `tmux`, `git`, `clash`, `node`, `uv`, `go`, `docker`, `tailscale`, `ssh`, `claude-code`, `codex`, `gemini`, `skills`

**New:** Use presets for common setups:
```bash
# AI agent development (shell, tools, git, node, claude-code, codex, gemini, skills)
curl -fsSL https://ba.sh/rig | bash -s -- --preset agent

# See all presets: minimal, agent, devops, fullstack
# Docs: https://github.com/X-Zero-L/rig/blob/master/docs/rig-management.md
```

## Components

Each script can also be run standalone. All scripts support two install styles — direct and via gh-proxy:

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/<script> | bash
```

```bash
curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/X-Zero-L/rig/master/<script> | bash
```

---

### Base Environment

#### Shell (`setup-shell.sh`)

Installs zsh, Oh My Zsh, plugins (autosuggestions, syntax-highlighting, z), Starship prompt with Catppuccin Powerline preset. Requires `sudo`.

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-shell.sh | bash
```

Via proxy:

```bash
curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-shell.sh | bash
```

#### Tmux (`setup-tmux.sh`)

Installs [tmux](https://github.com/tmux/tmux), [TPM](https://github.com/tmux-plugins/tpm) plugin manager, [Catppuccin](https://github.com/catppuccin/tmux) theme, and essential plugins (sensible, vim-tmux-navigator, yank, resurrect, continuum). Requires `sudo`.

Default (no custom keybindings):

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-tmux.sh | bash
```

With custom keybindings (Ctrl+a prefix, `|` and `-` splits, vim-style resize):

```bash
export TMUX_KEYBINDS=1
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-tmux.sh | bash
```

Via proxy:

```bash
curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-tmux.sh | bash
```

Config: `TMUX_KEYBINDS`, `TMUX_MOUSE`, `TMUX_STATUS_POS`, `GH_PROXY` — see [Configuration Reference](#configuration-reference).

#### Git (`setup-git.sh`)

Configures Git global `user.name`, `user.email`, and sensible defaults (`init.defaultBranch=main`, `pull.rebase=true`, etc.).

```bash
export GIT_USER_NAME="Your Name"
export GIT_USER_EMAIL="you@example.com"
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-git.sh | bash
```

Config: `GIT_USER_NAME`, `GIT_USER_EMAIL` — see [Configuration Reference](#configuration-reference).

#### Clash Proxy (`setup-clash.sh`)

Installs [clash-for-linux](https://github.com/nelvko/clash-for-linux-install) with subscription support.

With subscription URL as argument:

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-clash.sh | bash -s -- 'https://your-subscription-url'
```

With pre-exported env var:

```bash
export CLASH_SUB_URL='https://your-subscription-url'
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-clash.sh | bash
```

Via proxy:

```bash
curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-clash.sh | bash -s -- 'https://your-subscription-url'
```

Config: `CLASH_SUB_URL`, `CLASH_KERNEL`, `CLASH_GH_PROXY` — see [Configuration Reference](#configuration-reference).

#### Docker (`setup-docker.sh`)

Installs [Docker Engine](https://docs.docker.com/engine/install/), Compose plugin, configures registry mirrors, log rotation, address pools, and optional proxy. Requires `sudo`.

Default (no mirror, suitable for overseas):

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-docker.sh | bash
```

Custom configuration:

```bash
export DOCKER_MIRROR=https://mirror.example.com
export DOCKER_DATA_ROOT=/data/docker
export DOCKER_PROXY=http://localhost:7890
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-docker.sh | bash
```

Via proxy:

```bash
curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-docker.sh | bash
```

Config: `DOCKER_MIRROR`, `DOCKER_PROXY`, `DOCKER_DATA_ROOT`, `DOCKER_LOG_SIZE`, etc. — see [Configuration Reference](#configuration-reference).

#### Tailscale (`setup-tailscale.sh`)

Installs [Tailscale](https://tailscale.com/) VPN mesh network.

Install only:

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-tailscale.sh | bash
```

Install + auto connect:

```bash
export TAILSCALE_AUTH_KEY=tskey-auth-xxxxx
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-tailscale.sh | bash
```

#### SSH (`setup-ssh.sh`)

Configures OpenSSH server: custom port, key-only authentication, and GitHub SSH proxy.

Install only (ensure sshd running):

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-ssh.sh | bash
```

Change port + enable key-only auth:

```bash
export SSH_PORT=2222
export SSH_PUBKEY="ssh-ed25519 AAAA..."
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-ssh.sh | bash
```

With GitHub SSH proxy (when port 22 is blocked or proxy required):

```bash
export SSH_PROXY_PORT=7890
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-ssh.sh | bash
```

Config: `SSH_PORT`, `SSH_PUBKEY`, `SSH_PROXY_PORT` — see [Configuration Reference](#configuration-reference).

---

### Language Runtimes

#### Node.js (`setup-node.sh`)

Installs [nvm](https://github.com/nvm-sh/nvm) and Node.js.

Default (Node.js 24):

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-node.sh | bash
```

Specific version:

```bash
export NODE_VERSION=22
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-node.sh | bash
```

Via proxy:

```bash
curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-node.sh | bash
```

#### uv + Python (`setup-uv.sh`)

Installs [uv](https://docs.astral.sh/uv/) package manager, optionally installs a Python version.

uv only:

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-uv.sh | bash
```

uv + Python:

```bash
export UV_PYTHON=3.12
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-uv.sh | bash
```

Via proxy:

```bash
curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-uv.sh | bash
```

#### Go (`setup-go.sh`)

Installs [goenv](https://github.com/go-nv/goenv) and Go.

Default (latest Go):

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-go.sh | bash
```

Specific version:

```bash
export GO_VERSION=1.23.0
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-go.sh | bash
```

Via proxy:

```bash
curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-go.sh | GH_PROXY=https://gh-proxy.org bash
```

---

### AI Coding Agents

All three agent scripts share the same behavior:

- **With API keys** → install tool + write config (skip if already up to date)
- **Without API keys** → install tool only, configure later
- **Re-run with keys** → skip install, check and update config if changed

#### Claude Code (`setup-claude-code.sh`)

Installs [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI. Alias: `cc`.

Install + configure:

```bash
export CLAUDE_API_URL=https://your-api-url
export CLAUDE_API_KEY=your-key
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-claude-code.sh | bash
```

Install only (configure later):

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-claude-code.sh | bash
```

Via CLI arguments:

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-claude-code.sh | bash -s -- --api-url https://your-api-url --api-key your-key
```

Via proxy:

```bash
curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-claude-code.sh | bash
```

Config: `CLAUDE_API_URL`, `CLAUDE_API_KEY`, `CLAUDE_MODEL`, `CLAUDE_NPM_MIRROR` — see [Configuration Reference](#configuration-reference).

#### Codex CLI (`setup-codex.sh`)

Installs [Codex CLI](https://github.com/openai/codex). Alias: `cx`.

Install + configure:

```bash
export CODEX_API_URL=https://your-api-url
export CODEX_API_KEY=your-key
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-codex.sh | bash
```

Install only (configure later):

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-codex.sh | bash
```

Via CLI arguments:

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-codex.sh | bash -s -- --api-url https://your-api-url --api-key your-key
```

Via proxy:

```bash
curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-codex.sh | bash
```

Config: `CODEX_API_URL`, `CODEX_API_KEY`, `CODEX_MODEL`, `CODEX_EFFORT`, `CODEX_NPM_MIRROR` — see [Configuration Reference](#configuration-reference).

#### Gemini CLI (`setup-gemini.sh`)

Installs [Gemini CLI](https://github.com/google-gemini/gemini-cli). Alias: `gm`.

Install + configure:

```bash
export GEMINI_API_URL=https://your-api-url
export GEMINI_API_KEY=your-key
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-gemini.sh | bash
```

Install only (configure later):

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-gemini.sh | bash
```

Via CLI arguments:

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-gemini.sh | bash -s -- --api-url https://your-api-url --api-key your-key
```

Via proxy:

```bash
curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-gemini.sh | bash
```

Config: `GEMINI_API_URL`, `GEMINI_API_KEY`, `GEMINI_MODEL`, `GEMINI_NPM_MIRROR` — see [Configuration Reference](#configuration-reference).

#### Agent Skills (`setup-skills.sh`)

Installs common [agent skills](https://skills.sh/) globally for all coding agents.

| Skill | Source | Description |
|-------|--------|-------------|
| `find-skills` | [vercel-labs/skills](https://github.com/vercel-labs/skills) | Discover and install agent skills |
| `pdf` | [anthropics/skills](https://github.com/anthropics/skills) | PDF reading and manipulation |
| `gemini-cli` | [X-Zero-L/agent-skills](https://github.com/X-Zero-L/agent-skills) | Gemini CLI integration |
| `context7` | [intellectronica/agent-skills](https://github.com/intellectronica/agent-skills) | Library documentation lookup |
| `writing-plans` | [obra/superpowers](https://github.com/obra/superpowers) | Implementation plan writing |
| `executing-plans` | [obra/superpowers](https://github.com/obra/superpowers) | Plan execution with checkpoints |
| `codex` | [softaworks/agent-toolkit](https://github.com/softaworks/agent-toolkit) | Codex agent skill |

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-skills.sh | bash
```

Via proxy:

```bash
curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-skills.sh | bash
```

Config: `SKILLS_NPM_MIRROR` — see [Configuration Reference](#configuration-reference).

## Configuration Reference

All environment variables across all scripts in one table.

### General

| Variable | Scope | Default | Description |
|----------|-------|---------|-------------|
| `GH_PROXY` | `install.sh` | _(empty)_ | GitHub proxy URL for script downloads |

### Tmux

| Variable | Default | Description |
|----------|---------|-------------|
| `TMUX_KEYBINDS` | `0` | Enable custom keybindings: Ctrl+a prefix, \| and - splits, vim-style resize (`1` to enable) |
| `TMUX_MOUSE` | `1` | Enable mouse support (`0` to disable) |
| `TMUX_STATUS_POS` | `top` | Status bar position (`top` or `bottom`) |

### Git

| Variable | Default | Description |
|----------|---------|-------------|
| `GIT_USER_NAME` | _(empty)_ | `git config --global user.name` value |
| `GIT_USER_EMAIL` | _(empty)_ | `git config --global user.email` value |

### Clash

| Variable | Default | Description |
|----------|---------|-------------|
| `CLASH_SUB_URL` | _(empty)_ | Subscription URL (also accepted as first argument) |
| `CLASH_KERNEL` | `mihomo` | Proxy kernel (`mihomo` or `clash`) |
| `CLASH_GH_PROXY` | `https://gh-proxy.org` | GitHub proxy for clash downloads (empty to disable) |

### Node.js

| Variable | Default | Description |
|----------|---------|-------------|
| `NODE_VERSION` | `24` | Node.js major version (also accepted as first argument) |
| `NVM_NODEJS_ORG_MIRROR` | _(empty)_ | Node.js binary mirror. Auto-set when `GH_PROXY` is set. |
| `NPM_REGISTRY` | _(empty)_ | npm registry URL. Auto-set when `GH_PROXY` is set. |

### uv + Python

| Variable | Default | Description |
|----------|---------|-------------|
| `UV_PYTHON` | _(empty)_ | Python version to install (also accepted as first argument) |

### Go

| Variable | Default | Description |
|----------|---------|-------------|
| `GO_VERSION` | `latest` | Go version to install (also accepted as first argument) |
| `GO_BUILD_MIRROR_URL` | _(empty)_ | Go binary download mirror. Auto-set when `GH_PROXY` is set. |

### Docker

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCKER_MIRROR` | _(empty)_ | Registry mirror URL(s), comma-separated. Auto-set to `https://docker.1ms.run` when `--gh-proxy` is used in `install.sh` |
| `DOCKER_PROXY` | _(empty)_ | HTTP/HTTPS proxy for daemon and containers |
| `DOCKER_NO_PROXY` | `localhost,127.0.0.0/8` | No-proxy list |
| `DOCKER_DATA_ROOT` | _(empty)_ | Data directory (default: `/var/lib/docker`) |
| `DOCKER_LOG_SIZE` | `20m` | Max size per log file |
| `DOCKER_LOG_FILES` | `3` | Max number of log files |
| `DOCKER_EXPERIMENTAL` | `1` | Enable experimental features (`0` to disable) |
| `DOCKER_ADDR_POOLS` | `172.17.0.0/12:24,192.168.0.0/16:24` | Default address pools (`base/cidr:size`) |
| `DOCKER_COMPOSE` | `1` | Install docker-compose-plugin (`0` to skip) |

### Tailscale

| Variable | Default | Description |
|----------|---------|-------------|
| `TAILSCALE_AUTH_KEY` | _(empty)_ | Auth key for auto-connect. Leave empty to install only. |

### SSH

| Variable | Default | Description |
|----------|---------|-------------|
| `SSH_PORT` | _(empty)_ | Custom SSH port. Leave empty to keep current port. |
| `SSH_PUBKEY` | _(empty)_ | Public key string. When set, adds key and disables password auth. |
| `SSH_PRIVATE_KEY` | _(empty)_ | Private key content. When set, imports to `~/.ssh/` for outbound SSH. |
| `SSH_PROXY_HOST` | `127.0.0.1` | Proxy host for GitHub SSH. Only used when `SSH_PROXY_PORT` is set. |
| `SSH_PROXY_PORT` | _(empty)_ | Proxy port (e.g. `7890`). Configures GitHub SSH via `ssh.github.com:443` + corkscrew. |

### Claude Code

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_API_URL` | _(empty)_ | API base URL (skip config if empty) |
| `CLAUDE_API_KEY` | _(empty)_ | Auth token (skip config if empty) |
| `CLAUDE_MODEL` | `opus` | Model name |
| `CLAUDE_NPM_MIRROR` | _(empty)_ | npm registry mirror. Auto-set when `GH_PROXY` is set. |

### Codex CLI

| Variable | Default | Description |
|----------|---------|-------------|
| `CODEX_API_URL` | _(empty)_ | API base URL (skip config if empty) |
| `CODEX_API_KEY` | _(empty)_ | API key (skip config if empty) |
| `CODEX_MODEL` | `gpt-5.2` | Model name |
| `CODEX_EFFORT` | `xhigh` | Reasoning effort |
| `CODEX_NPM_MIRROR` | _(empty)_ | npm registry mirror. Auto-set when `GH_PROXY` is set. |

### Gemini CLI

| Variable | Default | Description |
|----------|---------|-------------|
| `GEMINI_API_URL` | _(empty)_ | API base URL (skip config if empty) |
| `GEMINI_API_KEY` | _(empty)_ | API key (skip config if empty) |
| `GEMINI_MODEL` | `gemini-3-pro-preview` | Model name |
| `GEMINI_NPM_MIRROR` | _(empty)_ | npm registry mirror. Auto-set when `GH_PROXY` is set. |

### Agent Skills

| Variable | Default | Description |
|----------|---------|-------------|
| `SKILLS_NPM_MIRROR` | _(empty)_ | npm registry mirror. Auto-set when `GH_PROXY` is set. |

## Bootstrap Guide

Step-by-step flow for setting up a fresh machine. The recommended order ensures dependencies are met.

**1. Proxy** (so subsequent downloads are faster)

```bash
curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/X-Zero-L/rig/master/setup-clash.sh | bash -s -- 'https://your-subscription-url'
```

```bash
source ~/.bashrc && clashon
```

**2. Prepare API keys** (optional — omit to install tools without config)

```bash
export CLAUDE_API_URL=https://your-api-url CLAUDE_API_KEY=your-key
export CODEX_API_URL=https://your-api-url  CODEX_API_KEY=your-key
export GEMINI_API_URL=https://your-api-url GEMINI_API_KEY=your-key
```

**3. Install everything**

```bash
curl -fsSL https://raw.githubusercontent.com/X-Zero-L/rig/master/install.sh | bash -s -- --all
```

Or install components individually in this order:

1. `setup-shell.sh` — Shell environment (zsh, plugins, Starship)
2. `setup-tmux.sh` — Tmux + Catppuccin + plugins
3. `setup-git.sh` — Git user identity + defaults
4. `setup-ssh.sh` — SSH port + key-only auth
5. `setup-docker.sh` — Docker Engine + Compose
6. `setup-tailscale.sh` — Tailscale VPN
7. `setup-uv.sh` — uv + Python
8. `setup-go.sh` — goenv + Go
9. `setup-node.sh` — nvm + Node.js
10. `setup-claude-code.sh` — Claude Code
11. `setup-codex.sh` — Codex CLI
12. `setup-gemini.sh` — Gemini CLI
13. `setup-skills.sh` — Agent skills

## Detailed Documentation

See the [docs/](docs/) directory for in-depth documentation on each script — what gets installed, which files are created/modified, re-run behavior, and OS-specific notes.

## macOS Notes

macOS support has the following differences:

- **Docker**: Uses Docker Desktop instead of Docker Engine. The `setup-docker.sh` script installs via Homebrew and does not configure systemd services (macOS doesn't use systemd).
- **SSH**: Uses macOS Remote Login instead of OpenSSH server configuration via `systemctl`.
- **Clash Proxy**: Not supported on macOS (Linux-only component).
- **Homebrew**: Automatically installed if not present. The scripts detect and use `brew` instead of `apt`/`yum`/`dnf`/`pacman`.
- **sudo**: Some Homebrew operations don't require sudo. The scripts handle this automatically.

## Notes

- Starship icons require a [Nerd Font](https://www.nerdfonts.com/) in your terminal.
- If `gh-proxy.org` is unavailable, check [ghproxy.link](https://ghproxy.link/) for alternatives.
- Re-running a script with different API keys/config will update the configuration without reinstalling.
- **Linux-only components**: Clash proxy is only available on Linux systems.
