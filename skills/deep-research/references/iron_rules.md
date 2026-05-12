# Iron Rules

Adapted from upstream `Imbad0202/academic-research-skills/deep-research`. These rules are non-negotiable across every mode.

## 1. Citation discipline

- Every claim of fact, every quoted statistic, every "researchers have shown" -> must carry a citation that resolves through one of: Semantic Scholar, arXiv, OpenAlex, Crossref/DOI.
- A citation that you cannot independently verify (no DOI, no arXiv id, no resolvable Semantic Scholar paper id) is **not a citation** -- it is a hallucination. Drop the claim.
- When in doubt, mark the claim `[UNVERIFIED]` and report it to the user. Better honest than wrong.

## 2. Source quality tiers

| Tier | Examples | OK to cite? |
|---|---|---|
| A | Peer-reviewed journals, top conference proceedings | yes |
| B | Pre-prints (arXiv, bioRxiv) by groups with prior peer-reviewed work | yes, label as preprint |
| C | Pre-prints from unknown groups, white papers, technical reports | yes for context, never load-bearing |
| D | Blog posts, news articles, Wikipedia, LLM transcripts | gray-zone -- only as primary-source pointers |
| E | Predatory journals, fabricated venues, retracted papers | **reject** |

Detect tier E aggressively. Cross-reference Retraction Watch when a paper is central to a conclusion.

## 3. Devil's Advocate checkpoints

Three mandatory checkpoints. The Devil's Advocate agent has block authority -- when it raises a critical issue, you cannot proceed until either (a) you fix the issue or (b) the user explicitly waives.

- **Checkpoint 1** -- after scoping. Question: "Is the research question well-formed and answerable from the literature, or is it really an opinion/empirical question?"
- **Checkpoint 2** -- after synthesis. Question: "Are the cross-source patterns real, or are we cherry-picking? What does the strongest counter-evidence look like?"
- **Checkpoint 3** -- after composition. Question: "Does the draft overstate what the cited sources actually claim?"

The agent must offer a concession threshold: if it cannot find a substantive issue after one honest pass, it concedes. Do not let it manufacture concerns.

## 4. Ethics halt

The Ethics agent halts delivery (not just blocks -- full stop) when the topic crosses into:

- Synthesis routes for weapons (chemical, biological, radiological, nuclear).
- Targeted harassment (deanonymization of specific individuals, doxxing material).
- Mass surveillance evasion **for a specific operation** (general academic surveys are fine).
- Detailed offensive cyber techniques against a specific target.

Defensive security research, CTF write-ups, and policy/historical analysis of these topics are **not** halt conditions.

## 5. Socratic discipline

In Socratic mode, you do not give the user answers -- you give them questions that sharpen theirs. The user can break out at any time by asking explicitly for a different mode. Never sneak an answer into a question.

## 6. Vault hygiene

- Drafts always land in `00_Inbox/`. Never write directly to `30_Literature/`, `10_Projects/`, or any curated folder. The user promotes notes manually.
- Use the `obsidian` MCP for vault writes when available; fall back to filesystem only if MCP is offline.
- Never overwrite an existing vault note silently. If a path collides, append a `-2`, `-3` suffix.

## 7. Session continuity

Long research runs span sessions. At the end of a run, ensure:

- The Inbox draft note exists and is complete.
- Every paper that was downloaded has a `30_Literature/{citekey}.md` note via the `paper-capture` skill.
- The TodoWrite list reflects any unfinished follow-ups (the Stop hook will persist them).

## 8. Semantic Scholar budget

The Semantic Scholar Graph API is the single highest-quality citation source and the backbone of the citation-discipline gate. With an issued API key the default rate is **1 request per second, cumulative across all endpoints** (search, paper-details, citations, references, all share one bucket). Without a key the search endpoint is unreliable enough that the gate fails open. Treat S2 traffic as a budgeted resource:

- **Use S2 for resolution and pre-flight, not for discovery.** Run open-ended literature search through `paper-search` (arXiv / bioRxiv / medRxiv / PubMed / Google Scholar) and `arxiv`. Reserve S2 for: resolving a known DOI / arXiv id to canonical metadata, citation-graph traversal on a specific load-bearing paper, and the final citation pre-flight pass.
- **Serialize S2 calls across parallel sub-agents.** When multiple investigators are running concurrently, do NOT let each one fire S2 calls independently. The investigator agent prompt enforces this: each investigator must explicitly note "S2 call planned" in its findings and the spawning agent must space them at least 1.1 seconds apart. When in doubt, run a single S2-aware investigator sequentially rather than three in parallel.
- **A 429 from S2 is transient, not a not-found.** Retry with backoff (3 attempts, 2s/4s/8s). Only a clean 404 permits marking a citation `[UNVERIFIED]`.
- **Cap parallel investigator count at 2 when S2 is the primary metadata path.** The `full` mode default of 3 parallel investigators (see deep-research/SKILL.md "Spawning sub-agents") is too aggressive against a 1 RPS budget. Reduce to 2 unless the user has confirmed a higher rate limit or arxiv/paper-search are doing the heavy lifting.
- **Cache aggressively.** `paper-capture` writes every resolved paper to `30_Literature/{citekey}.md`. Before calling S2 for a paper's metadata, check whether the note already exists — same-DOI re-captures should hit the local cache, not the API.

If the user reports a different S2 rate limit (some institutional keys get 10 RPS), they can override these caps for that session.
