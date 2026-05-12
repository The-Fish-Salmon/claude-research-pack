# install-mcp-servers.ps1
#
# Windows-native PowerShell equivalent of install-mcp-servers.sh.
# Idempotently installs the seven MCP servers used by the deep-research pack
# and merges the corresponding mcpServers entries into the target settings file.
#
# Run from PowerShell (not WSL):
#   PS> .\install-mcp-servers.ps1                 # default: Code-native target (%USERPROFILE%\.claude.json)
#   PS> .\install-mcp-servers.ps1 -Target Desktop # Claude Desktop target (%APPDATA%\Claude\claude_desktop_config.json)
#
# Prereqs (script verifies but does not install):
#   - Python 3.12 launcher (`py -3.12`)
#   - Node >= 20 (`node`, `npm`)
#   - Git for Windows (`git`)
#
# It installs:
#   - uv (the Python package launcher), if missing -- via official PowerShell installer
#   - arxiv-mcp-server, semanticscholar-mcp-server, paper-mcp (uv tool install)
#   - paper-search-mcp (resolved on first run via uv run --with)
#   - obsidian-wrapper.js dependencies (npm install)
#   - chrome-devtools-mcp pre-fetched via npx (paywall bypass via authenticated browser)
#
# After install:
#   - merges the appropriate template into the chosen settings file (PowerShell native JSON merge -- no jq)
#   - prints the env vars to set via `setx` for persistent install

[CmdletBinding()]
param(
    [ValidateSet('Native', 'Desktop')]
    [string]$Target = 'Native'
)

$ErrorActionPreference = 'Stop'

function Log  { param($m) Write-Host "[install] $m" -ForegroundColor Cyan }
function Warn { param($m) Write-Host "[warn] $m"    -ForegroundColor Yellow }
function Err  { param($m) Write-Host "[err] $m"     -ForegroundColor Red }

function Require-Cmd {
    param($name, $hint)
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Err "$name is required but not on PATH. $hint"
        exit 1
    }
}

# Resolve pack directory (this script lives in mcp-servers\)
$PackDir   = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$TargetDir = Join-Path $env:USERPROFILE '.claude\mcp-servers'

if ($Target -eq 'Desktop') {
    $SettingsTarget = Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'
    $TemplateName   = 'claude_desktop_config.template.json'
} else {
    $SettingsTarget = Join-Path $env:USERPROFILE '.claude.json'
    $TemplateName   = 'claude.windows.template.json'
}

New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $SettingsTarget) | Out-Null

# 0. Prereqs
Require-Cmd 'git'  'Install Git for Windows: https://git-scm.com/download/win'
Require-Cmd 'node' 'Install Node LTS: https://nodejs.org/'
Require-Cmd 'npm'  'npm ships with Node -- install Node LTS.'
if (-not (Get-Command 'py' -ErrorAction SilentlyContinue)) {
    Err 'Python launcher `py` is required. Install Python 3.12 from https://www.python.org/downloads/ (check "Add python.exe to PATH" and "Install launcher for all users").'
    exit 1
}
$pyOk = $false
try { & py -3.12 --version *> $null; if ($LASTEXITCODE -eq 0) { $pyOk = $true } } catch {}
if (-not $pyOk) { Warn 'py -3.12 not found; uv will pick up another Python. Install 3.12 if you hit version errors.' }

# 1. uv
if (-not (Get-Command 'uv' -ErrorAction SilentlyContinue)) {
    Log 'Installing uv (https://astral.sh/uv)'
    Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
    # uv installs to %USERPROFILE%\.local\bin -- make it visible for the rest of this session.
    $uvBin = Join-Path $env:USERPROFILE '.local\bin'
    if (Test-Path $uvBin) { $env:PATH = "$uvBin;$env:PATH" }
}
Require-Cmd 'uv' 'uv install failed -- check the output above and rerun.'

