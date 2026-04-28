# Mode: `lit-review`

Annotated bibliography + cross-source synthesis. 1,500–4,000 words. The output is a **catalog** of sources, each with a one-paragraph annotation, plus a synthesis section pulling threads across them.

## Workflow

1. **Scoping** — agree on the inclusion criterion (topic boundary, year range, source tier).
2. **Investigation** — 2× `investigator.md` in parallel. Each pulls 8–15 candidate papers across the MCP priority order. Goal: 15–30 papers in the long list.
3. **Triage** — sequential pass: from the long list, pick 8–20 that get full annotations. Drop rest with one-line dismissal each (so the user can see what was considered).
4. **Capture** — for every paper that gets a full annotation, call `paper-capture` so the vault accumulates the corpus.
5. **Synthesis** — 1× `synthesizer.md` only. (Bias auditor is lighter here — fold into annotations.)
6. **Devil's Advocate** — one checkpoint after synthesis. Can block if the synthesis overstates.
7. **Composition** — 1× `composer.md`, against [templates/report_lit_review.md](../templates/report_lit_review.md).
8. **Hand-off** — write `00_Inbox/lit-review-{slug}-{date}.md` via Obsidian MCP.

## Required sections

- Scope & inclusion criteria
- Long-list table (citekey, title, year, included? rationale)
- Annotated entries (8–20, in citation order):
  - Citation (APA)
  - 100–200 word annotation: question, method, finding, why it matters here
  - Quality / risk-of-bias notes
- Synthesis (cross-cutting patterns, agreements, contradictions, gaps)
- Suggested next reads
- Provenance

## This mode is the workhorse

Most of the time the user actually wants a lit-review even when they say "research". When in doubt, choose this mode and say so in the first response.
