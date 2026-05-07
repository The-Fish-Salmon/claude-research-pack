#!/usr/bin/env bash
#
# path-a-selftest.sh -- post-install verification for Path A (Claude Code on WSL).
#
# Six checks. Each prints [ok] / [fail] / [warn] with a one-line reason.
# Exits 0 if all green, 1 otherwise. Re-runnable any time:
#   $ bash scripts/path-a-selftest.sh
#
# Called automatically at the end of `scripts/setup.sh`.

set -u

pass=0
fail=0
ok()   { printf '\033[32m[ok]\033[0m   %s\n' "$*"; pass=$((pass+1)); }
fl()   { printf '\033[31m[fail]\033[0m %s\n' "$*"; fail=$((fail+1)); }
wn()   { printf '\033[33m[warn]\033[0m %s\n' "$*"; }

echo "== Path A self-test =="

# Source ~/.bashrc env block so the env vars are visible to *this* shell, not
# just the parent. The block is auto-managed by setup.sh.
if grep -qF '# >>> claude-research-pack env >>>' "${HOME}/.bashrc" 2>/dev/null; then
    # shellcheck disable=SC1090
    set -a
    eval "$(awk '/# >>> claude-research-pack env >>>/{flag=1; next} /# <<< claude-research-pack env <<</{flag=0} flag' "${HOME}/.bashrc")"
    set +a
fi

# 1. claude --version exits 0
if command -v claude >/dev/null 2>&1; then
    ver="$(claude --version 2>&1 | head -1)"
    if [[ -n "$ver" ]]; then
        ok "claude --version -> $ver"
    else
        fl "claude --version produced no output"
    fi
else
    fl "claude CLI not on PATH. Install Claude Code from https://claude.ai/code"
fi

# 2. claude mcp list shows the expected 7 servers
expected=(arxiv semantic-scholar paper-search paper-mcp scihub university-paper-access obsidian)
if command -v claude >/dev/null 2>&1; then
    mcp_out="$(claude mcp list 2>&1 || true)"
    missing=()
    for s in "${expected[@]}"; do
        if ! grep -qE "\b${s}\b" <<< "$mcp_out"; then
            missing+=("$s")
        fi
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        ok "claude mcp list shows all 7 servers"
    elif [[ ${#missing[@]} -eq 1 && "${missing[0]}" == "scihub" ]]; then
        wn "scihub missing or red (often network-blocked; safe to ignore)"
        ok "claude mcp list shows 6/7 servers (scihub tolerated)"
    else
        fl "claude mcp list missing servers: ${missing[*]}"
    fi
fi

# 3. ~/.claude.json parses; mcpServers has 7 entries
claude_json="${HOME}/.claude.json"
if [[ ! -f "$claude_json" ]]; then
    fl "~/.claude.json not found at $claude_json"
else
    if jq -e '.mcpServers' "$claude_json" >/dev/null 2>&1; then
        n=$(jq '.mcpServers | length' "$claude_json" 2>/dev/null || echo 0)
        if [[ "$n" -ge 7 ]]; then
            ok "~/.claude.json has $n mcpServers entries"
        else
            fl "~/.claude.json has only $n mcpServers entries (expected >=7)"
        fi
    else
        fl "~/.claude.json failed to parse or has no mcpServers key"
    fi
fi

# 4. ~/.claude/settings.json parses; .hooks present
settings_json="${HOME}/.claude/settings.json"
if [[ ! -f "$settings_json" ]]; then
    fl "~/.claude/settings.json not found at $settings_json"
else
    if jq -e '.hooks' "$settings_json" >/dev/null 2>&1; then
        ok "~/.claude/settings.json has a 'hooks' block"
    else
        fl "~/.claude/settings.json has no 'hooks' block (or fails to parse)"
    fi
fi

# 5. Env vars OBSIDIAN_VAULT_PATH / OBSIDIAN_API_KEY / UNPAYWALL_EMAIL /
#    PAPER_DOWNLOAD_DIR visible to a *fresh* login shell (i.e. survive a
#    re-login, not just shell-local).
probe="$(bash -lc 'echo "${OBSIDIAN_VAULT_PATH:-}|${OBSIDIAN_API_KEY:-}|${UNPAYWALL_EMAIL:-}|${PAPER_DOWNLOAD_DIR:-}"' 2>/dev/null)"
IFS='|' read -r v k e p <<< "$probe"
missing_vars=()
[[ -z "$v" ]] && missing_vars+=("OBSIDIAN_VAULT_PATH")
[[ -z "$k" ]] && missing_vars+=("OBSIDIAN_API_KEY")
[[ -z "$e" ]] && missing_vars+=("UNPAYWALL_EMAIL")
[[ -z "$p" ]] && missing_vars+=("PAPER_DOWNLOAD_DIR")
if [[ ${#missing_vars[@]} -eq 0 ]]; then
    ok "all 4 required env vars visible to a fresh login shell"
else
    fl "env vars NOT visible to a fresh login shell: ${missing_vars[*]} -- check ~/.bashrc env block"
fi

# 6. Obsidian Local REST API reachable (TLS, port 27124)
# On WSL2, the Windows-side Obsidian listens on the Windows host's
# 127.0.0.1; from inside WSL that may or may not be reachable depending on
# WSL networking mode. We try both 127.0.0.1 and the Windows host IP
# (default gateway).
if [[ -n "${OBSIDIAN_API_KEY:-}" ]]; then
    win_host=""
    if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
        win_host="$(ip route show 2>/dev/null | awk '/^default/ {print $3; exit}')"
    fi
    http_status=""
    for host in 127.0.0.1 ${win_host:-}; do
        [[ -z "$host" ]] && continue
        code="$(curl -sk -o /dev/null -w '%{http_code}' \
            -H "Authorization: Bearer ${OBSIDIAN_API_KEY}" \
            --max-time 5 \
            "https://${host}:27124/" 2>/dev/null)"
        curl_exit=$?
        if [[ $curl_exit -eq 0 && -n "$code" && "$code" != "000" ]]; then
            http_status="$code"
            break
        fi
    done
    [[ -z "$http_status" ]] && http_status="000"

    if [[ "$http_status" == "200" ]]; then
        ok "Obsidian Local REST API reachable on port 27124"
    elif [[ "$http_status" == "401" ]]; then
        fl "Obsidian REST API returned 401 -- API key mismatch. Re-copy from Obsidian plugin settings."
    elif [[ "$http_status" == "000" ]]; then
        if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
            fl "Obsidian REST API not reachable from WSL on 127.0.0.1 or ${win_host:-Windows host}. (1) Is Obsidian running on Windows with the Local REST API plugin enabled? (2) Some WSL2 setups block cross-OS localhost; try plugin's 'Bind Address' = 0.0.0.0 instead of 127.0.0.1."
        else
            fl "Obsidian REST API not reachable. Is Obsidian running with the Local REST API plugin enabled?"
        fi
    else
        fl "Obsidian REST API returned HTTP $http_status (unexpected)"
    fi
else
    wn "OBSIDIAN_API_KEY not set in current shell -- skipping REST API check."
fi

echo ""
printf 'Result: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m.\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]] && exit 0 || exit 1
