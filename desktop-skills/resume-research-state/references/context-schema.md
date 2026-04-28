# Research Continuity Context Schema

The source of truth is a visible folder at the root of an Obsidian vault:

```text
00-Claude-Context/
  current-state.md
  research-memory.md
  preferences.md
  decision-log.md
  open-questions.md
  task-ledger.md
  paper-map.md
  manifest.json
  session-snapshots/
    YYYY-MM-DDTHHMMSSZ-device.md
```

## Required Frontmatter

Every Markdown context file starts with:

```yaml
---
schema_version: 1.0.0
doc_type: current-state
source_device: device-slug
last_updated: 2026-04-28T00:00:00Z
---
```

Use the most specific `doc_type` for each file:

- `current-state`
- `research-memory`
- `preferences`
- `decision-log`
- `open-questions`
- `task-ledger`
- `paper-map`
- `session-snapshot`

## Write Policy

- Write only inside the selected research vault and `00-Claude-Context/`.
- Never write into Claude app data, `local-agent-mode-sessions/`, keychains,
  caches, browser stores, or audit logs.
- Treat `session-snapshots/` as append-only. Never overwrite a prior snapshot.
- Update durable files from the latest accepted snapshot only after preserving
  the snapshot.
- If two devices have concurrent snapshots, preserve both and synthesize a new
  reconciled snapshot before updating `current-state.md`.

## Snapshot Contents

A useful snapshot includes:

- Current research goal and scope.
- Files, papers, notes, datasets, and folders consulted.
- Claims or results established during the session.
- Open questions and blocked decisions.
- Tasks completed, active, deferred, or abandoned.
- User preferences or corrections learned in the session.
- A short resume prompt that a future session can read first.

Do not include secrets, passwords, access tokens, private keys, cookies, or
irrelevant personal data.
