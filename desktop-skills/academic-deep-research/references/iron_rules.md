# Iron Rules

Adapted from upstream `Imbad0202/academic-research-skills/deep-research`. These rules
are non-negotiable across every mode. **Identical to the Code variant** -- Desktop
keeps the same rules even though some integrity gates are weaker (see
`desktop_limitations.md`).

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

Three mandatory checkpoints. On Desktop, these are **self-critique** steps in the
same context (no parallel sub-agent). You must still write the banner and run the
checks -- collapsing them defeats the only remaining integrity gate. See SKILL.md for
the protocol.

- **Checkpoint 1** -- after scoping. Question: "Is the research question well-formed and answerable from the literature, or is it really an opinion/empirical question?"
- **Checkpoint 2** -- after synthesis. Question: "Are the cross-source patterns real, or are we cherry-picking? What does the strongest counter-evidence look like?"
- **Checkpoint 3** -- after composition. Question: "Does the draft overstate what the cited sources actually claim?"

The agent must offer a concession threshold: if it cannot find a substantive issue
after one honest pass, it concedes. Do not let it manufacture concerns.

## 4. Ethics halt

Halt delivery (not just block -- full stop) when the topic crosses into:

- Synthesis routes for weapons (chemical, biological, radiological, nuclear).
- Targeted harassment (deanonymization of specific individuals, doxxing material).
- Mass surveillance evasion **for a specific operation** (general academic surveys are fine).
- Detailed offensive cyber techniques against a specific target.

Defensive security research, CTF write-ups, and policy/historical analysis of these topics are **not** halt conditions.

## 5. Socratic discipline

In Socratic mode, you do not give the user answers -- you give them questions that
sharpen theirs. The user can break out at any time by asking explicitly for a
different mode. Never sneak an answer into a question.

## 6. Vault hygiene

- Drafts always land in `00_Inbox/`. Never write directly to `30_Literature/`, `10_Projects/`, or any curated folder. The user promotes notes manually.
- Use the `obsidian` MCP for vault writes when available; fall back to filesystem only if MCP is offline.
- Never overwrite an existing vault note silently. If a path collides, append a `-2`, `-3` suffix.

## 7. Session continuity

Long research runs span sessions. At the end of a run, ensure:

- The Inbox draft note exists and is complete.
- Every paper that was downloaded has a `30_Literature/{citekey}.md` note via the `paper-capture` skill.
- A clear "Where I stopped / Next steps" section so the next session can pick up.
  (Desktop has no Stop hook to persist todos automatically; you must write them into
  the Inbox draft yourself.)
