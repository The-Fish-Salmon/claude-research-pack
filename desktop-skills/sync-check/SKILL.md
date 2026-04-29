---
name: sync-check
description: Verify that the user's Obsidian vault is set up for cross-device research continuity. Triggers on free text like "run sync-check", "is my continuity folder ok", "verify my vault is ready for sync", "check 00-Claude-Context", or proactively when capture-research-state / resume-research-state can't find the expected files. Reports Ready / Not Ready and one specific next action.
---

# Sync Check (Desktop)

Use this skill to verify the cross-device continuity setup *before* relying on
`capture-research-state` or `resume-research-state`. Run it once after install
and again whenever something looks off.

## Checks (in order)

1. Vault root resolved? Prefer `OBSIDIAN_VAULT_PATH`; ask once if missing.
2. `00-Claude-Context/` exists at the vault root and is a normal (visible) folder.
3. Each of these files exists with valid frontmatter:
   - `manifest.json`
   - `current-state.md`
   - `research-memory.md`
   - `preferences.md`
   - `decision-log.md`
   - `open-questions.md`
   - `task-ledger.md`
   - `paper-map.md`
4. `session-snapshots/` exists and is a directory.
5. The snapshot count in `manifest.json` is `>=` the number of `.md` files in
   `session-snapshots/` (append-only invariant).
6. Newest snapshot, if any, has plausible frontmatter.

## How to run

Prefer the bundled helper (one shell call, deterministic):

```
python "${CLAUDE_PLUGIN_ROOT}/bin/research_sync_agent.py" validate --vault "{vault path}"
```

On Windows, fall back to `py -3.12 ...` if `python` is not on PATH. If neither
is available, walk the schema in
`${CLAUDE_PLUGIN_ROOT}/references/context-schema.md` by reading each file.

## Result format

Always emit a short verdict:

```
Vault:           {path}
Status:          Ready | Not Ready
Newest snapshot: {filename or "none"}
Next action:     {one specific step}
```

For "Not Ready", `Next action` should be the single most useful step -- usually
one of:

- `python "${CLAUDE_PLUGIN_ROOT}/bin/research_sync_agent.py" init --vault "{path}"`
- "Set OBSIDIAN_VAULT_PATH to the vault root and re-run."
- "Edit `{file}` to restore frontmatter key `{key}`."
- "Sync provider is split-brain -- review snapshots {a} and {b} and pick one."

Don't enumerate every problem at once if there are many -- name the one that
unblocks the next step. The user re-runs sync-check after fixing.

## What sync-check should NOT do

- Never modify any vault file. It's read-only.
- Never run `init` automatically. The user explicitly invokes it.
- Never delete, rename, or relocate snapshots, even if they look stale.
