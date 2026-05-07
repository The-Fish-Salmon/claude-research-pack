# Install on Windows -- Claude Research Pack v4

This pack supports **three install paths**. Pick one based on which Claude product
you'll use.

---

## 0. Choose your path

| | **Path A -- Code on WSL** | **Path B -- Code on Windows native** | **Path C -- Claude Desktop** |
|---|---|---|---|
| **Audience** | Linux-comfortable; existing rig | CLI users without WSL | Non-developer / GUI users |
| **Claude product** | Claude Code (CLI) | Claude Code (CLI) | Claude Desktop (chat app) |
| **Slash commands** (`/research`, `/capture-paper`) | ✅ | ✅ | ❌ (free-text invocation) |
| **Sub-agent integrity gates** (parallel investigators, independent devil's-advocate) | ✅ | ✅ | ❌ -- **single-pass with self-critique** |
| **Hooks** (auto-handoff, todo persistence, statusline) | ✅ | ✅ | ❌ |
| **Iron Rules + citation discipline** | ✅ | ✅ | ✅ |
| **Paper capture into vault** | ✅ | ✅ | ✅ |
| **Cross-device research continuity** (snapshot/resume via synced vault) | ❌ | ❌ | ✅ -- v3 |
| **Local-PDF ingestion** (drop a PDF, get a 30_Literature note) | ❌ | ✅ -- v5 | ✅ -- v4 |
| **Interactive research co-pilot loop** (orient/question/suggest/synthesize/escalate) | ❌ | ✅ -- v5 | ✅ -- v4 |
| **Mandatory scoping confirmation + citation pre-flight in deep-research** | ❌ | ✅ -- v5 | ✅ -- v4 |
| **Auto-install prereqs via winget + auto-detect vault & API key** | ❌ | ✅ -- v5 | ❌ |
| **Post-install self-test** | ❌ | ✅ -- v5 | ❌ |
| **Most-tested** | ✅ | new in v2 / v5 | new in v2 / v3 / v4 |
| **Setup time** | 30-45 min | **~5 min** (after Claude Code) | 20-30 min |

**Decision tree:**

- "I want a CLI and I already use WSL" -> **Path A**.
- "I want a CLI but no WSL" -> **Path B**.
- "I want a chat app, no terminal" -> **Path C**.

**Path C honest disclosure:** Claude Desktop has no Agent tool, so the deep-research
skill can't spawn parallel investigators or an independent devil's-advocate. The
desktop variant runs single-pass and uses explicit in-context self-critique
checkpoints. Iron Rules still apply (no fabricated citations) but the integrity
gate is mechanically weaker. Read
[desktop-skills/academic-deep-research/references/desktop_limitations.md](desktop-skills/academic-deep-research/references/desktop_limitations.md)
for what this means in practice.

---

## 1. Common prerequisites (all three paths)

You need (in addition to path-specific prereqs below):

- **Obsidian Desktop** -- https://obsidian.md
- **Obsidian "Local REST API" community plugin** -- In Obsidian: Settings ->
  Community plugins -> Browse -> search `Local REST API` -> Install -> Enable. Copy
  the API key from the plugin settings; you'll need it shortly.
- An Obsidian vault to receive captured papers. (Use an existing one, or create a
  fresh one.) Note the **absolute path** to its root directory.

### How the Obsidian MCP server fits in

Several skills in this pack (`paper-capture`, `lit-status`, `deep-research`'s
hand-off step) read and write through an MCP server named **`obsidian`**. The
chain of moving parts is worth understanding because it has the most failure
modes of any server in the pack:

```
Claude (Code or Desktop)
   ↓  spawns
mcp-servers/obsidian-wrapper.js   <- bundled in this pack
   ↓  spawns (as a child process)
mcp-obsidian (npm package)         <- installed by install-mcp-servers.{sh,ps1}
   ↓  HTTP over loopback (port 27124, TLS)
Local REST API plugin (inside Obsidian)
   ↓  reads / writes
Your vault on disk
```

What each piece does:

- **`obsidian-wrapper.js`** -- a tiny Node shim that the pack ships. It launches
  `mcp-obsidian` and patches each tool's `inputSchema` to add `"type": "object"`,
  which Claude Code requires but `mcp-obsidian` omits. Without this wrapper the
  obsidian server registers but every tool call fails schema validation.
- **`mcp-obsidian`** -- the actual MCP server. Talks to the Local REST API plugin
  over `https://127.0.0.1:27124/`. Read frontmatter, list notes, search, write
  files. Installed by both installers via `npm install mcp-obsidian` next to the
  wrapper.
- **Local REST API plugin** -- runs inside the Obsidian app and exposes the
  vault over a TLS-protected loopback HTTP API. **Obsidian must be running** for
  the obsidian MCP server to work -- if you close Obsidian, the server still
  starts but every call returns a connection error.
- **`OBSIDIAN_API_KEY`** -- the bearer token from the plugin's settings page.
  `mcp-obsidian` reads it from the inherited environment of the spawned process.
- **`OBSIDIAN_VAULT_PATH`** -- absolute path to the vault root. Used by
  `paper-capture` (skill), `/port-to-vault` (Path A/B slash command), and the
  v3 continuity skills to compute output paths
  (`{vault}/30_Literature/{citekey}.md`, etc.). Must point at the **same vault**
  that the Local REST API plugin is currently serving.

This is why the pack's troubleshooting matrix flags the `obsidian` server
specifically: it's the only one with a four-link chain, and *every link* must be
up at runtime.

Quick test the chain is intact (any path):

```powershell
PS> curl.exe -k -H "Authorization: Bearer $env:OBSIDIAN_API_KEY" https://127.0.0.1:27124/
```

```bash
$ curl -k -H "Authorization: Bearer $OBSIDIAN_API_KEY" https://127.0.0.1:27124/
```

You should get a small JSON status response -- not "connection refused" (Obsidian
not running, or plugin disabled) and not "401 Unauthorized" (wrong API key).

---

## 2. Get the pack

Clone or unzip into a working directory:

```powershell
PS> cd C:\Users\<you>\
PS> git clone https://github.com/The-Fish-Salmon/claude-research-pack.git
# or extract the zip into the same location
```

> Tip: keep the path short and ASCII-only -- long paths and accented characters
> trip up some MCP servers on Windows.

---

## 3. Run the installer

The router script `scripts\setup.ps1` picks the right install pipeline:

```powershell
PS> cd .\claude-research-pack
PS> .\scripts\setup.ps1 -Mode WSL       # Path A (default if -Mode omitted)
PS> .\scripts\setup.ps1 -Mode Native    # Path B
PS> .\scripts\setup.ps1 -Mode Desktop   # Path C
```

The next three sections cover what each mode does and what to do after.

---

## Path A -- Claude Code on WSL

### Path A prerequisites

| Tool | How |
|---|---|
| **Windows 10/11** with virtualization in BIOS | -- |
| **WSL2** (Ubuntu 22.04 or 24.04) | `wsl --install` (PowerShell admin), then reboot |
| **Claude Code CLI** | https://claude.ai/code -> install for Windows or Linux |
| **Node.js >= 20** (in WSL) | `curl -fsSL https://deb.nodesource.com/setup_20.x \| sudo -E bash - && sudo apt-get install -y nodejs` |
| **git, jq, rsync, curl** (in WSL) | `sudo apt-get install -y git jq rsync curl` |
| **Python 3.10+** (in WSL; 3.12 preferred) | `sudo apt-get install -y python3 python3-venv` (Ubuntu 22.04 ships 3.10, 24.04 ships 3.12 -- either works) |

### Path A install

```powershell
PS> .\scripts\setup.ps1 -Mode WSL
```

Or directly from inside WSL:

```bash
cd /mnt/c/Users/<you>/claude-research-pack
bash scripts/setup.sh
```

What the WSL setup script does:

1. Copies `skills/`, `hooks/`, `commands/` into `~/.claude/`.
2. Calls `mcp-servers/install-mcp-servers.sh`, which installs `uv`, the PyPI MCP
   servers, clones Sci-Hub-MCP-Server, copies bundled custom servers, runs
   `npm install` for the Obsidian wrapper, merges MCP entries into
   `~/.claude.json` (jq deep-merge).
3. Merges `settings/settings.template.json` into `~/.claude/settings.json`.

Idempotent -- re-run if a step fails.

### Path A env vars

Add to `~/.bashrc` (or `~/.zshrc`) inside WSL:

```bash
export PAPER_DOWNLOAD_DIR=/mnt/d/papers
export ARXIV_STORAGE_PATH="$PAPER_DOWNLOAD_DIR/arxiv"
export UNPAYWALL_EMAIL=you@example.org
export OBSIDIAN_VAULT_PATH="/mnt/c/Users/$USER/Documents/MyVault"
export OBSIDIAN_API_KEY="paste-from-obsidian-plugin"
# Optional: export PAPER_MENTION_HOOK=on
```

Then `source ~/.bashrc` (or open a new terminal).

### Path A vault bootstrap

```bash
rsync -a --ignore-existing ~/claude-research-pack/vault-templates/ "$OBSIDIAN_VAULT_PATH/"
```

Open Obsidian -> Settings -> Files & Links -> "Default location for new attachments" -> `80_Attachments`.
Settings -> Templates (core plugin) -> "Template folder location" -> `70_Templates`.

### Path A smoke tests

In a Claude Code session:

```text
> claude mcp list
```
Expect all 7 servers listed. If any are red, run `claude --debug` and look at stderr.

```text
/status
/research --mode quick "ion-gated transistors for reservoir computing"
/capture-paper 10.1038/s41586-021-03819-2
/lit-map summary
```

If all five pass, Path A is up.

---

## Path B -- Claude Code on Windows native

### Path B prerequisites

Just one manual install:

| Tool | How |
|---|---|
| **Claude Code for Windows** | https://claude.ai/code -> install for Windows |

That's it. Python 3.12, Node LTS, Git for Windows, and `uv` are all
auto-installed by `setup.ps1` via `winget` (Windows 10/11's built-in package
manager). Obsidian Desktop is also needed if you want vault integration --
install from https://obsidian.md and enable the **Local REST API** community
plugin once.

### Path B install

```powershell
PS> .\scripts\setup.ps1 -Mode Native
```

What it does (v5):

1. **Pre-flight via winget.** Auto-installs missing prereqs: Python 3.12,
   Node LTS, Git for Windows, uv. Skip-if-present, idempotent. Hard-fails
   with a one-line fix if winget itself is absent ("install App Installer
   from the Microsoft Store").
2. **Configuration wizard.** One prompt block. Defaults are auto-detected
   from existing config:
   - Vault path -- pulled from `%APPDATA%\obsidian\obsidian.json` (recent
     vaults).
   - API key -- pulled from `<vault>\.obsidian\plugins\obsidian-local-rest-api\data.json`.
   - Unpaywall email -- pulled from `git config --global user.email`.
   - Paper download dir -- defaults to `D:\papers` if D: exists, else
     `%USERPROFILE%\papers`.
   You confirm or override each. Hit Enter to accept defaults.
3. **Env vars (transactional).** Runs `setx` for the five vars **and** sets
   them in the current shell, so the rest of the install can use them
   immediately.
4. **Vault bootstrap.** Copies `vault-templates\*` into your vault
   (idempotent -- existing files are left alone). Writes
   `<vault>\.obsidian\app.json` to set attachments folder = `80_Attachments`
   and the templates plugin folder = `70_Templates`. No more manual clicks
   in Obsidian's Settings.
5. **Skills + hooks + commands.** Copies six skills (deep-research,
   paper-capture, lit-status, handoff, ingest-pdf, research-copilot), five
   hooks, seven slash commands into `%USERPROFILE%\.claude\`.
6. **MCP servers.** Calls `install-mcp-servers.ps1 -Target Native`.
7. **Settings merge.** Merges `settings\settings.windows.template.json`
   into `%USERPROFILE%\.claude\settings.json`.
8. **Self-test.** Runs `scripts\path-b-selftest.ps1` and reports green/red
   per check (claude mcp list, settings parse, env-var visibility, Obsidian
   REST API reachability).

Idempotent. Re-run any time -- safe.

### Path B re-running the self-test

Any time you suspect something drifted:

```powershell
PS> .\scripts\path-b-selftest.ps1
```

Six checks; exits 0 if all green.

### Path B smoke tests (after install)

Open a fresh PowerShell window (env vars need it) and try:

```text
> claude
/status
/research --mode quick "ion-gated transistors for reservoir computing"
/ingest-pdf D:\downloads\some-paper.pdf
/copilot
/lit-map summary
/capture-paper 10.1038/s41586-021-03819-2
```

`/research` will pause at `=== SCOPE CONFIRMATION ===` -- reply `go` (or
correct the scope first). Final draft ends with
`Captured N citations; M re-verified, K flagged unverified.` (citation
pre-flight).

### Path B manual fallback

If you ever need to set env vars by hand:

```powershell
PS> setx OBSIDIAN_VAULT_PATH   "C:\Users\<you>\Documents\MyVault"
PS> setx OBSIDIAN_API_KEY      "<from Obsidian Local REST API plugin>"
PS> setx PAPER_DOWNLOAD_DIR    "D:\papers"
PS> setx ARXIV_STORAGE_PATH    "D:\papers\arxiv"
PS> setx UNPAYWALL_EMAIL       "you@example.org"
```

`setx` writes to the persistent user environment but does NOT update the
current PowerShell session. **Open a fresh PowerShell window** afterwards.

---

## Path C -- Claude Desktop

### Path C prerequisites

| Tool | How |
|---|---|
| **Claude Desktop** | https://claude.ai/desktop |
| **Python 3.12** | python.org installer |
| **Node.js LTS** (>= 20) | nodejs.org |
| **Git for Windows** | git-scm.com/download/win |

### Path C install

```powershell
PS> .\scripts\setup.ps1 -Mode Desktop
```

What it does:

1. Calls `mcp-servers\install-mcp-servers.ps1 -Target Desktop`, which:
   - Same MCP server installs as Path B.
   - **But writes** `mcpServers` config into `%APPDATA%\Claude\claude_desktop_config.json`
     (Desktop's location) instead of `%USERPROFILE%\.claude.json`.
2. Calls `scripts\prepare-desktop-pack.ps1`, which copies the v3 helper
   `tools\research_sync_agent.py` into each continuity skill's `bin\` folder,
   then writes one zip per skill into `dist-desktop\<skill-name>.zip`.
   Each zip has the layout Claude Desktop's importer demands: **exactly one
   top-level folder** named after the skill, with **exactly one SKILL.md
   inside it**, plus any subfolders (`modes/`, `references/`, `templates/`,
   `bin/`).

   **Why the rename `deep-research -> academic-deep-research`?** Claude Desktop
   ships a built-in skill named `deep-research`. Two skills with the same
   name collide and the built-in wins. The unique name forces Desktop to
   invoke ours.
3. If `OBSIDIAN_VAULT_PATH` is set in the current shell, runs
   `python tools\research_sync_agent.py init --vault $env:OBSIDIAN_VAULT_PATH`
   to scaffold the cross-device continuity folder `00-Claude-Context\` in the
   vault. If the env var isn't set, prints the manual command to run later.
   Idempotent -- safe to re-run after `setx OBSIDIAN_VAULT_PATH` and a relogin.

### Path C manual import (required)

Claude Desktop installs Skills only via the GUI:

1. Open Claude Desktop -> **Settings** -> **Skills**.
2. **If you imported anything from this pack before** -- including per-skill
   zips with loose `SKILL.md` at the root, a `research-pack` bundle from a
   transient v3 attempt, or any of `deep-research`, `academic-deep-research`,
   `paper-capture`, `lit-status`, `capture-research-state`,
   `resume-research-state`, `sync-check`, `paper-map` -- **remove all of them
   first**. Mixing old and new imports causes name conflicts.
3. Click **Import**. Import each `.zip` from `dist-desktop\` one at a time --
   **nine imports total**: `academic-deep-research`, `paper-capture`,
   `lit-status`, `capture-research-state`, `resume-research-state`,
   `sync-check`, `paper-map`, `ingest-pdf` (v4), `research-copilot` (v4).
4. **Restart Claude Desktop** so the new MCP servers in
   `%APPDATA%\Claude\claude_desktop_config.json` are picked up.

### Path C env vars

`setx` is required because Claude Desktop is a GUI app and only reads
**user-environment** vars (not vars set in your current PowerShell session):

```powershell
PS> setx PAPER_DOWNLOAD_DIR    "D:\papers"
PS> setx ARXIV_STORAGE_PATH    "D:\papers\arxiv"
PS> setx UNPAYWALL_EMAIL       "you@example.org"
PS> setx OBSIDIAN_VAULT_PATH   "C:\Users\<you>\Documents\MyVault"
PS> setx OBSIDIAN_API_KEY      "<from Obsidian plugin>"
```

After `setx`, **sign out and back in** (not just open a new shell) -- Desktop apps
launched from the Start menu need a fresh user session to see the new vars.

### Path C vault bootstrap

```powershell
PS> Copy-Item -Recurse -Force:$false `
        -Path .\vault-templates\* `
        -Destination $env:OBSIDIAN_VAULT_PATH
```

Same Obsidian config as Path B (attachments folder, templates folder).

### Path C smoke tests

In a new chat in Claude Desktop:

1. *Discovery* -- ask (free text -- do NOT say "deep-research" by name, since
   that's a built-in Desktop skill that will pre-empt ours):
   > Do an academic literature review on ion-gated transistors for reservoir
   > computing. Cite real papers from Semantic Scholar / arXiv.

   Expected: the `academic-deep-research` skill triggers, runs single-pass
   workflow with explicit `=== DEVIL'S ADVOCATE CHECKPOINT N ===` banners, and
   lands a draft note in your vault `00_Inbox/`.

   Sanity check: every citation in the output must resolve through Semantic
   Scholar or have a real DOI/arXiv id. If you see citations the model can't
   point you at, the wrong skill (the built-in) fired -- see Troubleshooting.

2. *Capture* -- in another chat, paste:
   > Save this paper: 10.1038/s41586-021-03819-2

   Expected: `paper-capture` triggers, downloads PDF (if institutional access),
   writes `30_Literature/{citekey}.md`.

3. *Library* -- ask:
   > What's in my literature library? Show me the top tags.

   Expected: `lit-status` triggers and returns counts + top tags.

**Acceptance for Path C is weaker than Code paths.** Confirm Iron Rules: no
fabricated DOIs, all citations resolve when you click them. Spot-check at least 5
citations against the cited sources before relying on the deliverable.

### Path C extra: cross-device research continuity

Path C ships four extra skills for **cross-device** continuity:
`capture-research-state`, `resume-research-state`, `sync-check`, `paper-map`.
They read and write a folder at the vault root called `00-Claude-Context/`.
Sync software (Obsidian Sync / iCloud / OneDrive / Dropbox / Syncthing) mirrors
that folder across devices; when you open Claude Desktop on a different
machine, `resume-research-state` rehydrates the session from those files.

This is *separate from* the `handoff` skill, which only covers single-device
session ends.

#### Pick a sync provider

| Provider | Cost | Pros | Cons |
|---|---|---|---|
| **Obsidian Sync** | paid | First-party, conflict-aware, fast | Annual subscription |
| iCloud Drive | free (Apple ID) | Works out of the box on macOS / iCloud-for-Windows | Windows reliability is mixed |
| OneDrive / Google Drive / Dropbox | free tier | Ubiquitous | Can corrupt `.obsidian/` workspace files |
| Syncthing | free / self-hosted | Peer-to-peer, no cloud | Setup overhead |

If unsure, use Obsidian Sync. It handles `.obsidian/` correctly and
cross-device conflicts are explicit, not silent.

#### Initialize the continuity folder

`setup.ps1 -Mode Desktop` runs the helper for you if `OBSIDIAN_VAULT_PATH` is
already set. If not, after `setx OBSIDIAN_VAULT_PATH` and a relogin:

```powershell
PS> python .\tools\research_sync_agent.py init --vault $env:OBSIDIAN_VAULT_PATH
```

(Use `py -3.12` instead of `python` if `python` is not on PATH.) Idempotent --
safe to re-run.

#### Verify before you rely on it

In a new Claude Desktop chat:

```
Run sync-check on my vault.
```

Expect a verdict ending in `Status: Ready`. If `Not Ready`, the next-action
line tells you exactly what to fix.

#### First snapshot

Do any small piece of work in a Desktop chat (e.g. ask a research question
that uses `deep-research` quick mode). Then:

```
Save research state.
```

Expect a one-liner reporting `Captured: snapshot {filename}, durable files
updated.` Verify in your vault: a new file exists at
`<vault>/00-Claude-Context/session-snapshots/{timestamp}-{device-slug}.md`.

#### Resume on a second device

After the vault has synced to machine B, install Path C there too. In a fresh
Claude Desktop chat:

```
Resume research state.
```

Claude reads `current-state.md`, the latest snapshot, etc., and proposes a
next action that matches what machine A was doing. If your sync provider
produced two competing snapshots from overlapping work on both machines,
Claude surfaces both filenames and asks which is authoritative -- never picks
silently.

#### Conflict resolution

The skills are biased toward append-only. They will:

- Refuse to delete or overwrite a snapshot, even when asked.
- Surface concurrent snapshots and ask the user to choose.
- Update durable files only from the **chosen** snapshot, preserving the
  other on disk for review.

If you genuinely want to retire old snapshots, do it manually with
`File Explorer` / `Finder` -- and never delete the newest one.

---

## 4. Common: troubleshooting

| Symptom | Path | Fix |
|---|---|---|
| `claude mcp list` shows `obsidian: failed` | A, B | Walk the chain top-to-bottom: (1) Obsidian app running? (2) Local REST API plugin enabled, port 27124 listening? Test: `curl -k -H "Authorization: Bearer $OBSIDIAN_API_KEY" https://127.0.0.1:27124/`. (3) `mcp-obsidian` npm package present next to the wrapper -- `ls $HOME/.claude/mcp-servers/node_modules/mcp-obsidian/dist/index.js` (or the Windows equivalent under `%USERPROFILE%`). If missing, re-run the installer or `cd` into that dir and `npm install mcp-obsidian`. (4) `OBSIDIAN_API_KEY` and `OBSIDIAN_VAULT_PATH` visible to the Claude process -- Path A: same shell that launched claude; Path B: opened PowerShell *after* `setx`. |
| `obsidian-wrapper.js: could not locate mcp-obsidian` | A, B, C | npm install ran without the `mcp-obsidian` dep -- happens if you ran a pre-fix v2 installer. Fix: `cd <wrapper-dir> && npm install mcp-obsidian` (wrapper dir = `~/.claude/mcp-servers/` or `%USERPROFILE%\.claude\mcp-servers\`). |
| MCP server spawns with literal `%USERPROFILE%` in the path | B, C | You ran a pre-fix v2 installer that didn't expand placeholders. Re-run `setup.ps1 -Mode Native` (or `-Mode Desktop`) -- the new installer expands `%USERPROFILE%` at install time before writing the config. |
| MCP servers don't show up in Claude Desktop | C | Was Desktop restarted after `-Mode Desktop`? Check `%APPDATA%\Claude\claude_desktop_config.json` exists and parses (`Get-Content $env:APPDATA\Claude\claude_desktop_config.json \| ConvertFrom-Json`). |
| Skill import fails in Desktop ("invalid skill bundle") | C | Verify the `.zip` contains `SKILL.md` at its root (not nested in a subfolder). Re-run `prepare-desktop-pack.ps1`. |
| `/capture-paper` says `(PDF: no)` for everything | A, B | `university-paper-access` can't reach institutional auth. Confirm campus / VPN. Check `UNPAYWALL_EMAIL` is set. Falls back through arXiv -> Sci-Hub but the latter is often blocked. |
| `claude mcp list` shows `scihub: failed` | A, B | Sci-Hub mirror unreachable. Expected on some networks. Comment the `scihub` block out of your config if you don't want the noise. |
| `setup.sh` fails on `jq` or `rsync` | A | `sudo apt-get install -y jq rsync` and re-run. |
| `setup.ps1 -Mode Native` fails on `uv` install | B, C | Re-open PowerShell to refresh PATH; uv installs to `%USERPROFILE%\.local\bin`. Or run `irm https://astral.sh/uv/install.ps1 \| iex` manually. |
| Slow `npm install` on `/mnt/c/...` | A | Move the pack to `~/` (Linux home) and re-run. |
| Hooks don't fire | A, B | `~/.claude/settings.json` malformed. WSL: `jq . ~/.claude/settings.json`. Native: `Get-Content $env:USERPROFILE\.claude\settings.json \| ConvertFrom-Json`. |
| Statusline shows `?` for everything | B | `statusline.ps1` couldn't find your memory dir. The script falls back automatically; confirm `%USERPROFILE%\.claude\projects\` exists. |
| Captured papers don't show in `/lit-map` | A, B | `OBSIDIAN_VAULT_PATH` not visible to the Claude Code process. Path A: `echo $OBSIDIAN_VAULT_PATH` in the launching shell. Path B: open a fresh PowerShell after `setx` and verify `$env:OBSIDIAN_VAULT_PATH`. |
| Desktop deep-research seems to skip checkpoints | C | The user has prompted aggressively for an answer. The model is supposed to hold the line; if you see this, screenshot and report -- it's a regression in the lite skill. |
| `<tool_use_error>Unknown skill: deep-research</tool_use_error>` and a fallback to Claude's built-in deep-research feature | C | Pre-fix v3 build that named the skill `deep-research`, which collides with Desktop's built-in. Fix: re-run `setup.ps1 -Mode Desktop` (which now names the folder + skill `academic-deep-research`), remove the old `deep-research` skill from Desktop's Settings -> Skills, then import the regenerated `dist-desktop\academic-deep-research.zip`. Phrase requests in free text (avoid the literal phrase "deep-research") so Desktop doesn't pre-empt with the built-in. |
| `Unknown skill: academic-deep-research` (or any other pack skill) despite import succeeding | C | Two known causes: (1) **Description over 200 chars** -- Anthropic's documented hard cap; over the limit, the skill registers in `<available_skills>` but the dispatcher silently rejects it ([anthropics/claude-code#34586](https://github.com/anthropics/claude-code/issues/34586)). (2) **Wrong zip layout** -- pre-fix v3.x zips had loose `SKILL.md` at the root with no top-level folder. Desktop's importer requires exactly one top-level folder containing exactly one SKILL.md. Fix for both: re-run `setup.ps1 -Mode Desktop` (current packager wraps each skill correctly and v4 descriptions are all under 200 chars), remove every prior import from Settings -> Skills, re-import the regenerated zips, restart Desktop. |
| Skill import fails with "must contain exactly one top-level folder" or "exactly one SKILL.md" | C | Pre-fix v3.x zip layouts violated the rule (loose files at zip root, or an attempted `.claude-plugin/` bundle with multiple skills). Re-run `setup.ps1 -Mode Desktop` to regenerate the per-skill zips with the correct shape. |
| `setup.ps1` warns "Obsidian not detected" but Obsidian IS installed | A, B, C | Pre-fix v3 build only checked `%LOCALAPPDATA%\Obsidian\Obsidian.exe`, but the per-user installer drops it under `%LOCALAPPDATA%\Programs\Obsidian\`. Cosmetic -- the install proceeds. Fixed in current setup.ps1 which probes both per-user and Program Files paths. |
| `sync-check` says "Not Ready -- missing folder: .../00-Claude-Context" | C | The continuity folder hasn't been initialized. Run `python tools\research_sync_agent.py init --vault $env:OBSIDIAN_VAULT_PATH` (or re-run `setup.ps1 -Mode Desktop` after `setx OBSIDIAN_VAULT_PATH`). |
| `capture-research-state` errors with `bin/research_sync_agent.py: not found` | C | The helper wasn't bundled into the imported skill. You're on a pre-fix v3 build. Re-run `setup.ps1 -Mode Desktop` (which now copies `tools\research_sync_agent.py` into each continuity skill's `bin\` before zipping), then re-import the four `.zip`s and restart Desktop. |
| Two `session-snapshots/` files appear from the same minute | C | Concurrent snapshots from two devices. Expected -- `resume-research-state` will surface both and ask which to use. Do not delete either. |
| Continuity skill writes outside `00-Claude-Context/` | C | Skill misfire -- Operating Rules forbid this. File a regression note; verify by running `git status` in your vault if it's a repo. |
| `ingest-pdf` says "no extractable text" | C | The PDF is image-only / scanned. Run OCR with another tool first (Adobe Acrobat -> Recognize Text, or `ocrmypdf` if you have it), then re-run ingest-pdf on the OCR'd file. |
| `ingest-pdf` resolves the wrong DOI | C | Page 1 of the PDF had multiple DOIs (typically the journal master DOI plus the article DOI). Open the produced 30_Literature note and fix the `doi:` frontmatter by hand; re-run paper-capture with the corrected DOI to refresh the metadata. |
| `research-copilot` keeps asking the same question | C | The user gave a one-word reply that the skill can't disambiguate. Reply with a full sentence answering the clarifier; the loop should advance. If it doesn't, restart the chat and start with an Orient ("Where is my research?"). |
| Final draft from `academic-deep-research` is missing the `Captured N citations; M re-verified, K flagged unverified` line | C | Citation pre-flight didn't run -- likely a v3.x build. Update the pack (`git pull` + re-run `setup.ps1 -Mode Desktop`), re-import academic-deep-research, restart Desktop. |

---

## 5. Updating the pack

```powershell
PS> cd .\claude-research-pack
PS> git pull
PS> .\scripts\setup.ps1 -Mode <your mode>
```

The installers are idempotent and merge (not overwrite) `~/.claude.json`,
`%USERPROFILE%\.claude.json`, and `%APPDATA%\Claude\claude_desktop_config.json` --
your existing customizations are preserved. Backups are written to `*.bak.<timestamp>`
before any overwrite.

---

## 6. Uninstall

### Path A (WSL)

```bash
rm -rf ~/.claude/skills/{deep-research,paper-capture,lit-status,handoff}
rm -f  ~/.claude/hooks/{precompact-handoff.py,session-start-context.py,stop-persist-todos.py,statusline.sh,paper-mention-detect.py}
rm -f  ~/.claude/commands/{research.md,capture-paper.md,lit-map.md,status.md,port-to-vault.md}
rm -rf ~/.claude/mcp-servers/{Sci-Hub-MCP-Server,university-paper-access,obsidian-wrapper.js}
# Then edit ~/.claude.json and ~/.claude/settings.json by hand to remove the pack's mcpServers / hooks blocks.
```

### Path B (Native)

```powershell
PS> Remove-Item -Recurse -Force $env:USERPROFILE\.claude\skills\deep-research, `
                                  $env:USERPROFILE\.claude\skills\paper-capture, `
                                  $env:USERPROFILE\.claude\skills\lit-status, `
                                  $env:USERPROFILE\.claude\skills\handoff
PS> Remove-Item -Force $env:USERPROFILE\.claude\hooks\statusline.ps1, `
                       $env:USERPROFILE\.claude\hooks\precompact-handoff.py, `
                       $env:USERPROFILE\.claude\hooks\session-start-context.py, `
                       $env:USERPROFILE\.claude\hooks\stop-persist-todos.py, `
                       $env:USERPROFILE\.claude\hooks\paper-mention-detect.py
PS> Remove-Item -Force $env:USERPROFILE\.claude\commands\research.md, `
                       $env:USERPROFILE\.claude\commands\capture-paper.md, `
                       $env:USERPROFILE\.claude\commands\lit-map.md, `
                       $env:USERPROFILE\.claude\commands\status.md, `
                       $env:USERPROFILE\.claude\commands\port-to-vault.md
PS> Remove-Item -Recurse -Force $env:USERPROFILE\.claude\mcp-servers\Sci-Hub-MCP-Server, `
                                  $env:USERPROFILE\.claude\mcp-servers\university-paper-access
# Then edit %USERPROFILE%\.claude.json and %USERPROFILE%\.claude\settings.json by hand.
```

### Path C (Desktop)

1. Claude Desktop -> Settings -> Skills -> remove the nine imported skills:
   `academic-deep-research`, `paper-capture`, `lit-status`,
   `capture-research-state`, `resume-research-state`, `sync-check`,
   `paper-map`, `ingest-pdf`, `research-copilot`.
2. Edit `%APPDATA%\Claude\claude_desktop_config.json` to remove the pack's
   `mcpServers` entries.
3. (Optional) Remove `%USERPROFILE%\.claude\mcp-servers\` if no other Claude
   product uses those servers.

The Obsidian vault contents are untouched by uninstall -- your captured papers
and your `00-Claude-Context\` folder stay. If you want a clean slate on the
continuity layer too, delete `00-Claude-Context\` from the vault by hand.

---

## 7. Capability summary (re-check after install)

| Feature | Path A | Path B | Path C |
|---|---|---|---|
| `claude mcp list` shows 7 servers | ✅ | ✅ | (use Desktop UI) |
| `/research`, `/capture-paper`, `/lit-map`, `/status` slash commands | ✅ | ✅ | ❌ free-text |
| Hooks (handoff, todos, statusline) | ✅ | ✅ | ❌ |
| Parallel sub-agent investigators | ✅ | ✅ | ❌ |
| Independent devil's-advocate | ✅ | ✅ | ❌ -- self-critique |
| Iron Rules (no fabricated DOIs) | ✅ | ✅ | ✅ |
| Vault auto-write to `00_Inbox/` | ✅ | ✅ | ✅ |
| `paper-capture` for any read paper | ✅ | ✅ | ✅ |
| Obsidian MCP integration | ✅ | ✅ | ✅ |
| Cross-device continuity (`capture-research-state`, `resume-research-state`, `sync-check`, `paper-map`) | ❌ | ❌ | ✅ -- v3 |
| Local-PDF ingestion (`ingest-pdf`) | ❌ | ❌ | ✅ -- v4 |
| Interactive co-pilot loop (`research-copilot`) | ❌ | ❌ | ✅ -- v4 |
| Mandatory scope confirmation + citation pre-flight | ❌ | ❌ | ✅ -- v4 |

If any of the ✅ rows for your chosen path is failing, see Troubleshooting (§4).
