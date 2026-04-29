# Mode: `lit-review` (Desktop-lite)

Annotated bibliography + cross-source synthesis. 1,500-4,000 words. The output is a
**catalog** of sources, each with a one-paragraph annotation, plus a synthesis
section pulling threads across them.

## Workflow (single context, sequential)

1. **Scoping** -- agree on the inclusion criterion (topic boundary, year range,
   source tier).
2. **Investigation** -- pull 10-20 candidate papers across the MCP priority order.
   (The Code variant uses 2 parallel investigators to reach 15-30. Desktop drops to
   10-20 because everything is in one context.) Vary search vocabulary explicitly
   to compensate for the lost diversity-of-search.
3. **Triage** -- from the long list, pick 8-15 that get full annotations. Drop the
   rest with one-line dismissal each (so the user can see what was considered).
4. **Capture** -- for every paper that gets a full annotation, invoke `paper-capture`
   so the vault accumulates the corpus.
5. **Synthesis** -- write a synthesis section. Note bias / methodological weaknesses
   inline.
6. **Devil's Advocate Checkpoint** -- one checkpoint after synthesis. Run the
   protocol from SKILL.md. Focus on: did you cherry-pick? what's the strongest
   counter-evidence?
7. **Composition** -- against [templates/report_lit_review.md](../templates/report_lit_review.md).
8. **Hand-off** -- write `00_Inbox/lit-review-{slug}-{date}.md` via Obsidian MCP.

## Required sections

- Scope & inclusion criteria
- Long-list table (citekey, title, year, included? rationale)
- Annotated entries (8-15, in citation order):
  - Citation (APA)
  - 100-200 word annotation: question, method, finding, why it matters here
  - Quality / risk-of-bias notes
- Synthesis (cross-cutting patterns, agreements, contradictions, gaps)
- Suggested next reads
- Provenance

## This mode is the workhorse

Most of the time the user actually wants a lit-review even when they say "research".
When in doubt, choose this mode and say so in the first response.

## Desktop-specific cautions

- The Code variant's two parallel investigators reduce the chance of missing a
  terminology cluster. Desktop's single investigator is more vulnerable to this.
  Compensate by listing your search vocabulary explicitly in the scoping memo and
  asking the user to flag missing synonyms before you start the investigation
  phase.
- 8-15 annotations x 100-200 words each = a lot of context. If the run is heading
  toward composition with the abstracts still loaded, summarize each into a single
  bullet line before writing the synthesis.
