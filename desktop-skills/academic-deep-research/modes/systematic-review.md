# Mode: `systematic-review` (Desktop-lite)

PRISMA 2020-compliant systematic review. 5,000-15,000 words. Heavyweight -- only
choose this when the user explicitly asks for a systematic review, or for a review
that will be cited as one.

## ! Strong recommendation: use Code variant for this mode

Systematic reviews are exactly where the Code variant's parallel investigators and
independent devil's advocate earn their keep. On Desktop the integrity gates are
weaker (see [references/desktop_limitations.md](../references/desktop_limitations.md))
and the context-bloat risk is highest.

**If the SR will be cited in a publication, push the user toward the Code path
(Path A or B in INSTALL_WINDOWS.md).** Use Desktop only for exploratory
"systematic-style" reviews that won't be published as such.

## Workflow (single context, sequential -- proceed only with user awareness)

1. **Protocol declaration** (sequential, with user). Output a registered-protocol-
   style document covering:
   - PICO(S) elements (population, intervention, comparator, outcome, study design).
   - Search strategy: exact query strings per database.
   - Inclusion / exclusion criteria.
   - Data extraction fields.
   - Risk-of-bias tool (e.g., RoB 2 for RCTs, ROBINS-I for non-randomized,
     QUADAS-2 for diagnostic).
   - Synthesis plan (narrative? meta-analysis? if so, model + heterogeneity
     threshold).
   The user MUST approve the protocol before phase 2.
2. **Search & retrieval** -- work through databases sequentially. Use `paper-search`
   and `semantic-scholar` as primary; `arxiv` only if topic is in scope;
   `university-paper-access` for full text.
3. **PRISMA flow** -- track at every stage:
   - Records identified (per database)
   - Records after dedup
   - Records screened
   - Records excluded at title/abstract (with reason counts)
   - Full texts assessed
   - Full texts excluded (with reason counts)
   - Studies included
   Render as the [templates/prisma_flow.md](../templates/prisma_flow.md) ASCII
   diagram, plus a numerical table.
4. **Capture** -- every included full-text -> `paper-capture`. Tag the vault note
   with `systematic-review-{slug}` so the corpus is reproducible.
5. **Risk of bias** -- per included study, write a row in a bias-domain table.
6. **Synthesis** -- narrative synthesis at minimum; if the user asked for
   meta-analysis and the heterogeneity is acceptable, compute or commission the
   pooled effect.
7. **Devil's Advocate Checkpoints 1, 2, 3** -- DO NOT collapse. Run all three from
   the SKILL.md protocol. SR runs are the most likely to overstate; the gates are
   already weaker on Desktop, so do not weaken them further by skipping.
8. **Composition** -- against [templates/report_full.md](../templates/report_full.md)
   extended with PRISMA sections.
9. **Hand-off** -- `00_Inbox/SR-{slug}-{date}.md`. Frontmatter must include the
   protocol hash and the full citekey list.

## Required sections (PRISMA 2020 alignment)

- Title, abstract (structured)
- Introduction (rationale + objectives)
- Methods (protocol, eligibility, sources, search, selection, extraction, RoB,
  synthesis)
- Results (study selection w/ PRISMA flow; study characteristics; RoB results;
  synthesis of results; certainty of evidence)
- Discussion (interpretation, limitations, implications)
- Other (registration, support, competing interests, data availability)

## When NOT to use this mode

- One-off "what's the state of the field" questions -> `lit-review` is the right
  answer.
- Questions where peer-reviewed RCTs don't exist -> SR machinery doesn't fit; use
  `lit-review`.
- Time-pressured asks ("by tomorrow") -> SR is a multi-day commitment in good faith.
  Push back.
- Anything that will be peer-reviewed or cited as a formal SR -> use the Code variant.

## Desktop-specific cautions

- **Context exhaustion is highly likely.** A SR with 30+ studies, full abstracts
  loaded, plus the bias table, plus the synthesis -- easily exceeds Desktop's
  practical token budget. Plan to break the work across multiple chats:
  - Chat 1: Protocol declaration + search & retrieval.
  - Chat 2: Triage to included set (using citekey list from Chat 1's Inbox draft).
  - Chat 3: Risk of bias + synthesis.
  - Chat 4: Composition + checkpoints + hand-off.
  Each chat picks up from the prior chat's `00_Inbox/SR-{slug}-{date}.md` draft.
