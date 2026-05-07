# Claude Research Pack

A portable bundle that turns any Windows laptop into a literature-aware research
workstation: multi-mode deep research, automatic paper download, structured paper
capture into an Obsidian vault, and project-aware citation reuse.

Built on top of the **academic-research-skills** project by Cheng-I Wu (CC-BY-NC 4.0)
-- see [ATTRIBUTION.md](ATTRIBUTION.md). Reimplemented in Claude-native primitives
(skills + hooks + slash commands + MCP servers).

## v2 -- three install paths

Pick one based on which Claude product you want to drive:

| | **Path A -- Code on WSL** | **Path B -- Code on Windows native** | **Path C -- Claude Desktop** |
|---|---|---|---|
| **Audience** | Linux-comfortable; existing rig | CLI users without WSL | Non-developer / GUI users |
| **Slash commands** | ✅ | ✅ | ❌ (free-text invocation) |
| **Sub-agent integrity gates** | ✅ | ✅ | ❌ -- single-pass + self-critique |
| **Hooks** (handoff, todo persistence, statusline) | ✅ | ✅ | ❌ |
| **Iron Rules + citation discipline** | ✅ | ✅ | ✅ |
| **Paper capture into vault** | ✅ | ✅ | ✅ |
| **Cross-device research continuity** (snapshot/resume via synced vault) | ❌ | ❌ | ✅ -- v3 |
| **Local-PDF ingestion** | ❌ | ✅ -- v5 | ✅ -- v4 |
| **Interactive research co-pilot loop** | ❌ | ✅ -- v5 | ✅ -- v4 |
| **Mandatory scope confirmation + citation pre-flight** | ❌ | ✅ -- v5 | ✅ -- v4 |
| **One-command install (winget + auto-detect + self-test)** | ❌ | ✅ -- v5 | ❌ |
| **Setup time** | 30-45 min | **~5 min** (after Claude Code) | 20-30 min |

Decision tree and capability matrix in [INSTALL_WINDOWS.md](INSTALL_WINDOWS.md).

**Path C honest disclosure:** Claude Desktop has no Agent tool, so deep-research
runs single-pass with explicit in-context self-critique instead of independent
parallel sub-agents. Iron Rules still apply (no fabricated citations) but the
integrity gate is mechanically weaker. Read
[desktop-skills/academic-deep-research/references/desktop_limitations.md](desktop-skills/academic-deep-research/references/desktop_limitations.md)
before relying on Path C output for publication-grade work.

---

## What's in the box

### Skills (full versions -- used by Path A and Path B)

- **`deep-research`** -- 7-mode research pipeline (full / quick / lit-review /
  fact-check / socratic / systematic-review / review). Citation-disciplined: every
  claim must resolve through a real source. Multi-agent: spawns parallel
  investigators, synthesizer, devil's-advocate. See
  [skills/deep-research/SKILL.md](skills/deep-research/SKILL.md).
- **`paper-capture`** -- Resolve DOI/arXiv/URL/title -> metadata + PDF + structured
  Obsidian note. Idempotent and de-duped.
- **`lit-status`** -- Read-only library inspector: counts, tags, gaps, citation
  links to active projects.
- **`handoff`** -- Capture a session snapshot for the next chat.

### Skills (lite versions -- used by Path C)

- **`desktop-skills/academic-deep-research`** -- Same 7 modes, same Iron Rules,
  same templates, but workflow is serial in one context with explicit
  `=== DEVIL'S ADVOCATE CHECKPOINT N ===` self-critique banners. The skill is
  named `academic-deep-research` (not `deep-research`) to avoid colliding with
  Claude Desktop's built-in deep-research feature. See
  [desktop-skills/academic-deep-research/SKILL.md](desktop-skills/academic-deep-research/SKILL.md).
- **`desktop-skills/paper-capture`** and **`desktop-skills/lit-status`** -- Identical
  to the Code variants (no Agent tool dependency).