# Persist uv's bin dir in the user PATH so GUI apps (Claude Desktop) can find `uv` at launch.
# Claude Desktop is started from the Start menu and inherits only the *persistent* user environment --
# PATH changes made in the current PowerShell session are NOT visible to it.
$uvBin = Join-Path $env:USERPROFILE '.local\bin'
if (Test-Path $uvBin) {
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if (-not ($userPath -split ';' | Where-Object { $_ -ieq $uvBin })) {
        [Environment]::SetEnvironmentVariable('PATH', "$uvBin;$userPath", 'User')
        Log "Added $uvBin to persistent user PATH. Sign out and back in before launching Claude Desktop."
    } else {
        Log "$uvBin already in persistent user PATH."
    }
}

# 2. uv-installed MCP servers (pre-cached for faster first-run via `uv run --with`)
# NOTE: The MCP config no longer invokes these by bare command name -- it uses
# `uv run --with <pkg> <cmd>` so PATH is not required at runtime. The installs
# below are kept to pre-populate uv's cache and speed up first launch.
foreach ($pkg in @('arxiv-mcp-server', 'semanticscholar-mcp-server', 'paper-mcp')) {
    Log "Pre-caching $pkg"
    & uv tool install $pkg
    if ($LASTEXITCODE -ne 0) { Warn "$pkg install returned non-zero (may already be installed at the same version)" }
}
# paper-search-mcp is invoked via `uv run --with paper-search-mcp` so no global install needed.

# 3. chrome-devtools-mcp -- pre-fetch the npm package + create persistent profile dir.
#
# This is the paywall-bypass path. Replaces the legacy university-paper-access
# (IP-only fetch, silently saved paywall HTML on failure) and scihub (Windows
# charmap encoding bug, legally grey) servers. The user signs into their library
# proxy / publisher SSO ONCE in the persisted Chrome profile; every subsequent
# session reuses those cookies.
$ChromeProfileDir = Join-Path $env:USERPROFILE '.claude\chrome-profile'
New-Item -ItemType Directory -Force -Path $ChromeProfileDir | Out-Null
Log "Chrome profile dir at $ChromeProfileDir (persistent across sessions)"

Log 'Pre-fetching chrome-devtools-mcp (first run is slow otherwise)'
& npx -y chrome-devtools-mcp@latest --version *> $null
if ($LASTEXITCODE -ne 0) { Warn 'chrome-devtools-mcp pre-fetch returned non-zero -- check Node >= 20.19' }

# Verify Chrome stable is installed (chrome-devtools-mcp launches Chrome).
$ChromeCandidates = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)
$ChromePath = $ChromeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($ChromePath) {
    Log "Chrome detected at $ChromePath"
} else {
    Warn 'Chrome stable not found in default locations. Install from https://www.google.com/chrome/ before using the chrome-devtools MCP. (Other channels: pass --channel=canary|beta|dev to chrome-devtools-mcp.)'
}

# 4. obsidian-wrapper.js
$ObsSrc = Join-Path $PackDir 'mcp-servers\obsidian-wrapper.js'
$ObsDst = Join-Path $TargetDir 'obsidian-wrapper.js'
if (Test-Path $ObsSrc) {
    Log 'Installing obsidian-wrapper.js'
    Copy-Item -Force -Path $ObsSrc -Destination $ObsDst
    Push-Location $TargetDir
    try {
        if (-not (Test-Path 'package.json')) {
            & npm init -y *> $null
        }
        # mcp-obsidian is the actual MCP server we wrap -- required, not optional.
        & npm install --silent '@modelcontextprotocol/sdk' 'node-fetch' 'mcp-obsidian'
        if ($LASTEXITCODE -ne 0) { Warn 'npm install of obsidian wrapper deps returned non-zero' }
    } finally {
        Pop-Location
    }
} else {
    Warn 'obsidian-wrapper.js missing in pack -- skipping'
}

# 5. Merge MCP config into the chosen settings file (PowerShell native JSON merge -- no jq).
$Template = Join-Path $PackDir "settings\$TemplateName"
if (-not (Test-Path $Template)) {
    Err "MCP template not found at $Template"
    exit 1
}

Log "Merging MCP config from $TemplateName into $SettingsTarget"

