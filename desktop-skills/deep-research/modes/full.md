# Mode: `full` (Desktop-lite)

A complete research report, 3,000–8,000 words, suitable as the foundation of a
literature section. Use [templates/report_full.md](../templates/report_full.md) as
the skeleton.

## Workflow (single context, sequential)

1. **Scoping** — write a scoping memo (refined question, 3–6 sub-questions,
   methodology blueprint, search seeds). 300–800 words.
2. **Investigation** — work through the sub-questions one at a time. For each:
   - 3–5 MCP searches across the priority order (semantic-scholar → paper-search →
     arxiv → university-paper-access → paper-mcp → scihub).
   - Read abstracts; identify 4–10 must-read papers per sub-question.
   - Download full text only for papers that will be cited.
   - For each downloaded paper, invoke the `paper-capture` skill so it lands in
     `30_Literature/`.
   - Write a short findings memo for the sub-question.
   Repeat for each sub-question. **Watch token budget** — if context is filling up,
   summarize earlier sub-questions before moving on.
3. **Analysis** — build a single claim/evidence table across all sub-questions
   ([templates/claim_evidence_table.md](../templates/claim_evidence_table.md)).
   Note bias / methodological weaknesses inline (no separate auditor on Desktop).
4. **Devil's Advocate Checkpoint 1** — write the banner, run the protocol from
   SKILL.md. Verdict: BLOCK / CAVEAT / CONCEDE. If BLOCK, fix and re-run.
5. **Composition** — draft the report against `report_full.md`. APA 7.0.
6. **Devil's Advocate Checkpoint 2** — re-run the protocol against the draft. Focus
   on overstatement / causal language. Hedge prose if CAVEAT.
7. **Devil's Advocate Checkpoint 3** — final pass. Strongest counter-argument check.
8. **Hand-off** — write to `00_Inbox/research-{slug}-{date}.md` via the `obsidian`
   MCP. List every paper captured in the frontmatter `papers_captured` field.

## Required sections in the deliverable

- Executive summary (200–400 words)
- Background & question
- Methods (search strategy, databases, inclusion/exclusion)
- Findings (organized by sub-question)
- Synthesis (cross-cutting patterns)
- Limitations & open questions
- References (APA 7.0)
- Provenance (MCP calls + downloaded papers)
- Where I stopped / Next steps (Desktop has no Stop hook — write this yourself)

## Length budget

Aim for 5,000 words ± 30%. If you go over 8,000, you're padding — cut.

## Desktop-specific cautions

- The Code variant fans out across 3 parallel investigators. Sequential investigation
  here is slower and risks terminology-cluster blind spots. Mitigate by varying the
  search vocabulary explicitly (e.g. "ion-gated transistor" then "EDLT" then "EGT")
  for each sub-question.
- Context can fill before you reach composition. If you suspect this, summarize
  Phase 2 findings into a compact bullet list before starting Phase 3.