- **`desktop-skills/capture-research-state`**, **`resume-research-state`**,
  **`sync-check`**, **`paper-map`** -- v3 cross-device continuity. Snapshot a
  Desktop session into a synced Obsidian folder; resume it on another device.
  See [INSTALL_WINDOWS.md](INSTALL_WINDOWS.md#path-c-extra-cross-device-research-continuity)
  for setup. Backed by a stdlib Python helper at
  [tools/research_sync_agent.py](tools/research_sync_agent.py) bundled into each
  skill's `bin/` at zip time.
- **`desktop-skills/ingest-pdf`** -- v4. Drop a local PDF (or a folder of PDFs);
  the skill extracts the DOI / arXiv id / title from the file, hands off to
  `paper-capture` for resolution, and moves the original into
  `80_Attachments/papers/{citekey}.pdf`. Closes the gap where users had a
  paper on disk but no DOI handy.
- **`desktop-skills/research-copilot`** -- v4. The interactive loop layer:
  Orient -> Question -> Suggest -> Synthesize -> Escalate. One conversational
  move per turn, never invents citations, defers heavy lifting to the other
  skills. Turns the pack from a one-shot lit-review tool into an ongoing
  research conversation.

### Slash commands (Path A / B only)

- `/research [--mode <name>] <topic>`
- `/capture-paper <doi|arxiv|url|title> [--citekey <key>] [--project <slug>]`
- `/lit-map [summary|unread|tags|gaps|orphans|citation-map <citekey>]`
- `/status`, `/port-to-vault`

### MCP servers (installed by the bundled installer)

- `arxiv`, `semantic-scholar`, `paper-search`, `paper-mcp` -- paper search & metadata
- `university-paper-access` -- institutional full-text via Unpaywall
- `scihub` -- last-resort PDF
- `obsidian` -- read/search/write the Obsidian vault

Two installers ship in this pack:

- `mcp-servers/install-mcp-servers.sh` -- bash, for WSL (Path A)
- `mcp-servers/install-mcp-servers.ps1` -- PowerShell, for Windows native and Desktop
  (Path B and C; pick target with `-Target Native|Desktop`)

### Hooks (Path A / B only -- Desktop has no hooks API)

- `precompact-handoff.py` -- write `handoff_latest.md` before context compaction
- `session-start-context.py` -- inject latest handoff + review summary on resume
- `stop-persist-todos.py` -- keep TodoWrite items alive across sessions
- `statusline.sh` (WSL) / `statusline.ps1` (Windows native) -- bottom-bar status
- `paper-mention-detect.py` -- *off by default* -- suggest `/capture-paper` when a
  DOI is mentioned

### Vault templates (all three paths)

PARA-style scaffolding for Obsidian. Drop into a fresh vault to get
`30_Literature/`, `70_Templates/literature.md`, lit-review and research-question
templates.

---

## Install + use

- [INSTALL_WINDOWS.md](INSTALL_WINDOWS.md) -- full decision tree and walkthroughs.
- [USAGE.md](USAGE.md) -- how to actually use the pack after install: trigger
  prompts for deep research, auto-download papers, fine-tune search, ingest
  local PDFs, force quote-backed answers.

The router is:

```powershell
PS> .\scripts\setup.ps1 -Mode WSL       # Path A (default)
PS> .\scripts\setup.ps1 -Mode Native    # Path B
PS> .\scripts\setup.ps1 -Mode Desktop   # Path C
```

## Quickstart (after install)

### Path A / B -- slash commands in Claude Code

```text
/research --mode lit-review "ion-gated transistors for reservoir computing"
/capture-paper 10.1038/s41586-021-03819-2
/lit-map gaps
```

### Path C -- free-text in Claude Desktop

```text
> Do a lit review on ion-gated transistors for reservoir computing.
> Save this paper: 10.1038/s41586-021-03819-2
> What are the gaps in my reading on transistors?
```

---

## Design principles

- **Citation discipline first.** A "fact" without a citation that resolves through
  Semantic Scholar / arXiv / OpenAlex is a hallucination, not a fact. Deep-research
  is structured to make hallucination expensive -- the Devil's Advocate has block
  authority on Path A/B and uses an explicit mechanical checklist on Path C.
- **Vault is the canonical brain.** Drafts land in `00_Inbox/` for user curation;
  only `paper-capture` writes directly to `30_Literature/`. Project notes accumulate
  citekeys; the same papers come back as context on the next project.
- **One pack, three runtimes.** WSL, Windows native, and Desktop ship in the same
  pack. Recipients pick by path; nothing is renamed across versions, so v1 users
  can `git pull` to v2 with zero migration.
- **Bring your own institutional access.** `university-paper-access` uses
  Unpaywall + your campus IP. If you don't have institutional access, the pack
  still works via arXiv + (optionally) Sci-Hub.

---

## Versions and provenance

- **v5.0** -- Path B (Windows-native Code) overhaul: one-command install
  with winget pre-flight, auto-detect vault path + REST API key, automatic
  vault bootstrap + Obsidian config, post-install self-test. Plus full
  feature parity with Path C: `ingest-pdf`, `research-copilot`, mandatory
  scoping, citation pre-flight, `lit-status next-action`. New slash
  commands `/ingest-pdf` and `/copilot`.
- **v4.0** -- adds local-PDF ingestion (`ingest-pdf`), interactive co-pilot
  (`research-copilot`), mandatory scope confirmation + post-composition
  citation pre-flight in `academic-deep-research`, and a `next-action` mode
  in `lit-status`. (Path C only at v4; ported to Path B in v5.)
- **v3.0** -- cross-device research continuity for Path C
  (`capture-research-state`, `resume-research-state`, `sync-check`,
  `paper-map` + `tools/research_sync_agent.py`).
- **v2.0** -- adds Path B (Windows native) and Path C (Claude Desktop) on
  top of the original Path A WSL build.
- **v1.0** -- Path A only (Claude Code on WSL).

Built against the upstream `Imbad0202/academic-research-skills` v3.6.5 (April 2026).

## License

CC-BY-NC 4.0. See [LICENSE](LICENSE) and [ATTRIBUTION.md](ATTRIBUTION.md).
