# 40_Archive

Cold storage for finished or abandoned projects, old reviews, and historical material you might want to grep later but don't actively work with.

## Layout

```
40_Archive/
├── projects/         <- retired project folders (moved from 10_Projects/)
├── reviews/          <- auto-review reports written by /review-project
└── snapshots/        <- occasional state dumps (vault audits, citekey re-keying logs)
```

## Reviews

The `/review-project` slash command (Path A/B) writes timestamped audit reports here at `reviews/YYYY-MM-DD-auto-review.md`. The latest one is summarized into `~/.claude/projects/.../memory/review_latest.md` for fast loading at SessionStart.

Don't delete old reviews -- they're a paper trail of when issues were first flagged vs. when they were fixed.

## Conventions

- Don't edit archived material -- treat it as immutable history.
- If you need to revive an archived project, copy it back to `10_Projects/` and edit the copy.
- Citekeys in archived `overview.md` files are still valid references -- `lit-status` / `lit-map` will surface them when computing "papers cited by past projects".
