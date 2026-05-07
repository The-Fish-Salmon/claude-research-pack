---
name: deep-research
description: Citation-disciplined literature pipeline backed by paper MCP servers (semantic-scholar, arxiv, paper-search). Use for /research, lit review, fact-check, systematic review.
---

# Deep Research

This skill orchestrates a multi-phase academic research workflow. It is **citation-disciplined**: every claim in the final output must resolve to a real source reachable through one of the configured paper MCP servers. Hallucinated DOIs are a failure mode, not a typo -- they get caught and rejected here, not after the fact.

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

If the user did not specify, infer from their phrasing. Default to `socratic` when the question is too broad to research without scoping. See [references/mode_selection.md](references/mode_selection.md).

## How to invoke

User can pass `--mode {name}` and a topic via slash command (`/research --mode lit-review "ion-gated transistors for reservoir computing"`) or by free text. Read the args; if none, infer from the prompt.

## Iron Rules (apply to every mode)

1. **No claim without a citation that resolves through Semantic Scholar, OpenAlex, arXiv, or a publisher DOI.** If a claim cannot be cited, mark it as `[UNVERIFIED]` and either drop it or escalate it to the user -- never invent a citation.
2. **The `devils-advocate` agent runs at three checkpoints**: after scoping, after synthesis, after composition. It can block progression if claims are weak or sources gray-zone. See [agents/devils-advocate.md](agents/devils-advocate.md).
3. **The `ethics` agent can halt delivery** when the topic crosses into harm-enablement territory (weapons synthesis, targeted harassment, etc.). See [agents/ethics.md](agents/ethics.md).
4. **Socratic mode never gives direct answers** -- only guiding questions. If the user demands an answer, exit Socratic mode explicitly and re-enter via a different mode.
5. **Vault writes go to `00_Inbox/`, not `30_Literature/`.** The user curates and promotes. This matches the user's `feedback_obsidian_writes.md` rule.
6. **Capture every paper you actually read.** Whenever an agent fetches and reads a paper's full text (not just the abstract), call the `paper-capture` skill so it lands in `30_Literature/`. Do not skip this -- the whole point of the pack is that papers consumed during research are reusable on the next project.

## Phases (every mode runs through these in order)

1. **Scoping** -- sharpen the research question, choose the mode, write a methodology blueprint.
2. **Scope confirmation** (mandatory pause; see Scope Confirmation Protocol below). Skip ONLY in `quick` and `fact-check` modes.
3. **Investigation** -- search the MCP servers in priority order (see below), download and read promising papers. Spawn the parallel investigator sub-agents listed under "Spawning sub-agents".
4. **Analysis** -- synthesize across sources, run risk-of-bias on each, build a claim/evidence table.
5. **Composition** -- draft the deliverable in the mode-appropriate format.
6. **Review** -- editorial pass + ethics check + devil's advocate final pass.
7. **Citation pre-flight** (mandatory; see Citation Pre-flight Protocol below).
8. **Hand-off** -- write to vault `00_Inbox/research-{slug}-{YYYY-MM-DD}.md` via the `obsidian` MCP.

Skip phases that don't apply (e.g. `fact-check` skips composition).

## Scope Confirmation Protocol (mandatory pause after Phase 1)

In every mode EXCEPT `quick` and `fact-check`, after Phase 1 (Scoping) you MUST present the scope back to the user and wait for confirmation. Do not start Phase 3 (Investigation) until the user replies.

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

If the user's original request was genuinely vague (no topic, no scope at all), don't synthesize a scope -- drop into `socratic` mode instead.

## Citation Pre-flight Protocol (mandatory before Phase 8 Hand-off)

After Composition (Phase 5) and the Review pass (Phase 6), and before writing the final note to the vault:

1. Walk every in-text citation in the draft. Extract the DOI / arXiv id / Semantic Scholar paperId for each.
2. For each citation, call `mcp__semantic-scholar__get_semantic_scholar_paper_details` (or `mcp__paper-mcp__paper_get_metadata` as fallback).
3. Compare the returned title/authors against what the draft claims:
   - **Confirmed**: title + first-author both match -> mark `[verified]` internally.
   - **Mismatch**: title doesn't match -- the draft cited the wrong DOI. Either fix the DOI (re-search Semantic Scholar) or replace the in-text reference with `[UNVERIFIED -- DOI mismatch]`.
   - **404 / not-found**: re-resolve via title-author-year search; if that also fails, replace with `[UNVERIFIED -- could not re-confirm]`.
4. Surface the count of unverified to the user in the final delivery line: `Captured N citations; M re-verified, K flagged unverified.`
5. If K > 0, list each unverified citation in a `## Unverified Citations` section at the bottom of the draft, with what was attempted.

Pre-flight is the integrity gate that catches the rare case where a sub-step of the pipeline (or the model itself) introduced a fabricated or mistyped DOI.

## MCP server priority order

The investigator MUST try these in order and stop at the first success:

1. `semantic-scholar` -- best for metadata, paper resolution, citation graphs, abstract preview.
2. `paper-search` -- multi-source unified search (arXiv, bioRxiv, PubMed, medRxiv, Google Scholar).
3. `arxiv` -- when the topic is in physics/CS/quant-bio.
4. `university-paper-access` -- institutional download path; first choice for full-text PDF.
5. `paper-mcp` -- secondary metadata path.
6. `scihub` -- last-resort PDF when institutional access fails. Note legal/network limitations.

Always prefer **abstract-level reasoning** before downloading PDFs. Only download a paper when an agent has decided it actually needs the full text.

## Spawning sub-agents

Use the `Agent` tool with `subagent_type=Explore` for searches and `subagent_type=general-purpose` for synthesis/composition. Cap at 3 parallel agents. Each agent prompt lives in [agents/](agents/) -- load the file with `Read` and pass its body as the agent prompt, prepended with the specific topic.

For a `full` run, the recommended spawn pattern is:

- **Phase 1**: 1x `scoping` agent (sequential).
- **Phase 2**: 3x `investigator` agents in parallel -- one per top-level subtopic. Each may make several MCP calls.
- **Phase 3**: 1x `synthesizer` + 1x `bias-auditor` in parallel, sharing the Phase 2 output.
- **Phase 3.5**: 1x `devils-advocate` (checkpoint 1).
- **Phase 4**: 1x `composer` (sequential, large context).
- **Phase 5**: 1x `editor` + 1x `ethics` + 1x `devils-advocate` (checkpoint 2 & 3) in parallel.

For `quick`, run scoping -> 1x investigator -> 1x composer -> 1x devils-advocate. Skip bias auditor.

For `socratic`, never spawn agents. Stay in the main loop and ask questions until the user has a researchable question, then propose a mode.

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

Use these as the skeleton for the deliverable:

- [templates/report_full.md](templates/report_full.md)
- [templates/report_lit_review.md](templates/report_lit_review.md)
- [templates/prisma_flow.md](templates/prisma_flow.md)
- [templates/claim_evidence_table.md](templates/claim_evidence_table.md)

## Citation format

APA 7.0 in-text and reference list. For each cited source:

- DOI mandatory if it exists; arXiv id otherwise; URL only if neither.
- Mark provenance: `[SS]` Semantic Scholar / `[XV]` arXiv / `[UPA]` university-access / `[SH]` Sci-Hub. This trail is what makes the integrity gate falsifiable.

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

followed by the body and a final `## Provenance` section listing every MCP call made and every paper downloaded. Reviewers (you in three months, or a collaborator) should be able to reproduce the search.

## Iron Rule reference

Read [references/iron_rules.md](references/iron_rules.md) at the start of every run. If you're not sure whether something violates a rule, stop and ask the user.
