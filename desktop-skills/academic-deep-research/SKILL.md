---
name: academic-deep-research
description: Citation-disciplined literature pipeline backed by paper MCP servers (semantic-scholar, arxiv, paper-search). Use for lit review, fact-check, systematic review, scholarly research.
---

# Academic Deep Research (Desktop-lite)

This is the Claude Desktop variant of the deep-research skill. The Code variant in
`skills/deep-research/` spawns parallel context-isolated sub-agents (investigators,
synthesizer, devils-advocate). **Claude Desktop has no `Agent` tool**, so this
variant runs everything serially in one conversation context.

Read [references/desktop_limitations.md](references/desktop_limitations.md) once at the
start of any run -- it explains what integrity gates are weakened and how to
compensate. The Iron Rules in [references/iron_rules.md](references/iron_rules.md) still
apply in full.

## When to use which mode

| User intent | Mode | Output length |
|---|---|---|
| Vague topic, user is exploring | `socratic` | dialogue only |
| "Give me a quick summary of X" | `quick` | 500-1,500 words |
| "Write me a research report on X" | `full` | 3,000-8,000 words |
| "Find me papers on X" / "annotated bibliography" | `lit-review` | 1,500-4,000 words |
| "Is this claim true? / Does this paper exist?" | `fact-check` | 300-800 words |
| "Review this draft / argument" | `review` | varies |
| "PRISMA / systematic review of X" | `systematic-review` | 5,000-15,000 words |

If the user did not specify, infer from their phrasing. Default to `socratic` when the
question is too broad to research without scoping.

## How to invoke (Desktop)

There are no slash commands in Desktop. Recognize the skill from the user's free text.
If the user names a mode (e.g. "do a lit review on..."), use it directly. Otherwise
infer; if unclear, enter `socratic` first.

## Iron Rules (apply to every mode)

1. **No claim without a citation that resolves through Semantic Scholar, OpenAlex, arXiv, or a publisher DOI.** If a claim cannot be cited, mark it `[UNVERIFIED]` and either drop it or escalate to the user -- never invent a citation.
2. **Self-critique at three checkpoints** (Devil's Advocate). Because there is no
   independent sub-agent on Desktop, you write an explicit banner and critique your
   own prior output:
   ```
   === DEVIL'S ADVOCATE CHECKPOINT N ===
   ```
   Then run the checks below, write a verdict (`BLOCK | CAVEAT | CONCEDE`), and
   resume. Do NOT skip these -- they are the only integrity gate left.
3. **Ethics halt** -- if the topic crosses into weapons synthesis, targeted
   harassment, mass-surveillance evasion for a specific operation, or detailed
   offensive cyber against a specific target, stop and decline. Defensive security,
   CTF, and policy/historical analysis are fine.
4. **Socratic mode never gives direct answers** -- only guiding questions.
5. **Vault writes go to `00_Inbox/`, not `30_Literature/`.** The user curates.
6. **Capture every paper you actually read.** Whenever you fetch and read a paper's
   full text (not just the abstract), invoke the `paper-capture` skill so it lands
   in `30_Literature/`. This is how the corpus accumulates across projects.

## Phases (every mode runs through these in order, single context)

1. **Scoping** -- sharpen the research question, choose the mode, write a methodology blueprint.
2. **Scope confirmation** (mandatory pause; see Scope Confirmation Protocol below). Skip ONLY in `quick` and `fact-check` modes.
3. **Investigation** -- search the MCP servers in priority order, download and read promising papers.
4. **Analysis** -- synthesize across sources, build a claim/evidence table.
5. **Devil's Advocate Checkpoint 1** (after scoping/early synthesis): is the question well-formed and answerable from the literature?
6. **Composition** -- draft the deliverable in the mode-appropriate format.
7. **Devil's Advocate Checkpoint 2** (after composition): does the draft overstate what the cited sources actually claim?
8. **Devil's Advocate Checkpoint 3** (final): are there obvious counter-arguments / contradicting papers we ignored?
9. **Citation pre-flight** (mandatory; see Citation Pre-flight Protocol below).
10. **Hand-off** -- write to vault `00_Inbox/research-{slug}-{YYYY-MM-DD}.md` via the `obsidian` MCP.

Skip phases that don't apply (e.g. `fact-check` skips composition; `socratic` runs only Phase 1).

## Scope Confirmation Protocol (mandatory pause after Phase 1)

In every mode EXCEPT `quick` and `fact-check`, after Phase 1 (Scoping) you
MUST present the scope back to the user and wait for confirmation. Do not
start Phase 3 (Investigation) until the user replies.

Format:

```
=== SCOPE CONFIRMATION ===

Before I search, here's how I'm reading your request:
- Topic:        {one sentence}
- Year range:   {YYYY-YYYY or "open"}
- Languages:    {English / multilingual / etc.}
- Inclusions:   {peer-reviewed lab, preprints OK, ...}
- Exclusions:   {blog posts, retracted papers, ...}
- Depth:        {quick / lit-review / full / systematic-review / review}
- Time budget:  {e.g. 5-15 min for a quick run}

Reply 'go' to proceed, or correct any of the above. I'll wait.
```

If the user's original request was genuinely vague (no topic, no scope at
all), don't synthesize a scope -- drop into `socratic` mode instead and
ask one focused clarifier per turn.

