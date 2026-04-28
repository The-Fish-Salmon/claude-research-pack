#!/usr/bin/env bash
#
# setup.sh — bootstrap the deep-research pack into ~/.claude/
#
# Run from inside WSL (Ubuntu) after cloning/extracting the pack.
#   $ bash scripts/setup.sh
#
# Steps:
#   1. Copy skills / hooks / commands into ~/.claude/
#   2. Run mcp-servers/install-mcp-servers.sh
#   3. Merge settings/settings.template.json into ~/.claude/settings.json
#   4. Print next steps

set -euo pipefail

PACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"

log()  { printf '\033[1;34m[setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }

require() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 1; }; }
require jq
require rsync

mkdir -p "${CLAUDE_DIR}/skills" "${CLAUDE_DIR}/hooks" "${CLAUDE_DIR}/commands"

# 1. Skills (additive — won't clobber unrelated skills)
log "Copying skills → ${CLAUDE_DIR}/skills/"
for skill in deep-research paper-capture lit-status handoff; do
  if [[ -d "${PACK_DIR}/skills/${skill}" ]]; then
    rsync -a --delete "${PACK_DIR}/skills/${skill}/" "${CLAUDE_DIR}/skills/${skill}/"
    log "  installed skill: ${skill}"
  fi
done

# 2. Hooks
log "Copying hooks → ${CLAUDE_DIR}/hooks/"
for h in precompact-handoff.py session-start-context.py stop-persist-todos.py statusline.sh paper-mention-detect.py; do
  if [[ -f "${PACK_DIR}/hooks/${h}" ]]; then
    cp "${PACK_DIR}/hooks/${h}" "${CLAUDE_DIR}/hooks/${h}"
    chmod +x "${CLAUDE_DIR}/hooks/${h}"
  fi
done

# 3. Commands
log "Copying slash commands → ${CLAUDE_DIR}/commands/"
for c in research.md capture-paper.md lit-map.md status.md port-to-vault.md; do
  if [[ -f "${PACK_DIR}/commands/${c}" ]]; then
    cp "${PACK_DIR}/commands/${c}" "${CLAUDE_DIR}/commands/${c}"
  fi
done

# 4. MCP servers
log "Installing MCP servers"
bash "${PACK_DIR}/mcp-servers/install-mcp-servers.sh"

# 5. Merge settings.json (hooks, statusline, model)
TEMPLATE="${PACK_DIR}/settings/settings.template.json"
TARGET="${CLAUDE_DIR}/settings.json"

log "Merging settings → ${TARGET}"
TMP=$(mktemp)
envsubst < "${TEMPLATE}" > "${TMP}"

if [[ ! -f "${TARGET}" ]]; then
  cp "${TMP}" "${TARGET}"
else
  # Strip the underscore-prefixed comment / optional keys before merging — those are
  # documentation, not real settings. The user can copy the optional block manually.
  jq 'del(._comment_optional_hooks, ._optional_hooks)' "${TMP}" > "${TMP}.clean"
  jq -s '.[0] * .[1]' "${TARGET}" "${TMP}.clean" > "${TMP}.merged"
  mv "${TMP}.merged" "${TARGET}"
  rm -f "${TMP}" "${TMP}.clean"
fi

log "Done. Next:"
cat <<'EOF'

  1. Export the env vars listed above in your shell rc (UNPAYWALL_EMAIL,
     OBSIDIAN_API_KEY, OBSIDIAN_VAULT_PATH, PAPER_DOWNLOAD_DIR,
     ARXIV_STORAGE_PATH).
  2. Copy vault-templates/* into your Obsidian vault root (idempotent).
  3. Open Claude Code in any project and try:
       /status
       /research --mode quick "test query"
       /capture-paper 10.1038/s41586-021-03819-2
       /lit-map summary

  See INSTALL_WINDOWS.md for the full walkthrough and troubleshooting.
EOF
