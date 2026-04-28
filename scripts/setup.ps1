# setup.ps1 -- Windows entry point for the Claude Research Pack v2 (router).
#
# Usage:
#   PS> .\scripts\setup.ps1                    # default: WSL (backward compatible with v1)
#   PS> .\scripts\setup.ps1 -Mode WSL          # bridges to WSL: runs scripts/setup.sh inside Ubuntu
#   PS> .\scripts\setup.ps1 -Mode Native       # installs Code-native pack into %USERPROFILE%\.claude\
#   PS> .\scripts\setup.ps1 -Mode Desktop      # preps Desktop pack (.zip skills + Desktop config)
#
# See INSTALL_WINDOWS.md for the decision tree on which mode to pick.

[CmdletBinding()]
param(
    [ValidateSet('WSL', 'Native', 'Desktop')]
    [string]$Mode = 'WSL'
)

$ErrorActionPreference = 'Stop'

function Info { param($m) Write-Host "[setup] $m" -ForegroundColor Cyan }
function Warn { param($m) Write-Host "[warn]  $m" -ForegroundColor Yellow }
function Fail { param($m) Write-Host "[err]   $m" -ForegroundColor Red; exit 1 }

$PackDir = (Resolve-Path "$PSScriptRoot\..").Path
Info "Mode: $Mode"
Info "Pack: $PackDir"

# ---- Common: Obsidian reminder (all three paths need it) ----
# Obsidian's per-user installer (Squirrel-style) drops the binary under
# %LOCALAPPDATA%\Programs\Obsidian\, not %LOCALAPPDATA%\Obsidian\. The
# system-wide installer puts it under %PROGRAMFILES%\Obsidian\. The Microsoft
# Store version lives under WindowsApps and we don't bother probing that.
$obsidianCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Obsidian\Obsidian.exe'),
    (Join-Path $env:LOCALAPPDATA 'Obsidian\Obsidian.exe'),
    (Join-Path $env:ProgramFiles 'Obsidian\Obsidian.exe')
)
$obsidianFound = $obsidianCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($obsidianFound) {
    Info "Obsidian found at $obsidianFound"
} else {
    Warn "Obsidian not detected at standard paths. If you've installed it, ignore this; otherwise install from https://obsidian.md and enable the 'Local REST API' community plugin."
}

