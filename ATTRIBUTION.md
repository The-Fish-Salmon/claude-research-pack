# Attribution

## Upstream

Substantial portions of the `deep-research` skill — the 7-mode workflow, the agent-team architecture, the Iron Rules, the PRISMA flow template, the Devil's Advocate concession protocol — are adapted from:

> **Academic Research Skills** by Cheng-I Wu
> https://github.com/Imbad0202/academic-research-skills
> Licensed under CC-BY-NC 4.0
> Tested against upstream v3.6.5 (April 2026)

The upstream project targets `claude.ai` Projects (no MCP, no hooks). This pack reimplements the *intent* of the upstream `deep-research` skill in **Claude Code** native primitives, and integrates it with literature MCP servers and an Obsidian vault. The other upstream skills (`academic-paper`, `academic-paper-reviewer`, `academic-pipeline`) are **not** included in this pack.

## What's adapted vs. original

**Adapted from upstream**:
- The 7-mode taxonomy (full / quick / lit-review / fact-check / socratic / systematic-review / review).
- The agent role concept (scoping / investigator / synthesizer / bias-auditor / composer / editor / ethics / devil's-advocate).
- The Iron Rules (citation discipline, devil's advocate checkpoints, ethics halt, socratic discipline).
- The PRISMA flow diagram and claim/evidence table templates.

**Original to this pack**:
- Claude Code-specific implementation: `Agent` tool sub-agent spawn pattern, MCP wiring with the seven specific paper servers in priority order, `obsidian` MCP hand-off to vault.
- The `paper-capture` and `lit-status` skills.
- The `paper-mention-detect.py` hook.
- The Windows / WSL2 install path, `setup.sh` / `setup.ps1` / `install-mcp-servers.sh`.
- The vault PARA template structure.
- All slash commands.

## License

CC-BY-NC 4.0 (matches upstream). When sharing or modifying this pack, retain this attribution.

When citing this pack in academic work that benefited from it, please cite both:
- Wu, C.-I. *Academic Research Skills*. https://github.com/Imbad0202/academic-research-skills
- This pack (with whatever distribution URL you received it from)

## Other components

- The session-continuity hooks (`precompact-handoff.py`, `session-start-context.py`, `stop-persist-todos.py`, `statusline.sh`) and the `handoff` skill are from the package author's personal Claude Code rig and are released here under CC-BY-NC 4.0 for distribution as part of this pack.
- The `university-paper-access` MCP server is a small wrapper around Unpaywall + Semantic Scholar + OpenAlex + CrossRef and is included by reference.
- Third-party MCP servers (`arxiv-mcp-server`, `semanticscholar-mcp-server`, `paper-search-mcp`, `paper-mcp`, Sci-Hub-MCP-Server) are installed from their upstream sources by `install-mcp-servers.sh`; this pack does not redistribute them.
