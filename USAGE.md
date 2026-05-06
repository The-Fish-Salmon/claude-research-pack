# How to actually use the pack (Path C / Claude Desktop)

Six questions a typical user has after install. Concrete prompts you can
paste straight into Claude Desktop.

---

## 1. Does this have a "Deep Research" mode like Gemini's?

Yes -- the `academic-deep-research` skill. It's structurally different from
Gemini's deep-research feature:

| | Gemini Deep Research | This pack's `academic-deep-research` |
|---|---|---|
| Source | Google Search results | Semantic Scholar, arXiv, paper-search, university-paper-access, paper-mcp, Sci-Hub |
| Output destination | Chat | A draft note in your Obsidian vault `00_Inbox/` |
| Citations resolve to | Web pages | Real DOIs / arXiv ids / Semantic Scholar paperIds |
| Hallucination guard | Light | Iron Rules + 3x Devil's Advocate self-critique + post-composition citation pre-flight |
| Depth options | One mode | Seven (quick / full / lit-review / fact-check / socratic / systematic-review / review) |

**To trigger it, do NOT say "deep research" by name.** That phrase routes
to Claude Desktop's built-in deep-research feature instead of ours. Use
free text:

```
Do an academic literature review on {your topic}. Cite real papers from
Semantic Scholar / arXiv. Land the draft in my vault Inbox.
```

---

## 2. How do I give a topic and have it search + download papers automatically?

That's the default behavior of `academic-deep-research`. The skill:

1. Sharpens the question with a scoping pass.
2. Pauses to show you the scope (`=== SCOPE CONFIRMATION ===`); you reply
   `go` (or correct the scope first).
3. Searches the paper MCP servers in priority order.
4. For every paper it actually reads at full text, invokes `paper-capture`,
   which downloads the PDF and writes a `{vault}/30_Literature/{citekey}.md`
   note. PDFs land at `{vault}/80_Attachments/papers/{citekey}.pdf`.
5. Drafts the deliverable.
6. Re-verifies every citation against Semantic Scholar (citation pre-flight).
7. Drops the draft in `{vault}/00_Inbox/research-{slug}-{date}.md`.

Example:

```
Do an academic literature review on ion-gated transistors for reservoir
computing. Capture every paper you actually read.
```

When done, check:

- `{vault}/30_Literature/` -- one new `.md` per paper consumed.
- `{vault}/80_Attachments/papers/` -- one PDF per captured paper.
- `{vault}/00_Inbox/` -- the synthesis draft.

If a PDF didn't download (paywall, no institutional access, Sci-Hub
blocked), the note still gets written with `pdf: null` so you can drop the
PDF in manually later (see question 4).

---

## 3. How do I force a deeper run, or fine-tune the search?

Three levers:

### a. Pick a specific mode

The mode controls depth and shape:

| Mode | When to use | Output size |
|---|---|---|
| `quick` | "give me a 2-minute summary" | 500-1,500 words |
| `lit-review` | annotated bibliography across 10-20 papers | 1,500-4,000 words |
| `full` | 3-8k word research report on a single question | 3,000-8,000 words |
| `systematic-review` | PRISMA-style, full corpus, reproducible search | 5,000-15,000 words |
| `fact-check` | "is claim X true?" | 300-800 words |
| `socratic` | scope is too vague, talk it out first | dialogue only |
| `review` | "review this draft I wrote" | varies |

To force one, name it in the prompt:

```
Do a systematic review on {topic}. Use PRISMA. Time budget: 30 minutes.
```

### b. Use the scope confirmation to fine-tune

After the scoping pass, the skill prints:

```
=== SCOPE CONFIRMATION ===
- Topic:        ...
- Year range:   ...
- Languages:    ...
- Inclusions:   ...
- Exclusions:   ...
- Depth:        ...
- Time budget:  ...

Reply 'go' to proceed, or correct any of the above.
```

Reply with corrections in plain English, e.g.:

```
Year range 2020-2025 only. Exclude review papers and preprints. Depth
systematic-review. Then go.
```

The skill re-scopes and pauses again, until you say `go` against a clean
scope.

### c. Mid-run steering

Once a draft exists you can keep going:

```
Pull more papers from arXiv on the {sub-topic} angle.
```
```
Re-do the synthesis section but only use papers with peer review.
```
```
Add a section on {missing angle}, capturing any new papers you read.
```

---

## 4. How do I manually add a paper and have it indexed?

Two patterns.

### Single PDF on disk

Drop the PDF anywhere accessible. Then:

```
Ingest this PDF: D:\downloads\smith2024.pdf
```

The `ingest-pdf` skill:

1. Reads page 1 of the PDF (using Claude's built-in PDF-aware Read tool).
2. Sniffs the DOI; falls back to arXiv id; falls back to title-author-year.
3. Hands the resolved id to `paper-capture`, which talks to Semantic
   Scholar for canonical metadata and writes
   `{vault}/30_Literature/{citekey}.md`.
4. Moves the original PDF to `{vault}/80_Attachments/papers/{citekey}.pdf`
   and updates the note's `pdf:` frontmatter.
5. Reports a one-liner. Done.

### A folder of PDFs

Drop them all into `{vault}/80_Attachments/papers-inbox/` (any folder you
pick is fine; this convention is just easy to remember). Then:

```
Process the PDFs in papers-inbox.
```

`ingest-pdf` walks the folder, runs the same pipeline per file, moves
ingested PDFs into `papers/`, and leaves any that couldn't be resolved in
place with a report:

```
Total: 4 ingested, 1 skipped (no extractable text), 0 failed.
```

### Indexing

There's no separate "build index" step. `lit-status` reads
`{vault}/30_Literature/` live every time it runs. Anything in that
folder is indexed by definition. To verify:

```
What's in my literature library?
```

You'll get counts by status, top tags, and gaps (papers cited in active
project notes but not yet captured).