## Citation Pre-flight Protocol (mandatory before Phase 10 Hand-off)

After Composition (Phase 6) and the three Devil's Advocate checkpoints,
before writing the final note to the vault:

1. Walk every in-text citation in the draft. Extract the DOI / arXiv id /
   Semantic Scholar paperId for each.
2. For each citation, call
   `mcp__semantic-scholar__get_semantic_scholar_paper_details` (or
   `mcp__paper-mcp__paper_get_metadata` as fallback). The call should
   return the paper title and authors.
3. Compare the returned title/authors against what the draft claims:
   - **Confirmed**: title + first-author both match. Mark `[verified]`
     internally.
   - **Mismatch**: title doesn't match -- the draft cited the wrong DOI.
     Either fix the DOI (re-search Semantic Scholar) or replace the
     in-text reference with `[UNVERIFIED -- DOI mismatch]`.
   - **404 / not-found**: re-resolve via title-author-year search; if
     that also fails, replace with `[UNVERIFIED -- could not re-confirm]`.
4. Surface the count of unverified to the user in the final delivery line:
   `Captured N citations; M re-verified, K flagged unverified.`
5. If K > 0, list each unverified citation in a `## Unverified Citations`
   section at the bottom of the draft, with what was attempted.

Pre-flight is the integrity gate that catches the rare case where a
sub-step of the pipeline (or the model itself) introduced a fabricated
or mistyped DOI. It's cheap (one MCP call per citation) and catches the
class of errors that Devil's Advocate misses.

## MCP server priority order

The investigation phase tries these in the order below. The order is biased
toward broad-source coverage and institutional full-text access -- arXiv is
**only authoritative for preprints** and is missing most journal-published
work (Nature, Science, ACS Nano, Adv. Materials, Applied Physics Letters,
most of EE/MatSci, biology, chemistry). Do NOT default to arXiv-only
searches.

For SEARCH (broad coverage):

1. `semantic-scholar` -- best for metadata, paper resolution, citation graphs, abstract preview. Spans all journals + preprints. Tools: `search_semantic_scholar`, `get_semantic_scholar_paper_details`, `get_semantic_scholar_citations_and_references`.
2. `paper-search` -- multi-source unified search. Casts the widest net for preprints AND PMC open-access journal papers. Tools: `search_arxiv`, `search_biorxiv`, `search_medrxiv`, `search_pubmed`, `search_google_scholar`, plus `read_*_paper`.
3. `paper-mcp` -- secondary metadata + DOI resolution path. Tools: `paper_get_metadata`, `paper_get_fulltext`.
4. `arxiv` -- only when the topic is **explicitly preprint-relevant** (recent CS / physics / quant-bio that hasn't been formally published yet, OR seminal preprints from those fields). Don't make arxiv the primary source for an applied-physics or experimental-biology topic -- you'll miss the journal corpus. Tools: `search_papers`, `get_abstract`, `read_paper`.

For FULL-TEXT DOWNLOAD (after a paper has been chosen):

5. `university-paper-access` -- institutional download path via Unpaywall + on-campus IP. **First choice for full-text PDF** of any journal paper. Tools: `search_papers`, `download_paper`.
6. `arxiv` (download_paper) -- for arXiv ids only.
7. `paper-search` (download_*) -- per-source download from bioRxiv/medRxiv/PubMed/PMC.
8. `scihub` -- last-resort PDF when institutional access fails. Tools: `search_scihub_by_doi`, `download_scihub_pdf`.

Always prefer **abstract-level reasoning** before downloading PDFs. Only
download a paper when it will actually be cited. Then capture it via the
`paper-capture` skill (Iron Rule 6).

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
status: draft           # draft -> reviewed -> promoted
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
     evidence is correlational? Does it generalize ("ion-gated transistors are...")
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
