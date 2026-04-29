---
name: resume-research-state
description: Rehydrate a Claude Desktop session from {vault}/00-Claude-Context. Use for "resume research", "where was I", "pick up where I left off", "load research context".
---

# Resume Research State (Desktop)

Use this skill at the start of a session that needs continuity from a prior
session -- most importantly, from a session on a *different device*. The source
of truth is `{vault}/00-Claude-Context/`, which sync software (Obsidian Sync /
iCloud / OneDrive / Syncthing) has mirrored to this machine.

This skill never assumes a prior live Claude Desktop chat is available. It
reconstructs context from durable files only.

## Operating Rules (do not violate)

1. Read only the selected vault and `00-Claude-Context/` unless the user grants
   additional scope.
2. Do not inspect Claude app data, keychains, audit logs, browser storage, or
   caches while resuming.
3. If context files are missing or invalid, prefer to run:
   `python "${CLAUDE_PLUGIN_ROOT}/bin/research_sync_agent.py" validate --vault "{vault path}"`
   (or `py -3.12` on Windows), then point the user at any specific failure. If
   the helper isn't reachable, check the files against
   `${CLAUDE_PLUGIN_ROOT}/references/context-schema.md`.
4. **Preserve concurrent snapshots.** If two devices snapshotted overlapping
   sessions, surface both and ask which is authoritative -- never delete or
   overwrite either.

## Resume Procedure

1. Resolve the vault path. Prefer `OBSIDIAN_VAULT_PATH`; if absent, ask once.
2. Read `00-Claude-Context/manifest.json` -- get `last_updated_device` and
   `snapshot_count`.
3. Read in this order, accumulating context:
   - `current-state.md`
   - `task-ledger.md`
   - `open-questions.md`
   - `decision-log.md`
   - `preferences.md`
   - `research-memory.md`
   - `paper-map.md`
4. Inspect `00-Claude-Context/session-snapshots/`:
   - Newest one or two snapshots. List filenames with their `source_device`.
   - If the newest two are from different devices and within ~24h of each
     other, treat as a potential split-brain -- summarize both and ask the user
     which line of work to continue.
5. Produce a short working brief (~10-20 lines):
   - **Goal** (from `current-state.md`).
   - **Most relevant papers and notes** (from `paper-map.md` + the snapshot).
   - **Active tasks** (from `task-ledger.md`).
   - **Known decisions** (latest 2-3 from `decision-log.md`).
   - **Open questions** (top 3 from `open-questions.md`).
   - **Recommended next action** -- taken from the snapshot's "Resume prompt"
     section if present, or synthesized from the active tasks otherwise.
6. Wait for the user to confirm or override the next action. Only then
   continue work.

## Output style

Keep the resume brief practical and citation-flavored. Reference vault paths
and citation keys when possible (`[[30_Literature/kim2023ionic]]`). Do not
describe generic skill behavior unless there is a setup issue the user must
fix.

## Empty / first-run case

If `00-Claude-Context/` exists but every durable file is at its initial
"_Pending._" state, say so plainly: "No prior research state found. Run
`capture-research-state` at the end of this session to seed the continuity
layer." Don't invent context.
