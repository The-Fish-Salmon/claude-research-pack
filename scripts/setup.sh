#!/usr/bin/env bash
#
# setup.sh -- bootstrap the claude-research-pack into ~/.claude/ on WSL/Linux.
#
# Usage:
#   $ bash scripts/setup.sh                    # default: REST-API obsidian MCP
#   $ bash scripts/setup.sh --filesystem-mode  # filesystem MCP only, no REST API
#
# --filesystem-mode is the right choice on WSL2 when the Windows-side
# Obsidian Local REST API isn't reachable (Windows Defender Firewall,
# Hyper-V firewall, or other cross-OS-localhost issues that won't yield
# to bind-address 0.0.0.0 / Hyper-V firewall rules / mirrored networking).
# It swaps the bundled obsidian-wrapper.js for the official filesystem
# MCP server (`@modelcontextprotocol/server-filesystem`) scoped to the
# vault. Vault reads/writes work via plain filesystem operations; lose
# Obsidian-side frontmatter search but keep all skill functionality.
#
# v6 (parity with Path B v5):
#   1. Pre-flight: verify or auto-install Claude Code, jq, rsync, curl, git,
#      node, npm, python3, uv. Hard-fails on missing apt-installable
#      prereqs with the exact `sudo apt install` command.
#   2. Wizard: auto-detect defaults from
#        - %APPDATA%/obsidian/obsidian.json    (recent vaults, Windows side)
#        - $vault/.obsidian/plugins/obsidian-local-rest-api/data.json (API key)
#        - git config --global user.email      (Unpaywall email)
#   3. Persistent env vars: append a marked block to ~/.bashrc; also export
#      to current shell.
#   4. Vault bootstrap + Obsidian app.json + templates.json.
#   5. Skills, hooks, commands -> ~/.claude/.
#   6. MCP servers via install-mcp-servers.sh (filesystem-mode-aware).
#   7. Settings merge + self-test.
#
# Idempotent. Re-run any time -- safe.

set -euo pipefail

# ---------- Flags ----------
FILESYSTEM_MODE=0
for arg in "$@"; do
    case "$arg" in
        --filesystem-mode) FILESYSTEM_MODE=1 ;;
        --help|-h)
            sed -n '/^# Usage:/,/^# Idempotent/p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
    esac
done
export PACK_FILESYSTEM_MODE="$FILESYSTEM_MODE"

PACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"

log()  { printf '\033[1;34m[setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[err]\033[0m %s\n' "$*" >&2; }
info() { printf '\033[1;36m[info]\033[0m %s\n' "$*"; }

# ---------- 1. Pre-flight ----------
need_apt=()

# Claude Code: look on PATH first; fall back to the VS Code extension's
# bundled binary. On WSL, the extension lives under
# ~/.vscode-server/extensions/anthropic.claude-code-*-linux-x64/resources/
# native-binary/claude. If found, symlink it into ~/.local/bin so subsequent
# commands (and future shells) can find `claude`.
if ! command -v claude >/dev/null 2>&1; then
    vscode_ext_root="${HOME}/.vscode-server/extensions"
    if [[ -d "$vscode_ext_root" ]]; then
        vscode_claude="$(find "$vscode_ext_root" -maxdepth 4 -type f -name claude -path '*anthropic.claude-code-*' 2>/dev/null | sort | tail -1)"
        if [[ -n "$vscode_claude" && -x "$vscode_claude" ]]; then
            mkdir -p "${HOME}/.local/bin"
            ln -sf "$vscode_claude" "${HOME}/.local/bin/claude"
            export PATH="${HOME}/.local/bin:${PATH}"
            log "Claude Code: $vscode_claude (symlinked to ~/.local/bin/claude)"
        fi
    fi
fi
if ! command -v claude >/dev/null 2>&1; then
    err "claude (Claude Code CLI) not on PATH and not found in VS Code extensions."
    err "Install from https://claude.ai/code (or the VS Code Anthropic extension), then re-run."
    exit 1
fi
log "Claude Code: $(command -v claude)"

# Apt-installable prereqs
for pkg in jq rsync curl git; do
    command -v "$pkg" >/dev/null 2>&1 || need_apt+=("$pkg")
done
# Node/npm: prefer apt; user can also use NodeSource
if ! command -v node >/dev/null 2>&1; then need_apt+=("nodejs"); fi
if ! command -v npm  >/dev/null 2>&1; then need_apt+=("npm"); fi
# Python 3 + venv
if ! command -v python3 >/dev/null 2>&1; then need_apt+=("python3"); fi
if ! python3 -c 'import venv' 2>/dev/null; then need_apt+=("python3-venv"); fi

