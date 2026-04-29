# 40_Archive/reviews

Audit reports written by the `/review-project` slash command (Path A / B). On Path C (Desktop) the same skill writes here when invoked by free text ("review my active project").

Naming: `YYYY-MM-DD-auto-review.md` (or `YYYY-MM-DD-<slug>-review.md` for project-scoped runs).

The latest report is summarized to one line and mirrored into `~/.claude/projects/.../memory/review_latest.md` so SessionStart can surface it without loading the whole report.

Treat reports as immutable -- don't edit them after the fact. If a finding is resolved, log it in the project's `overview.md`, not by editing the original review.
