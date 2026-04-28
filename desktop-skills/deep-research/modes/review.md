# Mode: `review` (Desktop-lite)

Evaluate a draft document the user provides — a manuscript section, a literature
review, a grant aim, an argument essay. The output is editorial feedback, not a new
piece.

## Workflow (single context, sequential)

1. **Read the draft** in full. Identify the central claim(s).
2. **Extract every cited source** in the draft. Build a citation list.
3. **Investigation** — verify each citation:
   - Search Semantic Scholar for the source.
   - Confirm the source exists (DOI / arXiv / paper id resolves).
   - Fetch the abstract; if the draft cites a specific finding, confirm the
     abstract supports it. If ambiguous, download full text.
   - Invoke `paper-capture` for any full text you actually read.
4. **Bias audit** — does the draft cherry-pick? What major contradicting work isn't
   cited? (No separate bias-auditor agent on Desktop; do this inline.)
5. **Devil's Advocate** — strongest counter-argument the draft does not address.
   Run the SKILL.md protocol.
6. **Editorial pass** — clarity, structure, citation form, hedging accuracy.
7. **Hand-off** — `00_Inbox/review-{slug}-{date}.md`.

## Required sections

- Summary of the draft's argument (in your words, ≤200 words; user confirms accuracy)
- Citation audit:
  - Citations that check out
  - Citations that don't exist OR don't say what's claimed (each with the discrepancy)
- Missing-citations list (major works that should have been engaged with)
- Substantive critique:
  - Strongest counter-argument
  - Methodological concerns
  - Overstatement / hedging issues
- Editorial notes (clarity, structure)
- Provenance

## Tone

Be specific and useful, not adversarial. The goal is to make the draft stronger.
Cite the specific paragraph/page when raising an issue.

## Desktop-specific cautions

- The citation-existence check is mechanical and safe to do on Desktop.
- The "missing major works" check depends on your prior knowledge plus a few MCP
  searches; it's harder to catch blind spots without an independent investigator.
  Be explicit about your confidence: "I found these 3 missing works; the field may
  have more I haven't surfaced."