# Load template and expand %FOO% placeholders at install time.
#
# WHY: Claude Code / Claude Desktop on Windows do NOT expand %VAR% when they spawn MCP
# servers via Node's child_process.spawn -- the strings are passed verbatim to the child.
# So path placeholders like "%USERPROFILE%/.claude/mcp-servers/..." would be interpreted
# literally and the spawned `uv` / `node` process would fail to find the directory.
#
# We expand here using [Environment]::ExpandEnvironmentVariables, which substitutes any
# environment variable currently set in the user's PowerShell environment. %USERPROFILE%
# is always set so paths are always resolved. Runtime env vars (PAPER_DOWNLOAD_DIR,
# OBSIDIAN_API_KEY, etc.) are NOT placed in `env: {}` blocks in the template -- they are
# inherited by the spawned MCP server from Claude Code/Desktop's parent process, which in
# turn inherits them from the user environment after `setx ... ` + sign-out / sign-in.
function Expand-EnvInTree {
    param([Parameter(Mandatory = $true)]$node)
    if ($null -eq $node) { return $null }
    if ($node -is [string]) {
        return [Environment]::ExpandEnvironmentVariables($node)
    }
    if ($node -is [System.Collections.IList]) {
        $out = @()
        foreach ($item in $node) { $out += , (Expand-EnvInTree $item) }
        return ,$out
    }
    if ($node -is [pscustomobject]) {
        foreach ($p in @($node.PSObject.Properties)) {
            $node.$($p.Name) = Expand-EnvInTree $p.Value
        }
        return $node
    }
    return $node
}

$tplRaw = Get-Content -Raw -Path $Template
$tplObj = $tplRaw | ConvertFrom-Json
$tplObj = Expand-EnvInTree $tplObj

# Strip any documentation-only `_comment_*` keys so they don't pollute the user's settings.
foreach ($p in @($tplObj.PSObject.Properties)) {
    if ($p.Name -like '_comment_*') { $tplObj.PSObject.Properties.Remove($p.Name) }
}

if (-not (Test-Path $SettingsTarget)) {
    # Brand new file -- write the template directly.
    $tplObj | ConvertTo-Json -Depth 50 | Set-Content -Path $SettingsTarget -Encoding UTF8
} else {
    $existingRaw = Get-Content -Raw -Path $SettingsTarget
    $existing    = if ([string]::IsNullOrWhiteSpace($existingRaw)) { [pscustomobject]@{} } else { $existingRaw | ConvertFrom-Json }

    if (-not $existing.PSObject.Properties.Match('mcpServers').Count) {
        $existing | Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue ([pscustomobject]@{}) -Force
    }

    foreach ($srv in $tplObj.mcpServers.PSObject.Properties) {
        # Pack entries overwrite same-named ones (matches `jq -s '.[0] * .[1]'` behavior).
        $existing.mcpServers | Add-Member -NotePropertyName $srv.Name -NotePropertyValue $srv.Value -Force
    }

    # Backup before overwrite.
    $backup = "$SettingsTarget.bak.$(Get-Date -Format yyyyMMddHHmmss)"
    Copy-Item -Force -Path $SettingsTarget -Destination $backup
    Log "Backed up existing config to $backup"

    $existing | ConvertTo-Json -Depth 50 | Set-Content -Path $SettingsTarget -Encoding UTF8
}

Log 'Done. Required env vars (run these once, then restart your shell / Claude app):'
@'

  setx PAPER_DOWNLOAD_DIR    "D:\papers"
  setx ARXIV_STORAGE_PATH    "D:\papers\arxiv"
  setx UNPAYWALL_EMAIL       "you@example.org"
  setx OBSIDIAN_VAULT_PATH   "C:\Users\<you>\Documents\MyVault"
  setx OBSIDIAN_API_KEY      "<from Obsidian Local REST API plugin>"

Note: `setx` writes to the persistent user environment but does NOT update the current
PowerShell session. Open a new PowerShell window (or sign out and back in) before
launching Claude Code / Claude Desktop so the new vars are visible.
'@ | Write-Host
