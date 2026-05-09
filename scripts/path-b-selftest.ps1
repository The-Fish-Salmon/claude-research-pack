# path-b-selftest.ps1 -- post-install verification for Path B (Claude Code on Windows native).
#
# Six checks. Each prints [ok] or [fail] with a one-line reason. Exit 0 if all
# green, 1 otherwise. Re-runnable any time:
#   PS> .\scripts\path-b-selftest.ps1
#
# Called automatically at the end of `setup.ps1 -Mode Native`.

$ErrorActionPreference = 'Continue'

# Windows-only guard. The script depends on %USERPROFILE% and the Obsidian
# REST API on 127.0.0.1:27124 (which only the host running Obsidian
# exposes). Running on Linux/macOS produces a noisy cascade of null-path
# errors that aren't actionable.
if (-not $IsWindows -and -not $env:USERPROFILE) {
    Write-Host "[err] path-b-selftest.ps1 is Windows-only. On Linux/macOS, run the equivalent checks by hand or use Path A's WSL setup.sh." -ForegroundColor Red
    exit 2
}

$pass = 0
$fail = 0
function Ok   { param($m) Write-Host "[ok]   $m" -ForegroundColor Green; $script:pass++ }
function Fail { param($m) Write-Host "[fail] $m" -ForegroundColor Red;   $script:fail++ }
function Warn { param($m) Write-Host "[warn] $m" -ForegroundColor Yellow }

Write-Host '== Path B self-test ==' -ForegroundColor Cyan

# 1. claude --version returns 0
$claude = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claude) {
    Fail 'claude CLI not on PATH. Install Claude Code for Windows from https://claude.ai/code'
} else {
    $ver = & claude --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Ok "claude --version -> $ver"
    } else {
        Fail "claude --version returned non-zero: $ver"
    }
}

# 2. claude mcp list shows expected servers
$expectedServers = @('arxiv', 'semantic-scholar', 'paper-search', 'paper-mcp', 'chrome-devtools', 'obsidian')
if ($claude) {
    # Join into a single string: PowerShell's -notmatch on a string array returns
    # the non-matching elements (truthy for every iteration), not a boolean.
    $mcpOut = (& claude mcp list 2>&1 | Out-String)
    $missing = @()
    foreach ($s in $expectedServers) {
        if ($mcpOut -notmatch "\b$([regex]::Escape($s))\b") { $missing += $s }
    }
    if ($missing.Count -eq 0) {
        Ok "claude mcp list shows all 6 servers"
    } else {
        Fail "claude mcp list missing servers: $($missing -join ', ')"
    }
}

# 2b. Chrome stable available (chrome-devtools-mcp launches it for paywall bypass).
$chromeCandidates = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)
$chromePath = $chromeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($chromePath) {
    Ok "Chrome detected at $chromePath (chrome-devtools-mcp will use this)"
} else {
    Warn "Chrome stable not found. chrome-devtools-mcp paywall bypass requires Chrome (https://www.google.com/chrome/) or pass --channel=canary|beta|dev."
}

# 2c. chrome-devtools-mcp persistent profile dir exists.
$chromeProfile = Join-Path $env:USERPROFILE '.claude\chrome-profile'
if (Test-Path $chromeProfile) {
    Ok "chrome-devtools profile dir exists at $chromeProfile"
} else {
    Warn "chrome-devtools profile dir missing at $chromeProfile (will be created on first use; sign into your library proxy then to bootstrap cookies)"
}

# 3. ~/.claude.json parses; mcpServers has >=6 entries
$claudeJson = Join-Path $env:USERPROFILE '.claude.json'
if (-not (Test-Path $claudeJson)) {
    Fail "~/.claude.json not found at $claudeJson"
} else {
    try {
        $obj = Get-Content -Raw -Path $claudeJson | ConvertFrom-Json
        $count = ($obj.mcpServers.PSObject.Properties | Measure-Object).Count
        if ($count -ge 6) {
            Ok "~/.claude.json has $count mcpServers entries"
        } else {
            Fail "~/.claude.json has only $count mcpServers entries (expected >=6)"
        }
    } catch {
        Fail "~/.claude.json failed to parse: $_"
    }
}

# 4. ~/.claude/settings.json parses; hooks block present
$settingsJson = Join-Path $env:USERPROFILE '.claude\settings.json'
if (-not (Test-Path $settingsJson)) {
    Fail "~/.claude/settings.json not found at $settingsJson"
} else {
    try {
        $sobj = Get-Content -Raw -Path $settingsJson | ConvertFrom-Json
        if ($sobj.PSObject.Properties.Match('hooks').Count -gt 0) {
            Ok "~/.claude/settings.json has a 'hooks' block"
        } else {
            Fail "~/.claude/settings.json has no 'hooks' block"
        }
    } catch {
        Fail "~/.claude/settings.json failed to parse: $_"
    }
}

# 5. Env vars visible to a fresh PowerShell child (i.e. persisted via setx, not just shell-local).
$probe = & powershell.exe -NoProfile -Command 'Write-Output "$env:OBSIDIAN_VAULT_PATH|$env:OBSIDIAN_API_KEY|$env:UNPAYWALL_EMAIL|$env:PAPER_DOWNLOAD_DIR"' 2>&1
$parts = $probe -split '\|'
$missingVars = @()
$names = @('OBSIDIAN_VAULT_PATH', 'OBSIDIAN_API_KEY', 'UNPAYWALL_EMAIL', 'PAPER_DOWNLOAD_DIR')
for ($i = 0; $i -lt $names.Count; $i++) {
    if (-not $parts[$i] -or $parts[$i].Trim() -eq '') { $missingVars += $names[$i] }
}
if ($missingVars.Count -eq 0) {
    Ok "all 4 required env vars visible to a fresh shell"
} else {
    Fail "env vars NOT visible to a fresh shell: $($missingVars -join ', ') -- run setx and re-open shell"
}

# 6. Obsidian Local REST API reachable with the API key
if ($env:OBSIDIAN_API_KEY) {
    try {
        $resp = Invoke-WebRequest -Uri 'https://127.0.0.1:27124/' -Headers @{ Authorization = "Bearer $env:OBSIDIAN_API_KEY" } -SkipCertificateCheck -TimeoutSec 5 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            Ok "Obsidian Local REST API reachable on 127.0.0.1:27124"
        } else {
            Fail "Obsidian REST API returned HTTP $($resp.StatusCode)"
        }
    } catch {
        # On PS 5.1, -SkipCertificateCheck doesn't exist; try a fallback path.
        try {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            $req = [System.Net.WebRequest]::Create('https://127.0.0.1:27124/')
            $req.Headers.Add("Authorization", "Bearer $env:OBSIDIAN_API_KEY")
            $req.Timeout = 5000
            $resp = $req.GetResponse()
            if ([int]$resp.StatusCode -eq 200) {
                Ok "Obsidian Local REST API reachable on 127.0.0.1:27124"
            } else {
                Fail "Obsidian REST API returned HTTP $([int]$resp.StatusCode)"
            }
            $resp.Close()
        } catch {
            Fail "Obsidian REST API not reachable: $($_.Exception.Message). Is Obsidian running with the Local REST API plugin enabled?"
        } finally {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        }
    }
} else {
    Warn 'OBSIDIAN_API_KEY not set in current shell -- skipping REST API check.'
}

Write-Host ''
Write-Host "Result: $pass passed, $fail failed." -ForegroundColor Cyan
if ($fail -eq 0) { exit 0 } else { exit 1 }
