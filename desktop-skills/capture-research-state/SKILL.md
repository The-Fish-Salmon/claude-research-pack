---
name: capture-research-state
description: Snapshot the current research session into the Obsidian vault for cross-device resume. Use for "save research state", "snapshot session", "checkpoint research".
---

# Capture Research State (Desktop)

Use this skill to turn the current Claude Desktop session into durable, portable
research context -- a snapshot another device can pick up later.

The destination is a visible folder at the vault root: `00-Claude-Context/`. It
contains an append-only `session-snapshots/` subfolder plus seven durable
Markdown files that summarize the cumulative research state. Obsidian Sync /
iCloud / OneDrive / Syncthing replicates the folder; the next device sees it.

This skill does **not** replace the existing `handoff` skill (that one writes to
the Claude Code memory dir + `00_Inbox/`, single-device). Use `handoff` for a
session-end checkpoint visible to the next chat on the *same* machine; use this
skill when you want continuity across devices.

## Operating Rules (do not violate)

1. Work only inside the selected research vault and its `00-Claude-Context/` folder.
2. Never write into Claude app data, audit logs, credentials, browser stores,
   caches, keychains, or operating-system configuration.
3. Treat `00-Claude-Context/session-snapshots/` as **append-only**. Never
   overwrite or delete an existing snapshot, even if asked.
4. If the context folder is missing or invalid, run the bundled helper:
   `python "${CLAUDE_PLUGIN_ROOT}/bin/research_sync_agent.py" init --vault "{vault path}"`.
   If `python` is not on PATH, fall back to `py -3.12` on Windows. If neither is
   available, build the schema by hand from
   `${CLAUDE_PLUGIN_ROOT}/references/context-schema.md`.
5. Consult `${CLAUDE_PLUGIN_ROOT}/references/context-schema.md` before changing
   any context file.

## Capture Procedure

1. Resolve the vault path. Prefer `OBSIDIAN_VAULT_PATH` from the environment; if
   absent, ask the user once and remember for the rest of the session.
2. Confirm `00-Claude-Context/manifest.json` exists. If missing, run `init` (see
   rule 4) before continuing.
3. Build a snapshot in memory with these sections:
   - **Current goal** -- one paragraph.
   - **Active evidence and files** -- papers, vault notes, datasets, code paths.
   - **Claims established** -- what was settled this session (with citation keys).
   - **Decisions made** -- including reasoning.
   - **Open questions** -- unresolved items blocking progress.
   - **Task ledger changes** -- completed, active, deferred, abandoned.
   - **Preferences or corrections learned** -- user steering this session.
   - **Resume prompt** -- a 2-4 sentence imperative for the next session.
4. Write the snapshot to
   `00-Claude-Context/session-snapshots/{YYYY-MM-DDTHHMMSSZ}-{device-slug}.md`.
   The timestamp is UTC, ISO 8601 with the `Z` suffix. The device slug comes
   from the active machine's hostname (lowercased, alphanumerics + dashes).
   If a file with that exact name somehow exists, append `-{pid}` for collision
   avoidance -- never overwrite.
5. Update the seven durable files from the new snapshot. Each update preserves
   prior content; you are appending or rewriting summary sections, not deleting:
   - `current-state.md` -- overwrite the "Latest snapshot summary" sections.
   - `research-memory.md` -- append durable facts.
   - `preferences.md` -- append/correct user preferences.
   - `decision-log.md` -- append today's decisions with date.
   - `open-questions.md` -- add new, mark closed-but-keep-history.
   - `task-ledger.md` -- move tasks between Active and Done.
   - `paper-map.md` -- only when papers / claims / tags changed.
6. Bump `manifest.json`'s `snapshot_count` and `last_updated` (and
   `last_updated_device` to your slug).
7. Report one line to the user: `Captured: snapshot {filename}, durable files
   updated. Resume on another device with "resume research state".`

## Conflict prevention

- Don't run `init` if `manifest.json` already exists -- it's idempotent for
  files but you don't need to call it.
- If `validate` (or your inspection) reveals a stale or corrupt durable file,
  prefer surgical edits to a single key rather than rewriting the file from
  scratch.

## Quality bar

The next device should be able to read `current-state.md`, `task-ledger.md`,
and the latest snapshot, then continue the research without asking the user to
re-explain what happened. If you can't write a snapshot that passes that bar,
report the gap honestly rather than fabricating context.
