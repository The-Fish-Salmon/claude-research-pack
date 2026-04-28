---
description: One-paragraph snapshot of the active project — reads vault overview and latest auto-review summary.
argument-hint: (no args)
---

Produce a concise status snapshot for the user's active research project. Do **not** spawn a subagent — read the files yourself and summarize inline.

## Resolve paths first

- **Vault root**: `$OBSIDIAN_VAULT_PATH` (env var). If unset, say "vault unreachable" and skip vault-sourced fields.
- **Active project slug**: read `$ACTIVE_PROJECT` if set; otherwise scan `${OBSIDIAN_VAULT_PATH}/10_Projects/*/overview.md` and pick the first one whose frontmatter contains `status: active`. If none match, fall back to the most-recently-modified `overview.md`.
- **Memory dir**: it's the `memory/` sibling of the current session's transcript. The Claude Code path is `~/.claude/projects/{encoded-cwd}/memory/`. Use `~` (Path.home()) — never assume a specific username.

## Do this

1. Read `${OBSIDIAN_VAULT_PATH}/10_Projects/{active-slug}/overview.md` — pull status, phase, latest run.
2. Read the newest file in `${OBSIDIAN_VAULT_PATH}/10_Projects/{active-slug}/runs/` — pull its one-line headline.
3. Read `~/.claude/projects/{encoded-cwd}/memory/review_latest.md` if present — pull the summary line + age.
4. Read `~/.claude/projects/{encoded-cwd}/memory/todos_latest.md` if present — count carried-over items.
5. Optionally `git -C "$(pwd)" log --oneline -3` for recent code commits in the current directory.

## Output

A single short paragraph (4-6 lines) formatted like:

```
**{project-slug}** — phase {n}, status={status}. Latest run: {run-name} ({one-line headline}).
{one project-specific fact line — model file, key metric, etc., if overview surfaces one}.
Auto-review: "{summary}" ({age}d ago).
Carried-over TODOs: {n}.
Recent commits: <3 bullets or "none">.
```

If a file is missing, write `{unknown}` for that field — do not fail loudly. If the vault is unreachable, say so in one line and skip vault-sourced fields.
