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

        # ---- Pre-flight: winget + auto-install missing prereqs ----
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $winget) {
            Fail "winget not on PATH. Install 'App Installer' from the Microsoft Store, then re-run this script."
        }

        # Find Claude Code. Look on PATH first; fall back to the VS Code
        # extension's bundled binary at
        # %USERPROFILE%\.vscode\extensions\anthropic.claude-code-*\resources\native-binary\claude.exe
        # When the user has only the VS Code extension installed (no separate
        # Claude Code Windows install), we add the extension's bin dir to the
        # session PATH so the rest of setup can shell out to `claude`.
        $claudePath = Get-Command claude -ErrorAction SilentlyContinue
        if (-not $claudePath) {
            $vscodeExtRoot = Join-Path $env:USERPROFILE '.vscode\extensions'
            if (Test-Path $vscodeExtRoot) {
                $vscodeClaude = Get-ChildItem -Path $vscodeExtRoot -Filter 'anthropic.claude-code-*' -Directory -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    ForEach-Object { Join-Path $_.FullName 'resources\native-binary\claude.exe' } |
                    Where-Object { Test-Path $_ } |
                    Select-Object -First 1
                if ($vscodeClaude) {
                    $claudeDir = Split-Path $vscodeClaude
                    $env:PATH  = "$claudeDir;$env:PATH"
                    Info "Claude Code: $vscodeClaude (from VS Code extension; added to session PATH)"
                    $claudePath = Get-Command claude -ErrorAction SilentlyContinue
                    Warn "VS Code extension's claude.exe is not on your persistent PATH. To use `"claude`" outside this session, either:"
                    Warn "  (a) install Claude Code for Windows separately from https://claude.ai/code, or"
                    Warn "  (b) add this dir to your user PATH:  setx PATH `"%PATH%;$claudeDir`""
                }
            }
        }
        if (-not $claudePath) {
            Fail 'Claude Code CLI not found on PATH or in the VS Code extension. Install Claude Code for Windows from https://claude.ai/code (or the VS Code Anthropic extension), then re-run this script.'
        }
        Info "Claude Code: $($claudePath.Path)"

        function Refresh-Path {
            # Pick up newly-installed tools without restarting the shell.
            $machinePath = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
            $userPath    = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
            $env:PATH = "$machinePath;$userPath"
        }

        $tools = @(
            @{ name = 'python'; wingetId = 'Python.Python.3.12'; verifyCmd = 'py' },
            @{ name = 'node';   wingetId = 'OpenJS.NodeJS.LTS';  verifyCmd = 'node' },
            @{ name = 'git';    wingetId = 'Microsoft.Git';      verifyCmd = 'git' }
        )
        foreach ($t in $tools) {
            if (Get-Command $t.verifyCmd -ErrorAction SilentlyContinue) {
                Info "$($t.name) already present"
            } else {
                Info "Installing $($t.name) via winget ($($t.wingetId))"
                & winget install -e --id $t.wingetId --accept-source-agreements --accept-package-agreements --silent
                if ($LASTEXITCODE -ne 0) {
                    Fail "winget failed to install $($t.name). Install it manually and re-run."
                }
                Refresh-Path
                if (-not (Get-Command $t.verifyCmd -ErrorAction SilentlyContinue)) {
                    Fail "$($t.name) installed but $($t.verifyCmd) still not on PATH. Open a fresh PowerShell window and re-run."
                }
            }
        }

        # ---- Wizard: detect / prompt for the five env vars ----
        Info 'Reading defaults from your existing tools and config...'

        # Default vault path: most-recent vault from Obsidian's recent-vaults file.
        $defaultVault = $null
        $obsidianJson = Join-Path $env:APPDATA 'obsidian\obsidian.json'
        if (Test-Path $obsidianJson) {
            try {
                $oj = Get-Content -Raw -Path $obsidianJson | ConvertFrom-Json
                $vaults = $oj.vaults
                $best = $null; $bestTime = 0
                foreach ($p in $vaults.PSObject.Properties) {
                    $v = $p.Value
                    if ($v.ts -and ($v.ts -gt $bestTime)) {
                        $bestTime = $v.ts
                        $best = $v.path
                    }
                }
                if ($best) { $defaultVault = $best }
            } catch { Warn "Could not parse $obsidianJson; will prompt." }
        }
        $defaultVaultDisplay = if ($defaultVault) { $defaultVault } else { (Join-Path $env:USERPROFILE 'Documents\MyVault') }

        # Default Unpaywall email: git config user.email
        $defaultEmail = ''
        try { $defaultEmail = (& git config --global user.email 2>$null).Trim() } catch {}
        if (-not $defaultEmail) { $defaultEmail = 'you@example.org' }

        # Default paper download dir: D: if it exists, else %USERPROFILE%\papers.
        $defaultPaperDir = if (Test-Path 'D:\') { 'D:\papers' } else { Join-Path $env:USERPROFILE 'papers' }

        function Prompt-WithDefault {
            param([string]$prompt, [string]$default)
            $v = Read-Host "  $prompt [$default]"
            if ([string]::IsNullOrWhiteSpace($v)) { return $default } else { return $v.Trim('"', "'") }
        }

        Write-Host '' ; Write-Host '== Configuration wizard ==' -ForegroundColor Cyan
        $vault       = Prompt-WithDefault 'Obsidian vault path' $defaultVaultDisplay
        $paperDir    = Prompt-WithDefault 'Paper download dir' $defaultPaperDir
        $arxivDir    = Prompt-WithDefault 'arXiv cache dir'   (Join-Path $paperDir 'arxiv')
        $email       = Prompt-WithDefault 'Unpaywall email'   $defaultEmail

        # API key: try the plugin's data.json first.
        $defaultKey = $null
        $apiKeyFile = Join-Path $vault '.obsidian\plugins\obsidian-local-rest-api\data.json'
        if (Test-Path $apiKeyFile) {
            try {
                $kj = Get-Content -Raw -Path $apiKeyFile | ConvertFrom-Json
                if ($kj.apiKey) { $defaultKey = $kj.apiKey }
            } catch {}
        }
        $defaultKeyDisplay = if ($defaultKey) { '<auto-detected from vault config>' } else { '<paste from Obsidian Local REST API plugin>' }
        $apiKey = Prompt-WithDefault 'Obsidian REST API key' $defaultKeyDisplay
        if ($apiKey -eq '<auto-detected from vault config>' -and $defaultKey) {
            $apiKey = $defaultKey
        }
        if ($apiKey -eq '<paste from Obsidian Local REST API plugin>') {
            Warn 'No API key set. Obsidian MCP integration will fail until you setx OBSIDIAN_API_KEY manually.'
            $apiKey = ''
        }

        # ---- Apply env vars (setx for persistence + Set-Item for current shell) ----
        Info 'Setting persistent env vars (setx) and exporting to current shell...'
        $envPairs = @(
            @{ k = 'OBSIDIAN_VAULT_PATH';  v = $vault },
            @{ k = 'OBSIDIAN_API_KEY';     v = $apiKey },
            @{ k = 'PAPER_DOWNLOAD_DIR';   v = $paperDir },
            @{ k = 'ARXIV_STORAGE_PATH';   v = $arxivDir },
            @{ k = 'UNPAYWALL_EMAIL';      v = $email }
        )
        foreach ($p in $envPairs) {
            if ($p.v) {
                & setx $p.k $p.v | Out-Null
                Set-Item -Path "Env:$($p.k)" -Value $p.v
                Info "  $($p.k) = $($p.v)"
            }
        }

        # ---- Vault bootstrap ----
        if ($vault -and (Test-Path $vault)) {
            Info "Bootstrapping vault: $vault"
            $vaultTemplates = Join-Path $PackDir 'vault-templates'
            if (Test-Path $vaultTemplates) {
                Get-ChildItem -Path $vaultTemplates | ForEach-Object {
                    $dst = Join-Path $vault $_.Name
                    if (Test-Path $dst) {
                        # Recurse into existing folders, only copy missing files.
                        Copy-Item -Recurse -Force:$false -Path "$($_.FullName)\*" -Destination $dst -ErrorAction SilentlyContinue
                    } else {
                        Copy-Item -Recurse -Force -Path $_.FullName -Destination $dst
                    }
                }
                Info '  vault-templates copied (existing files left in place)'
            } else {
                Warn 'vault-templates/ not found in pack -- skipping bootstrap'
            }

            # Configure Obsidian app.json (attachments folder)
            $appJsonPath = Join-Path $vault '.obsidian\app.json'
            New-Item -ItemType Directory -Force -Path (Split-Path $appJsonPath) | Out-Null
            $appObj = if (Test-Path $appJsonPath) {
                Get-Content -Raw -Path $appJsonPath | ConvertFrom-Json
            } else { [pscustomobject]@{} }
            $appObj | Add-Member -NotePropertyName 'attachmentFolderPath' -NotePropertyValue '80_Attachments' -Force
            $appObj | ConvertTo-Json -Depth 5 | Set-Content -Path $appJsonPath -Encoding UTF8
            Info '  Obsidian attachments folder set to 80_Attachments'

            # Configure templates plugin (core plugin)
            $templatesJsonPath = Join-Path $vault '.obsidian\templates.json'
            $tjObj = if (Test-Path $templatesJsonPath) {
                Get-Content -Raw -Path $templatesJsonPath | ConvertFrom-Json
            } else { [pscustomobject]@{} }
            $tjObj | Add-Member -NotePropertyName 'folder' -NotePropertyValue '70_Templates' -Force
            $tjObj | ConvertTo-Json -Depth 5 | Set-Content -Path $templatesJsonPath -Encoding UTF8
            Info '  Obsidian templates folder set to 70_Templates'
        } else {
            Warn "Vault path '$vault' does not exist -- skipping vault bootstrap. Create the folder, then re-run setup."
        }

        # ---- Install skills, hooks, commands ----
        $ClaudeDir = Join-Path $env:USERPROFILE '.claude'
        New-Item -ItemType Directory -Force -Path (Join-Path $ClaudeDir 'skills')   | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $ClaudeDir 'hooks')    | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $ClaudeDir 'commands') | Out-Null

        # Skills (now includes v5 ingest-pdf + research-copilot)
        Info "Copying skills -> $ClaudeDir\skills\"
        foreach ($s in @('deep-research', 'paper-capture', 'lit-status', 'handoff', 'ingest-pdf', 'research-copilot')) {
            $src = Join-Path $PackDir "skills\$s"
            if (Test-Path $src) {
                $dst = Join-Path $ClaudeDir "skills\$s"
                if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
                Copy-Item -Recurse -Force -Path $src -Destination $dst
                Info "  installed skill: $s"
            }
        }

        # Hooks (Python hooks are cross-platform; statusline uses .ps1 on Windows)
        Info "Copying hooks -> $ClaudeDir\hooks\"
        foreach ($h in @('precompact-handoff.py', 'session-start-context.py', 'stop-persist-todos.py', 'paper-mention-detect.py', 'statusline.ps1')) {
            $src = Join-Path $PackDir "hooks\$h"
            if (Test-Path $src) { Copy-Item -Force -Path $src -Destination (Join-Path $ClaudeDir "hooks\$h") }
        }

        # Commands (now includes v5 ingest-pdf + copilot)
        Info "Copying slash commands -> $ClaudeDir\commands\"
        foreach ($c in @('research.md', 'capture-paper.md', 'lit-map.md', 'status.md', 'port-to-vault.md', 'ingest-pdf.md', 'copilot.md')) {
            $src = Join-Path $PackDir "commands\$c"
            if (Test-Path $src) { Copy-Item -Force -Path $src -Destination (Join-Path $ClaudeDir "commands\$c") }
        }

        # MCP servers (PowerShell installer, target = Native)
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

        # Expand %USERPROFILE% (and any other %VAR%) in hook/statusline command strings,
        # then flip backslashes to forward slashes.
        # WHY: Claude Code on Windows runs hooks via Git Bash. Bash does not expand cmd-style
        # %VAR% placeholders, and treats unknown backslash escapes (\U \k \. \h \s) as no-ops,
        # so a raw "%USERPROFILE%\.claude\hooks\foo.py" -- or even an expanded
        # "C:\Users\kxsps\.claude\hooks\foo.py" -- arrives at Python with the backslashes
        # eaten. Forward slashes survive bash quoting and work fine for Python's open() and
        # PowerShell's -File argument on Windows.
        function Expand-EnvInTree {
            param([Parameter(Mandatory = $true)]$node)
            if ($null -eq $node)              { return $null }
            if ($node -is [string])           { return ([Environment]::ExpandEnvironmentVariables($node)) -replace '\\', '/' }
            if ($node -is [System.Collections.IList]) {
                $out = @(); foreach ($item in $node) { $out += , (Expand-EnvInTree $item) }; return ,$out
            }
            if ($node -is [pscustomobject]) {
                foreach ($p in @($node.PSObject.Properties)) { $node.$($p.Name) = Expand-EnvInTree $p.Value }
                return $node
            }
            return $node
        }
        $tplObj = Expand-EnvInTree $tplObj

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

        # ---- Self-test ----
        $selftest = Join-Path $PackDir 'scripts\path-b-selftest.ps1'
        if (Test-Path $selftest) {
            Write-Host ''
            & $selftest
            $selftestExit = $LASTEXITCODE
        } else {
            Warn "scripts\path-b-selftest.ps1 not found -- skipping self-test."
            $selftestExit = 0
        }

        Write-Host ''
        if ($selftestExit -eq 0) {
            Info 'Path B install COMPLETE.'
            @"

  Open a fresh PowerShell window (env vars need it) and try:
    claude
    /status
    /research --mode quick "ion-gated transistors"
    /ingest-pdf D:\downloads\some-paper.pdf
    /copilot
    /lit-map summary

  Re-run the self-test any time:
    .\scripts\path-b-selftest.ps1

  Troubleshooting: see INSTALL_WINDOWS.md (Path B).
"@ | Write-Host
        } else {
            Warn 'Path B install completed with self-test failures. See [fail] lines above.'
            @"

  The pack is mostly installed -- only the self-test caught issues. Common
  causes:
    - Env vars not yet visible to a fresh shell  -> open a new PowerShell window.
    - Obsidian REST API unreachable              -> launch Obsidian, enable Local REST API plugin.
    - claude mcp list missing servers            -> rerun ``setup.ps1 -Mode Native``.

  Re-run the self-test after fixing:
    .\scripts\path-b-selftest.ps1
"@ | Write-Host
        }
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
