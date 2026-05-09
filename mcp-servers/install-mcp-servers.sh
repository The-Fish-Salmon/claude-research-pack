#!/usr/bin/env bash
#
# install-mcp-servers.sh
#
# Idempotently install the seven MCP servers used by the deep-research pack
# and merge the corresponding mcpServers entries into ~/.claude.json.
#
# Run this from inside WSL (Ubuntu). It assumes:
#   - the package is checked out (this script lives in mcp-servers/ inside it)
#   - you have curl, git, jq, node (>=20), npm
#
# It will install:
#   - uv (the Python package launcher), if missing
#   - arxiv-mcp-server, semanticscholar-mcp-server, paper-mcp (uv tool install)
#   - paper-search-mcp (resolved on each run via uv run --with)
#   - obsidian-wrapper.js dependencies (npm install)
#
# Paywall bypass on WSL: chrome-devtools-mcp is NOT installed by this script.
# Reason: launching Chrome from inside WSL is brittle (no native Chrome; X server
# or browser-url to a Windows-side Chrome is required). Recommended pattern:
# do paywall work from a Windows-native Claude Code (Path B) where chrome-devtools-mcp
# is configured automatically. See INSTALL_WINDOWS.md and skills/deep-research/
# references/paywall_workflow.md.
#
# After install:
#   - merges settings/claude.template.json into ~/.claude.json (preserves existing entries)
#   - prints the env vars you must export before starting Claude Code

set -euo pipefail

PACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${HOME}/.claude/mcp-servers"
SETTINGS_TARGET="${HOME}/.claude.json"

mkdir -p "${TARGET_DIR}"

log() { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[err]\033[0m %s\n' "$*" >&2; }

require() {
  command -v "$1" >/dev/null 2>&1 || { err "$1 is required but not on PATH"; exit 1; }
}

require curl
require git
require jq
require node
require npm

# 1. uv
if ! command -v uv >/dev/null 2>&1; then
  log "Installing uv (https://astral.sh/uv)"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="${HOME}/.local/bin:${PATH}"
fi
require uv

# 2. uv-installed MCP servers (idempotent -- uv tool install is a no-op if same version)
log "Installing arxiv-mcp-server"
uv tool install arxiv-mcp-server || warn "arxiv-mcp-server install returned non-zero (may already be installed)"

log "Installing semanticscholar-mcp-server"
uv tool install semanticscholar-mcp-server || warn "semanticscholar-mcp-server install returned non-zero"

log "Installing paper-mcp"
uv tool install paper-mcp || warn "paper-mcp install returned non-zero"

# paper-search-mcp is invoked via `uv run --with paper-search-mcp` so it doesn't need a
# global install -- first run will fetch and cache it.

# 3. Obsidian access: REST-API wrapper OR filesystem MCP, depending on mode.
#
# PACK_FILESYSTEM_MODE=1 (set by setup.sh --filesystem-mode) replaces the
# Local-REST-API-based obsidian MCP with the official filesystem MCP server,
# scoped to the vault. The REST-API path requires Obsidian's Local REST API
# plugin to be reachable from this machine; on WSL2 with Windows-side
# Obsidian that's frequently blocked by Windows Defender Firewall / Hyper-V
# firewall / TLS-stack issues. Filesystem mode sidesteps the network entirely.
if [[ "${PACK_FILESYSTEM_MODE:-0}" == "1" ]]; then
  log "Installing filesystem MCP server (mcp-server-filesystem)"
  # Install globally so `mcp-server-filesystem` is on PATH for Claude Code.
  npm install -g --silent @modelcontextprotocol/server-filesystem || \
    warn "npm install of mcp-server-filesystem returned non-zero"
  # Remove any leftover REST-API wrapper from a prior install.
  if [[ -f "${TARGET_DIR}/obsidian-wrapper.js" ]]; then
    log "Removing stale obsidian-wrapper.js (filesystem mode)"
    rm -f "${TARGET_DIR}/obsidian-wrapper.js"
  fi
else
  OBS_SRC="${PACK_DIR}/mcp-servers/obsidian-wrapper.js"
  OBS_DST="${TARGET_DIR}/obsidian-wrapper.js"
  if [[ -f "${OBS_SRC}" ]]; then
    log "Installing obsidian-wrapper.js (REST API mode)"
    cp "${OBS_SRC}" "${OBS_DST}"
    pushd "${TARGET_DIR}" >/dev/null
    if [[ ! -f package.json ]]; then
      npm init -y >/dev/null
    fi
    # mcp-obsidian is the actual MCP server we wrap -- required, not optional.
    npm install --silent @modelcontextprotocol/sdk node-fetch mcp-obsidian || warn "npm install of obsidian wrapper deps returned non-zero"
    popd >/dev/null
  else
    warn "obsidian-wrapper.js missing in pack -- skipping"
  fi
fi

# 4. Merge MCP config into ~/.claude.json
TEMPLATE="${PACK_DIR}/settings/claude.template.json"
if [[ ! -f "${TEMPLATE}" ]]; then
  err "MCP template not found at ${TEMPLATE}"
  exit 1
fi

log "Merging MCP config into ${SETTINGS_TARGET}"
TMP=$(mktemp)

# Expand env vars in the template before merging.
envsubst < "${TEMPLATE}" > "${TMP}.expanded"

if [[ ! -f "${SETTINGS_TARGET}" ]]; then
  cp "${TMP}.expanded" "${SETTINGS_TARGET}"
else
  # Deep-merge: existing entries are preserved; pack entries overwrite same-named ones.
  jq -s '.[0] * .[1]' "${SETTINGS_TARGET}" "${TMP}.expanded" > "${TMP}.merged"
  mv "${TMP}.merged" "${SETTINGS_TARGET}"
fi
rm -f "${TMP}" "${TMP}.expanded" 2>/dev/null

# Filesystem-mode patch: swap the obsidian MCP entry for vault-fs.
if [[ "${PACK_FILESYSTEM_MODE:-0}" == "1" ]]; then
  vault="${OBSIDIAN_VAULT_PATH:-}"
  if [[ -z "$vault" ]]; then
    warn "PACK_FILESYSTEM_MODE=1 but OBSIDIAN_VAULT_PATH is unset; cannot configure vault-fs MCP."
  else
    log "Filesystem mode: swapping obsidian MCP for vault-fs (${vault})"
    backup="${SETTINGS_TARGET}.bak.$(date +%Y%m%d%H%M%S)"
    cp "${SETTINGS_TARGET}" "${backup}"
    jq --arg vault "$vault" '
      .mcpServers
      |= ( del(.obsidian)
           + { "vault-fs": {
                 "type": "stdio",
                 "command": "mcp-server-filesystem",
                 "args": [ $vault ]
               }
             }
         )
    ' "${SETTINGS_TARGET}" > "${SETTINGS_TARGET}.new"
    mv "${SETTINGS_TARGET}.new" "${SETTINGS_TARGET}"
  fi
fi

log "Done. Required env vars:"
cat <<'EOF'

  export PAPER_DOWNLOAD_DIR=/mnt/d/papers
  export ARXIV_STORAGE_PATH=/mnt/d/papers/arxiv
  export UNPAYWALL_EMAIL=you@example.org
  export OBSIDIAN_VAULT_PATH="/mnt/c/Users/<you>/Documents/MyVault"
  export OBSIDIAN_API_KEY=<from Obsidian Local REST API plugin>

Add these to your ~/.bashrc / ~/.zshrc and restart Claude Code.
EOF
