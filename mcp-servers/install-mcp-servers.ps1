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
#   - the Sci-Hub-MCP-Server git clone
#   - the university-paper-access server (copied from this package)
#   - obsidian-wrapper.js dependencies (npm install)
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

# 2. uv-installed MCP servers (idempotent)
foreach ($pkg in @('arxiv-mcp-server', 'semanticscholar-mcp-server', 'paper-mcp')) {
    Log "Installing $pkg"
    & uv tool install $pkg
    if ($LASTEXITCODE -ne 0) { Warn "$pkg install returned non-zero (may already be installed at the same version)" }
}
# paper-search-mcp is invoked via `uv run --with paper-search-mcp` so no global install needed.

# 3. Sci-Hub-MCP-Server (git clone)
$SciHubDir = Join-Path $TargetDir 'Sci-Hub-MCP-Server'
if (-not (Test-Path (Join-Path $SciHubDir '.git'))) {
    Log 'Cloning Sci-Hub-MCP-Server'
    & git clone https://github.com/JackKuo666/Sci-Hub-MCP-Server.git $SciHubDir
    if ($LASTEXITCODE -ne 0) { Warn 'clone failed -- set this up manually if you need scihub' }
} else {
    Log 'Sci-Hub-MCP-Server already cloned'
}

# 4. university-paper-access (copy from this package)
$UpaSrc = Join-Path $PackDir 'mcp-servers\university-paper-access'
$UpaDst = Join-Path $TargetDir 'university-paper-access'
if (Test-Path $UpaSrc) {
    Log 'Installing university-paper-access'
    New-Item -ItemType Directory -Force -Path $UpaDst | Out-Null
    Copy-Item -Recurse -Force -Path (Join-Path $UpaSrc '*') -Destination $UpaDst
} else {
    Warn 'university-paper-access source missing in pack -- skipping'
}

# 5. obsidian-wrapper.js
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

# 6. Merge MCP config into the chosen settings file (PowerShell native JSON merge -- no jq).
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
