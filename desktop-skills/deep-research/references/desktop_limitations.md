# Desktop-lite limitations: what's degraded and how to compensate

Honest writeup of what the Desktop variant of `deep-research` cannot do compared to
the Code variant, so you (the model) and the user know what trade-offs you are
making. Read this once at the start of any non-trivial run.

## What's the same

- **Iron Rules** — all 7 rules apply identically. No claim without citation, no
  fabricated DOIs, vault writes go to `00_Inbox/`, etc.
- **MCP servers** — all 7 are wired up the same way (semantic-scholar, paper-search,
  arxiv, university-paper-access, paper-mcp, scihub, obsidian).
- **Modes** — same 7 modes (full / quick / lit-review / fact-check / socratic /
  systematic-review / review).
- **Templates** — identical skeletons for the deliverables.
- **`paper-capture` skill** — identical, no Agent dependency. Papers read during
  research still accumulate in `30_Literature/`.

## What's degraded

### 1. No parallel investigation

The Code variant spawns 3 `investigator` sub-agents in parallel for `full` and
`systematic-review` runs. Each agent runs in **isolated context** — their search
trails, false starts, and dead-end abstracts don't pollute the synthesizer's window.

Desktop runs investigation sequentially in one context. Practical effects:

- **Slower** — searches run one after another, not in parallel.
- **Context bloat** — abstracts and search results accumulate; for large runs you
  may hit token limits before composition.
- **No diversity-of-search** — one agent searching three angles will tend to
  converge faster on a search vocabulary than three independent agents would. This
  can miss papers in adjacent terminology clusters.

**Mitigation:** Drop the long-list size. Where the Code variant's `lit-review` mode
collects 15–30 candidates, target 10–20 on Desktop. Where `full` uses 5–15 papers
per sub-question across 3 sub-questions, target 4–10 per sub-question across 2
sub-questions on Desktop. Be explicit with the user about what you're cutting.

### 2. No independent devil's advocate

The Code variant's devil's advocate runs in a fresh context — it has not seen the
synthesizer's reasoning, only its output. That independence is what makes its
critique useful: it can't be talked into agreeing with you because it hasn't been
talking with you.

On Desktop, the devil's advocate is **the same model in the same context** that
just produced the deliverable. It will systematically miss the same blind spots. To
partially compensate, the SKILL.md devil's advocate protocol forces three
mechanical checks (citation random sample, counter-evidence search, overstatement
language pass) rather than a freeform critique. Mechanical checks are harder to
talk yourself out of than impressionistic ones.

**Mitigation:** Run the protocol in the SKILL.md verbatim. Do not collapse the
three checks into one paragraph. If you find yourself writing "this looks good" at
checkpoint 2 without having actually run a counter-evidence search, you are
hallucinating the gate.

### 3. No bias-auditor / ethics agent / editor as separate roles

The Code variant has dedicated agent prompts for bias auditing, ethics review, and
editorial pass. On Desktop they fold into the composer's pass. Practical effects:

- **Bias auditing** — done as you go in the synthesis phase, not as a separate
  audit. Risk: you may notice a methodological issue in paper #2 and adjust your
  reading of paper #5 to match. The Code variant's separate auditor would catch
  this; Desktop won't.
- **Ethics review** — you must self-check before composing. The user can prompt
  this by asking "is this in scope?" if uncertain.
- **Editorial pass** — composer self-edits.

**Mitigation:** When the topic is sensitive (security, biomedical, dual-use), add
an explicit "Ethics scope check" paragraph in the scoping memo and have the user
confirm before investigation starts.

### 4. No hooks

The Code variant has session-start, pre-compact, stop, and user-prompt-submit
hooks that:

- Persist TODOs across sessions.
- Save handoffs at compaction.
- Surface vault state at session start.
- Detect mentioned DOIs and suggest `/capture-paper`.

Desktop has none of these. Practical effects:

- **No session continuity** — each new chat starts cold. The Inbox draft is your
  only memory of where you stopped.
- **No DOI auto-capture nudge** — when the user mentions a DOI in chat, you must
  proactively offer `paper-capture`. Don't wait for a hook.

**Mitigation:** Always write a `## Where I stopped / Next steps` section at the end
of any draft. When the user mentions a DOI, suggest `paper-capture` immediately —
don't wait.

### 5. No slash commands

`/research`, `/capture-paper`, `/status`, `/lit-map` do not exist on Desktop. The
user invokes by free-text intent. Skill descriptions in the frontmatter are tuned
for Desktop's auto-trigger mechanism.

**Mitigation:** None needed — the skill descriptions handle this.

## When NOT to use Desktop-lite

If the deliverable is going to be:

- **Cited as a systematic review** in a publication.
- **Used to make a clinical / safety / regulatory decision.**
- **Submitted as the literature foundation of a thesis chapter.**

Use the Code variant. The integrity-gate degradation here is real and the user
should accept the cost of switching tools.

For exploratory research, getting oriented in a new field, brainstorming, or
keeping a personal knowledge base, Desktop-lite is fine.

## TL;DR for the user

If a non-developer asks "is this safe to use for my literature review", the answer
is:

> Yes, with caveats: it will not hallucinate citations (the Iron Rules still
> apply), but it has weaker self-critique than the developer version. For final
> publication-grade work, have someone spot-check 5 random citations against the
> sources before you submit. For exploratory and personal use, this is fine.
