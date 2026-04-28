# Mode: `full`

A complete research report, 3,000–8,000 words, suitable as the foundation of a literature section in a thesis or grant. Use [templates/report_full.md](../templates/report_full.md) as the skeleton.

## Workflow

1. **Scoping** — spawn `agents/scoping.md`. Output: refined question + 3–6 sub-questions + methodology blueprint.
2. **Investigation** — spawn 3 `agents/investigator.md` in parallel, one per cluster of sub-questions. Each agent:
   - Issues 3–8 MCP searches across the priority order.
   - Reads abstracts, identifies 5–15 must-read papers per cluster.
   - Downloads PDFs only for papers that will be cited (not every hit).
   - For each downloaded paper, calls the `paper-capture` skill so it lands in `30_Literature/`.
3. **Analysis** — spawn `agents/synthesizer.md` and `agents/bias-auditor.md` in parallel. Synthesizer builds a claim/evidence table ([templates/claim_evidence_table.md](../templates/claim_evidence_table.md)). Bias auditor flags methodological weaknesses per source.
4. **Devil's Advocate Checkpoint 1** — spawn `agents/devils-advocate.md`. May block.
5. **Composition** — spawn `agents/composer.md`. Drafts the report against the claim/evidence table. APA 7.0.
6. **Review** — spawn `agents/editor.md`, `agents/ethics.md`, `agents/devils-advocate.md` (Checkpoint 2 + 3) in parallel.
7. **Hand-off** — write to `00_Inbox/research-{slug}-{date}.md` via Obsidian MCP. List every paper captured in the frontmatter `papers_captured` field.

## Required sections in the deliverable

- Executive summary (200–400 words)
- Background & question
- Methods (search strategy, databases, inclusion/exclusion)
- Findings (organized by sub-question)
- Synthesis (cross-cutting patterns)
- Limitations & open questions
- References (APA 7.0)
- Provenance (MCP calls + downloaded papers)

## Length budget

Aim for 5,000 words ± 30%. If you go over 8,000, you're padding — cut.