if [[ ${#need_apt[@]} -gt 0 ]]; then
    err "Missing prerequisites: ${need_apt[*]}"
    err "Install with: sudo apt-get update && sudo apt-get install -y ${need_apt[*]}"
    err "Then re-run scripts/setup.sh."
    exit 1
fi
log "Prereqs: jq rsync curl git node npm python3 python3-venv -- all present"

# uv: auto-install if missing (no sudo needed)
if ! command -v uv >/dev/null 2>&1; then
    log "Installing uv (Python package launcher) -- no sudo required..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="${HOME}/.local/bin:${PATH}"
    if ! command -v uv >/dev/null 2>&1; then
        err "uv install reported success but uv still not on PATH. Check ${HOME}/.local/bin."
        exit 1
    fi
fi
log "uv: $(command -v uv)"

# ---------- 2. Wizard: auto-detect + prompt ----------

# Convert a Windows-style path (C:\foo\bar) to WSL (/mnt/c/foo/bar). If
# already POSIX, return as-is.
win_to_wsl() {
    local p="$1"
    if [[ "$p" =~ ^([A-Za-z]):[\\/](.*)$ ]]; then
        local drive="${BASH_REMATCH[1],,}"
        local rest="${BASH_REMATCH[2]//\\//}"
        echo "/mnt/${drive}/${rest}"
    else
        echo "$p"
    fi
}

# Detect Obsidian's most-recently-opened vault from the Windows-side config.
detect_default_vault() {
    local appdata=""
    # WSL: $APPDATA isn't set; reach into the Windows user's AppData.
    local winuser=""
    if command -v cmd.exe >/dev/null 2>&1; then
        winuser=$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r' || true)
    fi
    if [[ -n "$winuser" ]]; then
        appdata="/mnt/c/Users/${winuser}/AppData/Roaming"
    fi
    if [[ -z "$appdata" || ! -f "$appdata/obsidian/obsidian.json" ]]; then
        echo ""
        return 0
    fi
    # Read recent vaults; pick the one with the largest ts.
    local best
    best=$(jq -r '
        .vaults | to_entries
        | map(.value)
        | sort_by(.ts // 0)
        | reverse
        | .[0].path // empty
    ' "$appdata/obsidian/obsidian.json" 2>/dev/null || true)
    if [[ -n "$best" ]]; then
        win_to_wsl "$best"
    else
        echo ""
    fi
    return 0
}

# Read the API key out of the Local REST API plugin's data.json.
detect_api_key_for_vault() {
    local vault="$1"
    local data="${vault}/.obsidian/plugins/obsidian-local-rest-api/data.json"
    if [[ ! -f "$data" ]]; then
        echo ""
        return 0
    fi
    jq -r '.apiKey // empty' "$data" 2>/dev/null || echo ""
    return 0
}

# Read existing pack-managed env vars from ~/.bashrc (so re-running the
# wizard pre-fills with the user's prior choices, not blank defaults).
# Always exits 0 -- under set -e + pipefail, a failing grep would otherwise
# kill the script.
read_existing_env_var() {
    local name="$1"
    [[ -f "${HOME}/.bashrc" ]] || { echo ""; return 0; }
    grep -E "^export ${name}=" "${HOME}/.bashrc" 2>/dev/null \
        | tail -1 \
        | sed -E "s/^export ${name}=//; s/^[\"']//; s/[\"']$//" \
        || true
    return 0
}

prompt_with_default() {
    # The prompt text goes to STDERR so it doesn't get captured into the
    # caller's `var=$(prompt_with_default ...)` substitution. Only the final
    # echoed value goes to stdout.
    local prompt="$1" default="$2" reply
    if [[ -n "$default" ]]; then
        printf '  %s [%s]: ' "$prompt" "$default" >&2
    else
        printf '  %s: ' "$prompt" >&2
    fi
    read -r reply || true
    if [[ -z "$reply" ]]; then echo "$default"; else echo "$reply"; fi
}

info ""
info "== Configuration wizard =="

# Defaults
default_vault="$(read_existing_env_var OBSIDIAN_VAULT_PATH)"
[[ -z "$default_vault" ]] && default_vault="$(detect_default_vault 2>/dev/null || true)"
[[ -z "$default_vault" ]] && default_vault="${HOME}/Documents/MyVault"

default_email="$(read_existing_env_var UNPAYWALL_EMAIL)"
[[ -z "$default_email" ]] && default_email="$(git config --global user.email 2>/dev/null || echo '')"
[[ -z "$default_email" ]] && default_email="you@example.org"

default_paper_dir="$(read_existing_env_var PAPER_DOWNLOAD_DIR)"
[[ -z "$default_paper_dir" ]] && {
    if [[ -d /mnt/d ]]; then default_paper_dir="/mnt/d/papers"
    else default_paper_dir="${HOME}/papers"; fi
}

vault="$(prompt_with_default 'Obsidian vault path' "$default_vault")"
paper_dir="$(prompt_with_default 'Paper download dir' "$default_paper_dir")"
arxiv_dir="$(prompt_with_default 'arXiv cache dir' "${paper_dir}/arxiv")"
email="$(prompt_with_default 'Unpaywall email' "$default_email")"

# API key: try plugin data.json first; fall back to existing env value.
default_key="$(detect_api_key_for_vault "$vault" 2>/dev/null || true)"
[[ -z "$default_key" ]] && default_key="$(read_existing_env_var OBSIDIAN_API_KEY)"
api_key_display="${default_key:-<paste from Obsidian Local REST API plugin>}"
api_key="$(prompt_with_default 'Obsidian REST API key' "$api_key_display")"
[[ "$api_key" == "<paste from Obsidian Local REST API plugin>" ]] && api_key=""

# ---------- 3. Persistent env vars (~/.bashrc) ----------
log "Updating ~/.bashrc env block (idempotent)..."
BEGIN_MARK="# >>> claude-research-pack env >>>"
END_MARK="# <<< claude-research-pack env <<<"

# Build the block
tmp_block="$(mktemp)"
{
    echo "$BEGIN_MARK"
    echo "# Auto-managed by claude-research-pack/scripts/setup.sh -- edits below"
    echo "# this line will be overwritten on the next run; edit between the marks"
    echo "# only if you understand the wizard will overwrite."
    [[ -n "$vault"      ]] && echo "export OBSIDIAN_VAULT_PATH=\"$vault\""
    [[ -n "$api_key"    ]] && echo "export OBSIDIAN_API_KEY=\"$api_key\""
    [[ -n "$paper_dir"  ]] && echo "export PAPER_DOWNLOAD_DIR=\"$paper_dir\""
    [[ -n "$arxiv_dir"  ]] && echo "export ARXIV_STORAGE_PATH=\"$arxiv_dir\""
    [[ -n "$email"      ]] && echo "export UNPAYWALL_EMAIL=\"$email\""
    echo "$END_MARK"
} > "$tmp_block"

touch "${HOME}/.bashrc"
if grep -qF "$BEGIN_MARK" "${HOME}/.bashrc"; then
    # Replace the existing block in place.
    awk -v begin="$BEGIN_MARK" -v end="$END_MARK" -v block="$(cat "$tmp_block")" '
        $0 == begin { print block; in_block=1; next }
        in_block { if ($0 == end) in_block=0; next }
        { print }
    ' "${HOME}/.bashrc" > "${HOME}/.bashrc.tmp"
    mv "${HOME}/.bashrc.tmp" "${HOME}/.bashrc"
    log "  replaced existing env block"
else
    {
        echo ""
        cat "$tmp_block"
    } >> "${HOME}/.bashrc"
    log "  appended new env block"
fi
rm -f "$tmp_block"

# Export to current shell so the rest of the install can use them.
[[ -n "$vault"     ]] && export OBSIDIAN_VAULT_PATH="$vault"
[[ -n "$api_key"   ]] && export OBSIDIAN_API_KEY="$api_key"
[[ -n "$paper_dir" ]] && export PAPER_DOWNLOAD_DIR="$paper_dir"
[[ -n "$arxiv_dir" ]] && export ARXIV_STORAGE_PATH="$arxiv_dir"
[[ -n "$email"     ]] && export UNPAYWALL_EMAIL="$email"
log "  exported to current shell"

# ---------- 4. Vault bootstrap ----------
if [[ -n "$vault" && -d "$vault" ]]; then
    log "Bootstrapping vault: $vault"
    if [[ -d "${PACK_DIR}/vault-templates" ]]; then
        rsync -a --ignore-existing "${PACK_DIR}/vault-templates/" "${vault}/"
        log "  vault-templates copied (existing files left in place)"
    else
        warn "vault-templates/ not found in pack -- skipping bootstrap"
    fi

    # 5. Obsidian app config (attachments + templates folders)
    obs_config="${vault}/.obsidian"
    mkdir -p "$obs_config"

    # app.json: attachmentFolderPath
    app_json="${obs_config}/app.json"
    if [[ -f "$app_json" ]]; then
        jq '. + {attachmentFolderPath: "80_Attachments"}' "$app_json" > "${app_json}.new"
        mv "${app_json}.new" "$app_json"
    else
        echo '{"attachmentFolderPath": "80_Attachments"}' | jq '.' > "$app_json"
    fi
    log "  Obsidian attachments folder set to 80_Attachments"

    # templates.json (core templates plugin): folder
    templates_json="${obs_config}/templates.json"
    if [[ -f "$templates_json" ]]; then
        jq '. + {folder: "70_Templates"}' "$templates_json" > "${templates_json}.new"
        mv "${templates_json}.new" "$templates_json"
    else
        echo '{"folder": "70_Templates"}' | jq '.' > "$templates_json"
    fi
    log "  Obsidian templates folder set to 70_Templates"
else
    warn "Vault path '$vault' does not exist -- skipping vault bootstrap. Create the folder, then re-run setup."
fi

# ---------- 6. Skills, hooks, commands ----------
mkdir -p "${CLAUDE_DIR}/skills" "${CLAUDE_DIR}/hooks" "${CLAUDE_DIR}/commands"

log "Copying skills -> ${CLAUDE_DIR}/skills/"
for skill in deep-research paper-capture lit-status handoff ingest-pdf research-copilot; do
    if [[ -d "${PACK_DIR}/skills/${skill}" ]]; then
        rsync -a --delete "${PACK_DIR}/skills/${skill}/" "${CLAUDE_DIR}/skills/${skill}/"
        log "  installed skill: ${skill}"
    fi
done

log "Copying hooks -> ${CLAUDE_DIR}/hooks/"
for h in precompact-handoff.py session-start-context.py stop-persist-todos.py statusline.sh paper-mention-detect.py; do
    if [[ -f "${PACK_DIR}/hooks/${h}" ]]; then
        cp "${PACK_DIR}/hooks/${h}" "${CLAUDE_DIR}/hooks/${h}"
        chmod +x "${CLAUDE_DIR}/hooks/${h}"
    fi
done

log "Copying slash commands -> ${CLAUDE_DIR}/commands/"
for c in research.md capture-paper.md lit-map.md status.md port-to-vault.md ingest-pdf.md copilot.md; do
    if [[ -f "${PACK_DIR}/commands/${c}" ]]; then
        cp "${PACK_DIR}/commands/${c}" "${CLAUDE_DIR}/commands/${c}"
    fi
done

# ---------- 7. MCP servers ----------
if [[ "$FILESYSTEM_MODE" == "1" ]]; then
    log "Installing MCP servers (filesystem mode -- no REST API obsidian wrapper)"
else
    log "Installing MCP servers"
fi
bash "${PACK_DIR}/mcp-servers/install-mcp-servers.sh"

# ---------- 8. Settings merge ----------
TEMPLATE="${PACK_DIR}/settings/settings.template.json"
TARGET="${CLAUDE_DIR}/settings.json"

log "Merging settings -> ${TARGET}"
TMP=$(mktemp)
envsubst < "${TEMPLATE}" > "${TMP}"

if [[ ! -f "${TARGET}" ]]; then
    cp "${TMP}" "${TARGET}"
else
    jq 'del(._comment_optional_hooks, ._optional_hooks)' "${TMP}" > "${TMP}.clean"
    backup="${TARGET}.bak.$(date +%Y%m%d%H%M%S)"
    cp "${TARGET}" "${backup}"
    log "  backed up existing settings to ${backup}"
    jq -s '.[0] * .[1]' "${TARGET}" "${TMP}.clean" > "${TMP}.merged"
    mv "${TMP}.merged" "${TARGET}"
    rm -f "${TMP}" "${TMP}.clean"
fi

# ---------- 9. Self-test ----------
selftest="${PACK_DIR}/scripts/path-a-selftest.sh"
if [[ -f "$selftest" ]]; then
    log "Running self-test..."
    if bash "$selftest"; then
        echo ""
        log "Path A install COMPLETE."
        cat <<EOF

  Open a fresh shell (or 'source ~/.bashrc') and try:
    claude
    /status
    /research --mode quick "ion-gated transistors"
    /ingest-pdf /mnt/d/papers/some.pdf
    /copilot
    /lit-map summary

  Re-run the self-test any time:
    bash scripts/path-a-selftest.sh

  Troubleshooting: see INSTALL_WINDOWS.md (Path A).
EOF
    else
        warn 'Self-test reported failures. See [fail] lines above.'
        cat <<EOF

  The pack is mostly installed. Common causes for self-test failures:
    - Env vars not yet visible to a fresh shell -> run `source ~/.bashrc`.
    - Obsidian REST API unreachable             -> launch Obsidian, enable Local REST API plugin.
    - claude mcp list missing servers           -> rerun `bash scripts/setup.sh`.

  Re-run the self-test after fixing:
    bash scripts/path-a-selftest.sh
EOF
    fi
else
    warn 'scripts/path-a-selftest.sh not found -- skipping self-test.'
fi
