# MCP servers

This directory contains the MCP server source / config for the deep-research pack.

## Servers

| Server | Source | Purpose |
|---|---|---|
| `arxiv` | PyPI: [`arxiv-mcp-server`](https://pypi.org/project/arxiv-mcp-server/) | Search/download arXiv |
| `semantic-scholar` | PyPI: [`semanticscholar-mcp-server`](https://pypi.org/project/semanticscholar-mcp-server/) | Metadata, citation graph |
| `paper-search` | PyPI: [`paper-search-mcp`](https://pypi.org/project/paper-search-mcp/) | Multi-source unified search (arXiv, bioRxiv, medRxiv, PubMed, Google Scholar) |
| `paper-mcp` | PyPI: [`paper-mcp`](https://pypi.org/project/paper-mcp/) | Secondary metadata + DOI |
| `scihub` | git: [Sci-Hub-MCP-Server](https://github.com/JackKuo666/Sci-Hub-MCP-Server) | Last-resort PDF |
| `university-paper-access` | bundled in `university-paper-access/` | Institutional download via Unpaywall + IP auth |
| `obsidian` | bundled in `obsidian-wrapper.js` | Read/search/write the Obsidian vault via Local REST API plugin |

## Installers

Two installers ship in this directory; pick by your install path:

| Installer | Used by | Targets |
|---|---|---|
| `install-mcp-servers.sh` | Path A (WSL) | `~/.claude.json` |
| `install-mcp-servers.ps1` | Path B (Windows native) and Path C (Claude Desktop) | `%USERPROFILE%\.claude.json` (Native) **or** `%APPDATA%\Claude\claude_desktop_config.json` (Desktop) |

Both are idempotent and re-runnable. Both back up the target settings file before
overwriting (`*.bak.<timestamp>`).

### WSL install

```bash
bash install-mcp-servers.sh
```

What it does:

1. Install `uv` if missing.
2. `uv tool install` the three PyPI servers that benefit from a global install.
3. `git clone` Sci-Hub-MCP-Server into `~/.claude/mcp-servers/Sci-Hub-MCP-Server`.
4. Copy `university-paper-access/` to `~/.claude/mcp-servers/university-paper-access`.
5. Copy `obsidian-wrapper.js` to `~/.claude/mcp-servers/`, run `npm install` for its deps.
6. Merge `settings/claude.template.json` into `~/.claude.json` (jq deep-merge).

### Windows native / Desktop install

```powershell
PS> .\install-mcp-servers.ps1                  # default: -Target Native (%USERPROFILE%\.claude.json)
PS> .\install-mcp-servers.ps1 -Target Desktop  # %APPDATA%\Claude\claude_desktop_config.json
```

Same six steps as the bash version, but:

- `uv` is installed via `irm https://astral.sh/uv/install.ps1 | iex` instead of curl.
- JSON merge uses PowerShell native `ConvertFrom-Json` / `ConvertTo-Json` -- **no
  `jq` dependency on Windows.**
- Pack entries overwrite same-named ones (matches `jq -s '.[0] * .[1]'` behavior).

## Required env vars (all paths)

After install, set these (the installer prints commands you can paste):

```
PAPER_DOWNLOAD_DIR     # where downloaded PDFs land (e.g. /mnt/d/papers or D:\papers)
ARXIV_STORAGE_PATH     # arXiv MCP cache
UNPAYWALL_EMAIL        # required by Unpaywall API
OBSIDIAN_VAULT_PATH    # absolute path to the vault
OBSIDIAN_API_KEY       # from the Obsidian "Local REST API" plugin
```

WSL: add to `~/.bashrc`. Windows: use `setx` (persistent) or PowerShell profile.
For Claude Desktop, `setx` requires a sign-out / sign-in to take effect -- Desktop
GUI apps don't read shell-local vars.

## Pinned versions

Tested against:
- `arxiv-mcp-server` -- latest on PyPI as of 2026-04
- `semanticscholar-mcp-server` -- latest on PyPI as of 2026-04
- `paper-search-mcp` -- latest on PyPI as of 2026-04
- `paper-mcp` -- latest on PyPI as of 2026-04

If a server's API changes, you may need to update the corresponding template under
`settings/`.

## Manual test after install

### Path A / B

```bash
claude mcp list
# expect: arxiv, semantic-scholar, paper-search, paper-mcp, scihub, university-paper-access, obsidian
```

### Path C

Open Claude Desktop -> Settings -> Connections -> check that all seven MCP servers are
green. If a server is red, click it for the launch error log.

## Schema differences (Claude Code vs Claude Desktop)

The two products consume nearly identical MCP config but differ in a few fields:

| Field | Code (`claude.windows.template.json`) | Desktop (`claude_desktop_config.template.json`) |
|---|---|---|
| `mcpServers` key | ✅ | ✅ |
| `command` / `args` / `env` per server | ✅ | ✅ |
| `type: "stdio"` | required | omitted (default) |

The PowerShell installer picks the right template based on `-Target`.
