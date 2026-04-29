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
#   - the Sci-Hub-MCP-Server git clone
#   - the university-paper-access server (copied from this package)
#   - obsidian-wrapper.js dependencies (npm install)
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

# 3. Sci-Hub-MCP-Server (git clone)
SCIHUB_DIR="${TARGET_DIR}/Sci-Hub-MCP-Server"
if [[ ! -d "${SCIHUB_DIR}/.git" ]]; then
  log "Cloning Sci-Hub-MCP-Server"
  git clone https://github.com/JackKuo666/Sci-Hub-MCP-Server.git "${SCIHUB_DIR}" || warn "clone failed -- set this up manually if you need scihub"
else
  log "Sci-Hub-MCP-Server already cloned"
fi

# 4. university-paper-access (copy from this package)
UPA_SRC="${PACK_DIR}/mcp-servers/university-paper-access"
UPA_DST="${TARGET_DIR}/university-paper-access"
if [[ -d "${UPA_SRC}" ]]; then
  log "Installing university-paper-access"
  mkdir -p "${UPA_DST}"
  cp -r "${UPA_SRC}/." "${UPA_DST}/"
else
  warn "university-paper-access source missing in pack -- skipping"
fi

# 5. obsidian-wrapper.js
OBS_SRC="${PACK_DIR}/mcp-servers/obsidian-wrapper.js"
OBS_DST="${TARGET_DIR}/obsidian-wrapper.js"
if [[ -f "${OBS_SRC}" ]]; then
  log "Installing obsidian-wrapper.js"
  cp "${OBS_SRC}" "${OBS_DST}"
  # The wrapper depends on a couple of npm packages; install them next to the wrapper.
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

# 6. Merge MCP config into ~/.claude.json
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

log "Done. Required env vars:"
cat <<'EOF'

  export PAPER_DOWNLOAD_DIR=/mnt/d/papers
  export ARXIV_STORAGE_PATH=/mnt/d/papers/arxiv
  export UNPAYWALL_EMAIL=you@example.org
  export OBSIDIAN_VAULT_PATH="/mnt/c/Users/<you>/Documents/MyVault"
  export OBSIDIAN_API_KEY=<from Obsidian Local REST API plugin>

Add these to your ~/.bashrc / ~/.zshrc and restart Claude Code.
EOF
