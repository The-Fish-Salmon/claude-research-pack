# Claude Research Pack

A portable bundle that turns any Windows laptop into a literature-aware research
workstation: multi-mode deep research, automatic paper download, structured paper
capture into an Obsidian vault, and project-aware citation reuse.

Built on top of the **academic-research-skills** project by Cheng-I Wu (CC-BY-NC 4.0)
— see [ATTRIBUTION.md](ATTRIBUTION.md). Reimplemented in Claude-native primitives
(skills + hooks + slash commands + MCP servers).

## v2 — three install paths

Pick one based on which Claude product you want to drive:

| | **Path A — Code on WSL** | **Path B — Code on Windows native** | **Path C — Claude Desktop** |
|---|---|---|---|
| **Audience** | Linux-comfortable; existing rig | CLI users without WSL | Non-developer / GUI users |
| **Slash commands** | ✅ | ✅ | ❌ (free-text invocation) |
| **Sub-agent integrity gates** | ✅ | ✅ | ❌ — single-pass + self-critique |
| **Hooks** (handoff, todo persistence, statusline) | ✅ | ✅ | ❌ |
| **Iron Rules + citation discipline** | ✅ | ✅ | ✅ |
| **Paper capture into vault** | ✅ | ✅ | ✅ |
| **Cross-device research continuity** (snapshot/resume via synced vault) | ❌ | ❌ | ✅ — v3 |
| **Setup time** | 30–45 min | 30–45 min | 20–30 min |

Decision tree and capability matrix in [INSTALL_WINDOWS.md](INSTALL_WINDOWS.md).

**Path C honest disclosure:** Claude Desktop has no Agent tool, so deep-research
runs single-pass with explicit in-context self-critique instead of independent
parallel sub-agents. Iron Rules still apply (no fabricated citations) but the
integrity gate is mechanically weaker. Read
[desktop-skills/academic-deep-research/references/desktop_limitations.md](desktop-skills/academic-deep-research/references/desktop_limitations.md)
before relying on Path C output for publication-grade work.

---

## What's in the box

### Skills (full versions — used by Path A and Path B)

- **`deep-research`** — 7-mode research pipeline (full / quick / lit-review /
  fact-check / socratic / systematic-review / review). Citation-disciplined: every
  claim must resolve through a real source. Multi-agent: spawns parallel
  investigators, synthesizer, devil's-advocate. See
  [skills/deep-research/SKILL.md](skills/deep-research/SKILL.md).
- **`paper-capture`** — Resolve DOI/arXiv/URL/title → metadata + PDF + structured
  Obsidian note. Idempotent and de-duped.
- **`lit-status`** — Read-only library inspector: counts, tags, gaps, citation
  links to active projects.
- **`handoff`** — Capture a session snapshot for the next chat.

### Skills (lite versions — used by Path C)

- **`desktop-skills/academic-deep-research`** — Same 7 modes, same Iron Rules,
  same templates, but workflow is serial in one context with explicit
  `=== DEVIL'S ADVOCATE CHECKPOINT N ===` self-critique banners. The skill is
  named `academic-deep-research` (not `deep-research`) to avoid colliding with
  Claude Desktop's built-in deep-research feature. See
  [desktop-skills/academic-deep-research/SKILL.md](desktop-skills/academic-deep-research/SKILL.md).
- **`desktop-skills/paper-capture`** and **`desktop-skills/lit-status`** — Identical
  to the Code variants (no Agent tool dependency).
- **`desktop-skills/capture-research-state`**, **`resume-research-state`**,
  **`sync-check`**, **`paper-map`** — v3 cross-device continuity. Snapshot a
  Desktop session into a synced Obsidian folder; resume it on another device.
  See [INSTALL_WINDOWS.md](INSTALL_WINDOWS.md#path-c-extra-cross-device-research-continuity)
  for setup. Backed by a stdlib Python helper at
  [tools/research_sync_agent.py](tools/research_sync_agent.py) bundled into each
  skill's `bin/` at zip time.

### Slash commands (Path A / B only)

- `/research [--mode <name>] <topic>`
- `/capture-paper <doi|arxiv|url|title> [--citekey <key>] [--project <slug>]`
- `/lit-map [summary|unread|tags|gaps|orphans|citation-map <citekey>]`
- `/status`, `/port-to-vault`

### MCP servers (installed by the bundled installer)

- `arxiv`, `semantic-scholar`, `paper-search`, `paper-mcp` — paper search & metadata
- `university-paper-access` — institutional full-text via Unpaywall
- `scihub` — last-resort PDF
- `obsidian` — read/search/write the Obsidian vault

Two installers ship in this pack:

- `mcp-servers/install-mcp-servers.sh` — bash, for WSL (Path A)
- `mcp-servers/install-mcp-servers.ps1` — PowerShell, for Windows native and Desktop
  (Path B and C; pick target with `-Target Native|Desktop`)

### Hooks (Path A / B only — Desktop has no hooks API)

- `precompact-handoff.py` — write `handoff_latest.md` before context compaction
- `session-start-context.py` — inject latest handoff + review summary on resume
- `stop-persist-todos.py` — keep TodoWrite items alive across sessions
- `statusline.sh` (WSL) / `statusline.ps1` (Windows native) — bottom-bar status
- `paper-mention-detect.py` — *off by default* — suggest `/capture-paper` when a
  DOI is mentioned

### Vault templates (all three paths)

PARA-style scaffolding for Obsidian. Drop into a fresh vault to get
`30_Literature/`, `70_Templates/literature.md`, lit-review and research-question
templates.

---

## Install

See [INSTALL_WINDOWS.md](INSTALL_WINDOWS.md) for the full decision tree and
walkthroughs. The router is:

```powershell
PS> .\scripts\setup.ps1 -Mode WSL       # Path A (default)
PS> .\scripts\setup.ps1 -Mode Native    # Path B
PS> .\scripts\setup.ps1 -Mode Desktop   # Path C
```

## Quickstart (after install)

### Path A / B — slash commands in Claude Code

```text
/research --mode lit-review "ion-gated transistors for reservoir computing"
/capture-paper 10.1038/s41586-021-03819-2
/lit-map gaps
```

### Path C — free-text in Claude Desktop

```text
> Do a lit review on ion-gated transistors for reservoir computing.
> Save this paper: 10.1038/s41586-021-03819-2
> What are the gaps in my reading on transistors?
```

---

## Design principles

- **Citation discipline first.** A "fact" without a citation that resolves through
  Semantic Scholar / arXiv / OpenAlex is a hallucination, not a fact. Deep-research
  is structured to make hallucination expensive — the Devil's Advocate has block
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

v2.0 — adds Path B (Windows native) and Path C (Claude Desktop). v1.0 (Path A only)
remains supported by leaving the WSL tree unchanged.

Built against the upstream `Imbad0202/academic-research-skills` v3.6.5 (April 2026).

## License

CC-BY-NC 4.0. See [LICENSE](LICENSE) and [ATTRIBUTION.md](ATTRIBUTION.md).
