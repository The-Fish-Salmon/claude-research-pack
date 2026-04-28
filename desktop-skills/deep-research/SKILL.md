---
name: deep-research
description: Multi-mode academic research pipeline for Claude Desktop — runs literature discovery, synthesis, fact-checking, or systematic review against your literature MCP servers and lands findings in your Obsidian vault. Use whenever the user asks to "research", "look into the literature on", "find papers on", "fact-check", "do a lit review", "do a systematic review", or asks an open-ended scholarly question. Adapted from Imbad0202/academic-research-skills (CC-BY-NC 4.0). DESKTOP-LITE variant: runs single-pass without parallel sub-agents — see references/desktop_limitations.md for what that means for hallucination-resistance.
---

# Deep Research (Desktop-lite)

This is the Claude Desktop variant of the deep-research skill. The Code variant in
`skills/deep-research/` spawns parallel context-isolated sub-agents (investigators,
synthesizer, devils-advocate). **Claude Desktop has no `Agent` tool**, so this
variant runs everything serially in one conversation context.

Read [references/desktop_limitations.md](references/desktop_limitations.md) once at the
start of any run — it explains what integrity gates are weakened and how to
compensate. The Iron Rules in [references/iron_rules.md](references/iron_rules.md) still
apply in full.

## When to use which mode

| User intent | Mode | Output length |
|---|---|---|
| Vague topic, user is exploring | `socratic` | dialogue only |
| "Give me a quick summary of X" | `quick` | 500–1,500 words |
| "Write me a research report on X" | `full` | 3,000–8,000 words |
| "Find me papers on X" / "annotated bibliography" | `lit-review` | 1,500–4,000 words |
| "Is this claim true? / Does this paper exist?" | `fact-check` | 300–800 words |
| "Review this draft / argument" | `review` | varies |
| "PRISMA / systematic review of X" | `systematic-review` | 5,000–15,000 words |

If the user did not specify, infer from their phrasing. Default to `socratic` when the
question is too broad to research without scoping.

## How to invoke (Desktop)

There are no slash commands in Desktop. Recognize the skill from the user's free text.
If the user names a mode (e.g. "do a lit review on…"), use it directly. Otherwise
infer; if unclear, enter `socratic` first.

## Iron Rules (apply to every mode)

