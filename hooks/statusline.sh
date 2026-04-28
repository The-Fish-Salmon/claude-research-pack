#!/usr/bin/env bash
# Status line — tiny snapshot of project state for the Claude Code bottom bar.
# Output: single line, format:
#   <active-project> | review: <age> | todos: <n> | mem: <n>
#
# Path resolution (cross-user, cross-host):
#   - Memory dir: $HOME/.claude/projects/<encoded-cwd>/memory, where <encoded-cwd>
#     is the current working directory with /, : and \ replaced by - (Claude Code's
#     own encoding). Falls back to the first sibling memory/ if that exact dir
#     doesn't exist.
#   - Active project: scans $OBSIDIAN_VAULT_PATH/10_Projects/*/overview.md for
#     `status: active`; override with $ACTIVE_PROJECT.
# All fields gracefully degrade to "?" / "none" / "0" when their source is missing.

set -u

# 1. Locate the memory dir.
encoded_cwd=$(pwd | sed 's:[/\\:]:-:g' | sed 's:^-::' | tr 'A-Z' 'a-z')
MEM="$HOME/.claude/projects/-$encoded_cwd/memory"
if [ ! -d "$MEM" ]; then
    # Fallback: any sibling memory/ under .claude/projects/*
    MEM=$(find "$HOME/.claude/projects" -maxdepth 2 -type d -name memory 2>/dev/null | head -1)
fi

# 2. Active project from vault overview frontmatter.
PROJ="?"
if [ -n "${OBSIDIAN_VAULT_PATH:-}" ] && [ -d "${OBSIDIAN_VAULT_PATH}/10_Projects" ]; then
    SLUG="${ACTIVE_PROJECT:-}"
    OVERVIEW=""
    if [ -n "$SLUG" ] && [ -f "${OBSIDIAN_VAULT_PATH}/10_Projects/$SLUG/overview.md" ]; then
        OVERVIEW="${OBSIDIAN_VAULT_PATH}/10_Projects/$SLUG/overview.md"
    else
        # Pick the first project whose overview.md has `status: active`.
        for d in "${OBSIDIAN_VAULT_PATH}/10_Projects"/*/; do
            ov="${d}overview.md"
            if [ -f "$ov" ] && grep -qiE '^status:[[:space:]]*active' "$ov" 2>/dev/null; then
                SLUG=$(basename "${d%/}")
                OVERVIEW="$ov"
                break
            fi
        done
    fi
    if [ -n "$OVERVIEW" ]; then
        STATUS=$(awk '/^status:/ {gsub(/[[:space:]]/,"",$2); print $2; exit}' "$OVERVIEW")
        PROJ="${SLUG}${STATUS:+/$STATUS}"
    fi
fi

# 3. Last auto-review age (add ! if >=3 days stale).
REVIEW_AGE="none"
if [ -n "${MEM:-}" ] && [ -f "$MEM/review_latest.md" ]; then
    MTIME=$(stat -c %Y "$MEM/review_latest.md" 2>/dev/null || stat -f %m "$MEM/review_latest.md" 2>/dev/null)
    if [ -n "$MTIME" ]; then
        AGE_DAYS=$(( ( $(date +%s) - MTIME ) / 86400 ))
        if [ "$AGE_DAYS" -ge 3 ]; then
            REVIEW_AGE="${AGE_DAYS}d!"
        else
            REVIEW_AGE="${AGE_DAYS}d"
        fi
    fi
fi

# 4. Carried-over todo count.
TODO_N=0
if [ -n "${MEM:-}" ] && [ -f "$MEM/todos_latest.md" ]; then
    TODO_N=$(grep -c '^- \[' "$MEM/todos_latest.md" 2>/dev/null || echo 0)
fi

# 5. Memory file count.
MEM_N=0
if [ -n "${MEM:-}" ]; then
    MEM_N=$(ls -1 "$MEM"/*.md 2>/dev/null | wc -l | tr -d ' ')
fi

printf '%s | review: %s | todos: %s | mem: %s' "$PROJ" "$REVIEW_AGE" "$TODO_N" "$MEM_N"
