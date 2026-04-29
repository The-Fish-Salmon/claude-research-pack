# 00-Claude-Context

This folder is the **cross-device research-continuity layer** used by the
Claude Desktop research-continuity skills (`capture-research-state`,
`resume-research-state`, `sync-check`, `paper-map`).

## What's supposed to live here

- `manifest.json` -- bookkeeping (schema version, snapshot count, last device).
- Seven durable Markdown files: `current-state.md`, `research-memory.md`,
  `preferences.md`, `decision-log.md`, `open-questions.md`, `task-ledger.md`,
  `paper-map.md`. Each carries frontmatter that the skills validate.
- `session-snapshots/` -- append-only directory of per-session snapshots,
  named `YYYY-MM-DDTHHMMSSZ-{device-slug}.md`.

When you first install Path C, only this `_README.md` is here. Run

```powershell
PS> python tools/research_sync_agent.py init --vault $env:OBSIDIAN_VAULT_PATH
```

(or `setup.ps1 -Mode Desktop`, which calls it for you) to materialize the
rest. The helper is idempotent -- re-running won't overwrite anything that
already exists.

## How it's meant to sync

Put the vault inside a sync-aware folder: Obsidian Sync (paid, most reliable),
iCloud Drive, OneDrive, Dropbox, Google Drive, or Syncthing. The continuity
skills don't sync anything themselves -- they read and write plain files. Sync
is the user's responsibility.

`session-snapshots/` is **append-only by convention**. The skills will refuse
to delete or overwrite snapshots, even when asked. If two devices snapshot
overlapping work, you'll have two files; `resume-research-state` surfaces both
and asks which to use.

## Don't hand-edit

Don't manually edit `manifest.json` or the frontmatter of the seven Markdown
files (`schema_version:`, `doc_type:`, `source_device:`, `last_updated:`).
`sync-check` will reject the folder if those keys go missing or malformed.

You *can* edit the Markdown body content normally -- that's where the durable
research state lives.

## See also

- The `sync-check` skill -- verify the folder is healthy.
- Each skill's `references/context-schema.md` -- full schema spec.
