# Mode: `systematic-review`

PRISMA 2020-compliant systematic review. 5,000-15,000 words. Heavyweight -- only choose this when the user explicitly asks for a systematic review, or for a review that will be cited as one.

## Workflow

1. **Protocol declaration** (sequential, with user). Output a registered-protocol-style document covering:
   - PICO(S) elements (population, intervention, comparator, outcome, study design).
   - Search strategy: exact query strings per database.
   - Inclusion / exclusion criteria.
   - Data extraction fields.
   - Risk-of-bias tool (e.g., RoB 2 for RCTs, ROBINS-I for non-randomized, QUADAS-2 for diagnostic).
   - Synthesis plan (narrative? meta-analysis? if so, model + heterogeneity threshold).
   The user must approve the protocol before phase 2.
2. **Search & retrieval** -- 3x `investigator.md` in parallel. Use `paper-search` and `semantic-scholar` as primary; `arxiv` only if topic is in scope; `university-paper-access` for full text.
3. **PRISMA flow** -- track at every stage:
   - Records identified (per database)
   - Records after dedup
   - Records screened
   - Records excluded at title/abstract (with reason counts)
   - Full texts assessed
   - Full texts excluded (with reason counts)
   - Studies included
   Render as the [templates/prisma_flow.md](../templates/prisma_flow.md) ASCII diagram, plus a numerical table.
4. **Capture** -- every included full-text -> `paper-capture`. Tag the vault note with `systematic-review-{slug}` so the corpus is reproducible.
5. **Risk of bias** -- `bias-auditor.md` per included study. Output: bias domain table.
6. **Synthesis** -- `synthesizer.md`. Narrative synthesis at minimum; if the user asked for meta-analysis and the heterogeneity is acceptable, compute or commission the pooled effect.
7. **Devil's Advocate** -- three checkpoints. SR runs are the most likely to overstate; this is where it earns its keep.
8. **Composition** -- `composer.md` against [templates/report_full.md](../templates/report_full.md) extended with PRISMA sections.
9. **Editorial + ethics** -- final review.
10. **Hand-off** -- `00_Inbox/SR-{slug}-{date}.md`. Frontmatter must include the protocol hash and the full citekey list.

## Required sections (PRISMA 2020 alignment)

- Title, abstract (structured)
- Introduction (rationale + objectives)
- Methods (protocol, eligibility, sources, search, selection, extraction, RoB, synthesis)
- Results (study selection w/ PRISMA flow; study characteristics; RoB results; synthesis of results; certainty of evidence)
- Discussion (interpretation, limitations, implications)
- Other (registration, support, competing interests, data availability)

## When NOT to use this mode

- One-off "what's the state of the field" questions -> `lit-review` is the right answer.
- Questions where peer-reviewed RCTs don't exist -> SR machinery doesn't fit; use `lit-review`.
- Time-pressured asks ("by tomorrow") -> SR is a multi-day commitment in good faith. Push back.