switch ($Mode) {
    # ----------------------------------------------------------------------
    'WSL' {
        Info 'Path A -- bridging to WSL.'

        $wslList = & wsl --list --quiet 2>$null
        if (-not $wslList) {
            Fail "WSL is not installed. Run 'wsl --install' (admin) and re-run this script after reboot."
        }
        Info "WSL detected: $($wslList -join ', ')"

        # Convert C:\path -> /mnt/c/path
        $drive = $PackDir.Substring(0, 1).ToLower()
        $rest  = $PackDir.Substring(2).Replace('\', '/')
        $packDirWsl = "/mnt/$drive$rest"

        Info "Pack location (WSL view): $packDirWsl"
        Info 'Running scripts/setup.sh inside WSL...'

        & wsl -- bash -lc "cd '$packDirWsl' && bash scripts/setup.sh"
        if ($LASTEXITCODE -ne 0) { Fail 'WSL setup script returned non-zero -- see output above.' }

        Info 'Path A setup complete. Continue from INSTALL_WINDOWS.md (Path A) for env vars and vault bootstrap.'
    }

    # ----------------------------------------------------------------------
    'Native' {
        Info 'Path B -- installing Claude Code on Windows (native).'

        $claudePath = Get-Command claude -ErrorAction SilentlyContinue
        if (-not $claudePath) {
            Warn 'Claude Code CLI not on PATH. Install Claude Code for Windows from https://claude.ai/code first, then rerun.'
        } else {
            Info "Claude Code: $($claudePath.Path)"
        }

        $ClaudeDir = Join-Path $env:USERPROFILE '.claude'
        New-Item -ItemType Directory -Force -Path (Join-Path $ClaudeDir 'skills')   | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $ClaudeDir 'hooks')    | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $ClaudeDir 'commands') | Out-Null

        # 1. Skills (additive)
        Info "Copying skills -> $ClaudeDir\skills\"
        foreach ($s in @('deep-research', 'paper-capture', 'lit-status', 'handoff')) {
            $src = Join-Path $PackDir "skills\$s"
            if (Test-Path $src) {
                $dst = Join-Path $ClaudeDir "skills\$s"
                if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
                Copy-Item -Recurse -Force -Path $src -Destination $dst
                Info "  installed skill: $s"
            }
        }

        # 2. Hooks (Python hooks are cross-platform; statusline uses .ps1 on Windows)
        Info "Copying hooks -> $ClaudeDir\hooks\"
        foreach ($h in @('precompact-handoff.py', 'session-start-context.py', 'stop-persist-todos.py', 'paper-mention-detect.py', 'statusline.ps1')) {
            $src = Join-Path $PackDir "hooks\$h"
            if (Test-Path $src) { Copy-Item -Force -Path $src -Destination (Join-Path $ClaudeDir "hooks\$h") }
        }

        # 3. Commands
        Info "Copying slash commands -> $ClaudeDir\commands\"
        foreach ($c in @('research.md', 'capture-paper.md', 'lit-map.md', 'status.md', 'port-to-vault.md')) {
            $src = Join-Path $PackDir "commands\$c"
            if (Test-Path $src) { Copy-Item -Force -Path $src -Destination (Join-Path $ClaudeDir "commands\$c") }
        }

        # 4. MCP servers (PowerShell installer, target = Native)
        Info 'Installing MCP servers (Native target)'
        & (Join-Path $PackDir 'mcp-servers\install-mcp-servers.ps1') -Target Native
        if ($LASTEXITCODE -ne 0) { Fail 'MCP install script returned non-zero -- see output above.' }

        # 5. Merge settings.json (hooks, statusline, model) -- PowerShell native JSON merge.
        $tplPath    = Join-Path $PackDir 'settings\settings.windows.template.json'
        $targetPath = Join-Path $ClaudeDir 'settings.json'

        if (-not (Test-Path $tplPath)) { Fail "Template missing: $tplPath" }
        Info "Merging settings -> $targetPath"

        $tplObj = (Get-Content -Raw -Path $tplPath) | ConvertFrom-Json
        # Strip the underscore-prefixed comment / optional keys.
        if ($tplObj.PSObject.Properties.Match('_comment_optional_hooks').Count) { $tplObj.PSObject.Properties.Remove('_comment_optional_hooks') }
        if ($tplObj.PSObject.Properties.Match('_optional_hooks').Count)        { $tplObj.PSObject.Properties.Remove('_optional_hooks') }

        if (-not (Test-Path $targetPath)) {
            $tplObj | ConvertTo-Json -Depth 50 | Set-Content -Path $targetPath -Encoding UTF8
        } else {
            $existingRaw = Get-Content -Raw -Path $targetPath
            $existing    = if ([string]::IsNullOrWhiteSpace($existingRaw)) { [pscustomobject]@{} } else { $existingRaw | ConvertFrom-Json }

            foreach ($prop in $tplObj.PSObject.Properties) {
                # Top-level shallow merge: pack values overwrite same-named keys (matches `jq -s '.[0]*.[1]'`).
                $existing | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
            }

            $backup = "$targetPath.bak.$(Get-Date -Format yyyyMMddHHmmss)"
            Copy-Item -Force -Path $targetPath -Destination $backup
            Info "Backed up existing settings to $backup"

            $existing | ConvertTo-Json -Depth 50 | Set-Content -Path $targetPath -Encoding UTF8
        }

        Info 'Path B setup complete. Next:'
        @"

  1. Set env vars persistently (each opens in a NEW window after restart):
       setx PAPER_DOWNLOAD_DIR    "D:\papers"
       setx ARXIV_STORAGE_PATH    "D:\papers\arxiv"
       setx UNPAYWALL_EMAIL       "you@example.org"
       setx OBSIDIAN_VAULT_PATH   "C:\Users\<you>\Documents\MyVault"
       setx OBSIDIAN_API_KEY      "<from Obsidian Local REST API plugin>"

  2. Copy vault-templates\* into your Obsidian vault root (idempotent -- won't clobber existing files).

  3. Restart your shell, then in any project run:
       claude
       /status
       /research --mode quick "test query"
       /capture-paper 10.1038/s41586-021-03819-2

  See INSTALL_WINDOWS.md (Path B) for troubleshooting.
"@ | Write-Host
    }

    # ----------------------------------------------------------------------
    'Desktop' {
        Info 'Path C -- preparing Claude Desktop pack.'

        # 1. MCP servers (PowerShell installer, target = Desktop -> writes %APPDATA%\Claude\claude_desktop_config.json)
        Info 'Installing MCP servers (Desktop target)'
        & (Join-Path $PackDir 'mcp-servers\install-mcp-servers.ps1') -Target Desktop
        if ($LASTEXITCODE -ne 0) { Fail 'MCP install script returned non-zero -- see output above.' }

        # 2. Zip the desktop-skills folders for manual import via Settings -> Skills.
        Info 'Zipping desktop skills'
        & (Join-Path $PackDir 'scripts\prepare-desktop-pack.ps1')
        if ($LASTEXITCODE -ne 0) { Fail 'prepare-desktop-pack.ps1 returned non-zero -- see output above.' }

        # 3. Scaffold the cross-device research-continuity folder in the user's vault, if a vault is set.
        # This is what the four continuity skills (capture-research-state, resume-research-state,
        # sync-check, paper-map) read and write. Idempotent -- safe to re-run.
        $helper = Join-Path $PackDir 'tools\research_sync_agent.py'
        if (Test-Path $helper) {
            if ($env:OBSIDIAN_VAULT_PATH -and (Test-Path $env:OBSIDIAN_VAULT_PATH)) {
                Info "Initializing research-continuity folder in vault: $env:OBSIDIAN_VAULT_PATH"
                # PowerShell 5.1 (default on Windows) doesn't support `??`, so we resolve manually.
                $py = Get-Command 'python' -ErrorAction SilentlyContinue
                if (-not $py) { $py = Get-Command 'py' -ErrorAction SilentlyContinue }
                if ($py) {
                    $pyArgs = @($helper, 'init', '--vault', $env:OBSIDIAN_VAULT_PATH)
                    if ($py.Name -eq 'py' -or $py.Name -eq 'py.exe') { $pyArgs = @('-3.12') + $pyArgs }
                    & $py.Path @pyArgs
                    if ($LASTEXITCODE -ne 0) {
                        Warn 'research_sync_agent.py init returned non-zero -- see output above.'
                    }
                } else {
                    Warn 'Python not on PATH; skipping continuity-folder init. Run manually:'
                    Write-Host "  python `"$helper`" init --vault `"$env:OBSIDIAN_VAULT_PATH`""
                }
            } else {
                Warn 'OBSIDIAN_VAULT_PATH not set -- skipping continuity-folder init.'
                Write-Host '  After setx OBSIDIAN_VAULT_PATH and a relogin, run:'
                Write-Host "  python `"$helper`" init --vault `"<your-vault>`""
            }
        }

        Info 'Path C setup complete. Next:'
        @"

  1. Set env vars persistently -- Desktop is a GUI app, so it ONLY sees `setx` vars
     after a sign-out / sign-in (not just a new shell):
       setx PAPER_DOWNLOAD_DIR    "D:\papers"
       setx ARXIV_STORAGE_PATH    "D:\papers\arxiv"
       setx UNPAYWALL_EMAIL       "you@example.org"
       setx OBSIDIAN_VAULT_PATH   "C:\Users\<you>\Documents\MyVault"
       setx OBSIDIAN_API_KEY      "<from Obsidian Local REST API plugin>"

  2. Copy vault-templates\* into your Obsidian vault root.

  3. Open Claude Desktop -> Settings -> Skills -> Import.
     Select each .zip file under `dist-desktop\` (deep-research, paper-capture, lit-status).

  4. Restart Claude Desktop so the new MCP servers in
     %APPDATA%\Claude\claude_desktop_config.json are picked up.

  5. In a new chat, smoke-test:
       "research ion-gated transistors using deep-research, mode lit-review"
       "capture this paper: 10.1038/s41586-021-03819-2"

  IMPORTANT: Path C runs deep-research single-pass (no parallel sub-agents).
  See desktop-skills\deep-research\references\desktop_limitations.md for what
  this means for hallucination-resistance.
"@ | Write-Host
    }
}