---

## 5. How do I force Claude to use only my captured papers as the knowledge foundation?

Three options, in order of strictness.

### a. Default: Iron Rule 1

`academic-deep-research`'s first rule is: **no claim without a citation
that resolves through Semantic Scholar / arXiv / OpenAlex / publisher
DOI**. Any claim without such a citation is marked `[UNVERIFIED]` and
either dropped or escalated to you.

This is automatic; you don't have to say anything.

### b. Explicit "only my captured papers"

Iron Rule 1 lets the skill pull *new* papers via MCP. To restrict to your
existing library:

```
Answer using only papers in my 30_Literature folder. If you can't support
a claim from those, say so explicitly and stop.
```

The skill then walks the vault (via `lit-status` or directly through the
`obsidian` MCP), reads your captured notes' frontmatter + body, and
constrains itself to citekeys that already exist on disk.

### c. Synthesis from a named citekey list

If you want a tightly-scoped answer:

```
Synthesize what kim2023ionic, lee2022neural, and chen2024gate say about
ion residence time scaling.
```

That triggers `research-copilot`'s **Synthesize** move. It reads the
named notes, produces one paragraph, cites each citekey explicitly, and
flags contradictions if any. Won't pull in any other source.

---

## 6. How do I make it a rule that every claim is backed by a reference paper, with the exact wording quoted and an explanation of why that wording supports the claim?

This is the strongest mode of operation. It's not the default, but you can
demand it explicitly. Two ways:

### a. Per-prompt, exact-quote mode

```
For every claim in your answer:
- Cite the citekey from my 30_Literature folder.
- Quote the exact passage from the paper that supports the claim,
  using > blockquote syntax.
- Add one sentence explaining why that passage supports the claim.

Topic: {your question}
```

The skill (whichever you invoke -- `academic-deep-research`,
`research-copilot`, or just a free-text request) will:

1. Load the named papers' notes from `30_Literature/{citekey}.md` (which
   may already contain extracted quotes in the Takeaways / Key claims
   sections).
2. If the note doesn't have the quote, fetch the paper's full text via
   `paper-search` or `university-paper-access` MCP and quote from there.
3. Format every claim as: claim + > blockquote + 1-line justification.

### b. Project-wide rule via the active project's overview.md

Edit `{vault}/10_Projects/{slug}/overview.md` and add:

```yaml
---
project: {slug}
status: active
...
research_rules:
  - "Every claim must include a verbatim quote from a 30_Literature paper."
  - "Every quote must be followed by one sentence explaining why it supports the claim."
  - "If no captured paper supports the claim, mark [UNVERIFIED] and stop."
---
```

`research-copilot` reads the active project's `overview.md` during its
**Orient** move, so these rules are surfaced at the start of every
session that touches that project. The skill (and any sibling skill that
escalates to it) will follow them.

### c. Add the rule to research-memory.md (cross-device, cross-project)

For a rule that should apply to *every* research session on every device,
edit `{vault}/00-Claude-Context/research-memory.md` and add the same
rules under a `## Standing rules` section. `resume-research-state` reads
this file on session start, so the rules are loaded before the user even
asks the first question.

---

## Cheat sheet

| You want... | Paste this |
|---|---|
| A literature review with auto-download | `Do an academic literature review on {topic}. Capture every paper you read.` |
| A systematic review (PRISMA) | `Do a systematic review on {topic}. Use PRISMA. Time budget 30 min.` |
| A quick fact check | `Fact-check the claim that {claim}, using my captured papers.` |
| Add a PDF on disk | `Ingest this PDF: {path}` |
| Bulk ingest | `Process the PDFs in {folder}.` |
| Library overview | `What's in my literature library?` |
| What to read next | `What should I read next?` |
| Where am I | `Where is my research?` |
| Cross-paper synthesis | `Synthesize {citekey1}, {citekey2}, {citekey3} on {topic}.` |
| Quote-backed answer | (see question 6) |
| Save state for another device | `Save research state.` |
| Resume on this device | `Resume research state.` |
| Verify continuity setup | `Run sync-check.` |

---

## Troubleshooting

- The skill named `academic-deep-research` -- not `deep-research` -- is
  ours. If you see Claude using a built-in research feature instead, you
  said "deep research" by name. Re-prompt without that phrase.
- If `paper-capture` reports `(PDF: no)`, the source-priority chain
  (university-paper-access -> arXiv -> Sci-Hub) didn't land a file. The
  note is still written with `pdf: null` -- drop the PDF in manually with
  `ingest-pdf` once you have it.
- If the citation pre-flight flags an unverified citation, click through
  to confirm. The footnote in the draft tells you what was attempted.
- See [INSTALL_WINDOWS.md §4](INSTALL_WINDOWS.md#4-common-troubleshooting)
  for install / wiring issues.