1. **No claim without a citation that resolves through Semantic Scholar, OpenAlex, arXiv, or a publisher DOI.** If a claim cannot be cited, mark it `[UNVERIFIED]` and either drop it or escalate to the user — never invent a citation.
2. **Self-critique at three checkpoints** (Devil's Advocate). Because there is no
   independent sub-agent on Desktop, you write an explicit banner and critique your
   own prior output:
   ```
   === DEVIL'S ADVOCATE CHECKPOINT N ===
   ```
   Then run the checks below, write a verdict (`BLOCK | CAVEAT | CONCEDE`), and
   resume. Do NOT skip these — they are the only integrity gate left.
3. **Ethics halt** — if the topic crosses into weapons synthesis, targeted
   harassment, mass-surveillance evasion for a specific operation, or detailed
   offensive cyber against a specific target, stop and decline. Defensive security,
   CTF, and policy/historical analysis are fine.
4. **Socratic mode never gives direct answers** — only guiding questions.
5. **Vault writes go to `00_Inbox/`, not `30_Literature/`.** The user curates.
6. **Capture every paper you actually read.** Whenever you fetch and read a paper's
   full text (not just the abstract), invoke the `paper-capture` skill so it lands
   in `30_Literature/`. This is how the corpus accumulates across projects.

## Phases (every mode runs through these in order, single context)

1. **Scoping** — sharpen the research question, choose the mode, write a methodology blueprint.
2. **Investigation** — search the MCP servers in priority order, download and read promising papers.
3. **Analysis** — synthesize across sources, build a claim/evidence table.
4. **Devil's Advocate Checkpoint 1** (after scoping/early synthesis): is the question well-formed and answerable from the literature?
5. **Composition** — draft the deliverable in the mode-appropriate format.
6. **Devil's Advocate Checkpoint 2** (after composition): does the draft overstate what the cited sources actually claim?
7. **Devil's Advocate Checkpoint 3** (final): are there obvious counter-arguments / contradicting papers we ignored?
8. **Hand-off** — write to vault `00_Inbox/research-{slug}-{YYYY-MM-DD}.md` via the `obsidian` MCP.

Skip phases that don't apply (e.g. `fact-check` skips composition; `socratic` runs only Phase 1).

## MCP server priority order

The investigation phase MUST try these in order and stop at the first success:

1. `semantic-scholar` — best for metadata, paper resolution, citation graphs, abstract preview. Tools: `mcp__semantic-scholar__search_semantic_scholar`, `mcp__semantic-scholar__get_semantic_scholar_paper_details`, `mcp__semantic-scholar__get_semantic_scholar_citations_and_references`.
2. `paper-search` — multi-source unified search. Tools: `mcp__paper-search__search_arxiv`, `search_biorxiv`, `search_medrxiv`, `search_pubmed`, `search_google_scholar`, plus `read_*_paper`.
3. `arxiv` — when the topic is in physics/CS/quant-bio. Tools: `mcp__arxiv__search_papers`, `get_abstract`, `read_paper`, `download_paper`.
4. `university-paper-access` — institutional download path; first choice for full-text PDF. Tools: `mcp__university-paper-access__search_papers`, `download_paper`.
5. `paper-mcp` — secondary metadata path. Tools: `mcp__paper-mcp__paper_get_metadata`, `paper_get_fulltext`.
6. `scihub` — last-resort PDF when institutional access fails. Tools: `mcp__scihub__search_scihub_by_doi`, `download_scihub_pdf`.

Always prefer **abstract-level reasoning** before downloading PDFs. Only download a
paper when it will actually be cited.

## Mode-specific instructions

Read the mode file before starting:

- [modes/full.md](modes/full.md)
- [modes/quick.md](modes/quick.md)
- [modes/lit-review.md](modes/lit-review.md)
- [modes/fact-check.md](modes/fact-check.md)
- [modes/socratic.md](modes/socratic.md)
- [modes/systematic-review.md](modes/systematic-review.md)
- [modes/review.md](modes/review.md)

## Templates

- [templates/report_full.md](templates/report_full.md)
- [templates/report_lit_review.md](templates/report_lit_review.md)
- [templates/prisma_flow.md](templates/prisma_flow.md)
- [templates/claim_evidence_table.md](templates/claim_evidence_table.md)

## Citation format

APA 7.0 in-text and reference list. For each cited source:

- DOI mandatory if it exists; arXiv id otherwise; URL only if neither.
- Mark provenance: `[SS]` Semantic Scholar / `[XV]` arXiv / `[UPA]` university-access / `[SH]` Sci-Hub. The trail is what makes the integrity gate falsifiable.

## Hand-off note format

The vault note dropped in `00_Inbox/` MUST include:

```yaml
---
type: research-output
mode: {mode}
topic: {topic}
date: {YYYY-MM-DD}
status: draft           # draft → reviewed → promoted
papers_captured: [{citekey1}, {citekey2}, ...]
---
```

followed by the body and a final `## Provenance` section listing every MCP call made
and every paper downloaded. Reviewers (the user in three months, or a collaborator)
should be able to reproduce the search.

## Devil's Advocate self-critique protocol (Desktop-specific)

At each checkpoint, write the banner then run all three checks below in order. Do not
collapse them. Output the verdict line at the end.

```
=== DEVIL'S ADVOCATE CHECKPOINT N ===

1. Citation discipline check
   - Pick three random claims from the prior output. For each, identify the citation
     and verify (against your earlier MCP results) that the source says what the
     claim implies. If any fails, log a `BLOCK`.

2. Strongest counter-evidence check
   - What would the strongest paper that disagrees with the deliverable look like?
     Did you search for it explicitly? If no, search now (one MCP call) before
     resuming.

3. Overstatement check
   - Does the prior output use causal language ("X causes Y") where the cited
     evidence is correlational? Does it generalize ("ion-gated transistors are…")
     where the evidence covers only one material system? If yes, log a `CAVEAT` and
     hedge the prose.

Verdict: BLOCK | CAVEAT | CONCEDE
=== END CHECKPOINT N ===
```

If `BLOCK`, fix the issue before resuming the next phase. If `CAVEAT`, hedge the
prose and continue. If `CONCEDE`, continue.

The concession threshold from the Code variant still applies: do not manufacture
concerns to look useful. After one honest pass, if you can't find a substantive
issue, concede.
