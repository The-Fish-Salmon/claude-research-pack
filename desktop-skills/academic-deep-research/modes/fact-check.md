# Mode: `fact-check` (Desktop-lite)

Verify one or a few specific claims. 300-800 words total. Narrow scope -- resist the
urge to go broad.

## Workflow (single context, sequential)

1. **Restate the claim(s)** in one sentence each. Confirm with the user if any
   wording is ambiguous.
2. **Investigation** -- for each claim:
   - Search Semantic Scholar for the original source.
   - If the source is named, verify the source actually says what's claimed
     (download abstract; download full text if abstract is ambiguous).
   - Search for direct contradicting evidence.
   - Invoke `paper-capture` for any full text you actually read.
3. **Verdict per claim** -- one of:
   - `SUPPORTED` -- primary source confirms, no strong contradiction.
   - `PARTIALLY SUPPORTED` -- true under conditions; original wording overgeneralizes.
   - `CONTRADICTED` -- primary source says otherwise OR strong contradicting evidence.
   - `UNVERIFIABLE` -- claimed source does not exist OR no evidence either way.
4. **Devil's Advocate** -- quick pass: "did you find the strongest counter-evidence,
   not just the easiest?" Run the SKILL.md protocol, collapsed if the deliverable is
   short.
5. **Hand-off** -- write `00_Inbox/factcheck-{slug}-{date}.md`.

## Required sections

For each claim:
- Claim (verbatim)
- Verdict (one of the four)
- Primary source(s) consulted, with provenance tag
- One-paragraph reasoning
- Counter-evidence considered

## Skip

- No long synthesis. No separate bias auditor pass. No editor pass. Composer is
  implicit.

## Hallucinated-source detection (most common failure)

The user's claim cites a paper that does not exist. If Semantic Scholar + arXiv +
Crossref all return nothing for a stated DOI/title/author combo, verdict is
`UNVERIFIABLE` and you flag it explicitly:

> "The cited source could not be located in any major index -- this may be a
> hallucinated reference."

This is the most valuable thing fact-check mode does. Do it religiously.

## Desktop-specific cautions

- Fact-check is the mode where Desktop's lack of independent devil's advocate hurts
  least: the verdicts are mechanical (does the source exist? does it say what's
  claimed?) and easy to self-check. This mode is safe to use on Desktop without
  significant degradation.
