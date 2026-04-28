# 50_Notes

Atomic / fleeting / Zettelkasten-style notes — durable thoughts that don't belong to a specific project but aren't papers either.

Examples:

- A method or pattern you want to remember (`50_Notes/method-drt-regularization.md`).
- A definition or reusable explanation (`50_Notes/concept-edl-charge-screening.md`).
- A "lesson learned" extracted from a project that should outlive that project.
- Maps of Content (MOCs) that index notes across folders.

## Why this exists alongside `00_Inbox/`

`00_Inbox/` is the *triage* zone — anything dropped there is unsorted and pending review. `50_Notes/` is the *promoted* zone — notes you've decided are worth keeping outside the context of any one project.

Promotion path: `00_Inbox/` → `50_Notes/` (durable, atomic) or `10_Projects/<slug>/notes/` (project-scoped) or `30_Literature/` (paper-attached).

## Conventions

- One concept per note. If you find yourself adding a second `## Section` that introduces a new concept, split it.
- Title with a noun phrase, not a verb (`drt-regularization-tradeoffs.md`, not `how-to-tune-drt.md`).
- Wikilink liberally — the value of `50_Notes/` is the cross-reference graph it forms.
- Frontmatter recommended:
  ```yaml
  ---
  type: concept | method | moc | lesson
  tags: []
  created: YYYY-MM-DD
  ---
  ```

## What this folder is NOT

- **Not** a journal — daily notes belong in `20_Areas/journal/` or wherever you keep them.
- **Not** a paper library — see `30_Literature/`.
- **Not** project-specific working notes — those live in `10_Projects/<slug>/notes/`.
