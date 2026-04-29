# 10_Projects

PARA-style **active projects** -- work with a defined goal and an end. Each project is a folder; each folder has at minimum an `overview.md` (the project's MOC -- Map of Content).

## Layout

```
10_Projects/
├── <project-slug>/
│   ├── overview.md        <- project MOC: status, scope, deliverables, citekeys
│   ├── runs/              <- experiment runs (timestamped)
│   ├── notes/             <- drafts, design docs, meeting notes
│   └── figures/
└── ...
```

## `overview.md` frontmatter (recommended)

```yaml
---
project: <slug>
status: active        # active | paused | done | abandoned
started: YYYY-MM-DD
goal: one-sentence north star
deliverables: []
citekeys: []          # papers this project relies on; lit-status / lit-map cross-references this
---
```

The `statusline.ps1` / `statusline.sh` hook reads `status:` from the active project's `overview.md` to display in the Claude Code statusline.

## When a project ends

Move the whole folder to `40_Archive/projects/<slug>/`. Keep the citekeys in the archived `overview.md` so future search can find which projects relied on which papers.
