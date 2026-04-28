# statusline.ps1 -- Windows-native equivalent of statusline.sh
#
# Output: single line, format:
#   <active-project> | review: <age> | todos: <n> | mem: <n>
#
# Path resolution (cross-user, cross-host):
#   - Memory dir: %USERPROFILE%\.claude\projects\<encoded-cwd>\memory, where
#     <encoded-cwd> is the current working directory with `\`, `:`, `/` replaced
#     by `-` (Claude Code's own encoding). Falls back to the first sibling
#     memory\ if that exact dir doesn't exist.
#   - Active project: scans $env:OBSIDIAN_VAULT_PATH\10_Projects\*\overview.md
#     for `status: active`; override with $env:ACTIVE_PROJECT.
# All fields gracefully degrade to "?" / "none" / "0" when their source is missing.

$ErrorActionPreference = 'SilentlyContinue'

$userHome = $env:USERPROFILE

# 1. Locate the memory dir.
$encodedCwd = (Get-Location).Path -replace '[\\/:]', '-'
$encodedCwd = $encodedCwd.TrimStart('-').ToLower()
$mem = Join-Path $userHome ".claude\projects\-$encodedCwd\memory"
if (-not (Test-Path $mem)) {
    $mem = (Get-ChildItem -Path (Join-Path $userHome '.claude\projects') -Filter 'memory' -Directory -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
}

# 2. Active project from vault overview frontmatter.
$proj = '?'
if ($env:OBSIDIAN_VAULT_PATH -and (Test-Path (Join-Path $env:OBSIDIAN_VAULT_PATH '10_Projects'))) {
    $slug      = $env:ACTIVE_PROJECT
    $overview  = $null

    if ($slug) {
        $candidate = Join-Path $env:OBSIDIAN_VAULT_PATH "10_Projects\$slug\overview.md"
        if (Test-Path $candidate) { $overview = $candidate }
    }
    if (-not $overview) {
        $projDirs = Get-ChildItem -Path (Join-Path $env:OBSIDIAN_VAULT_PATH '10_Projects') -Directory -ErrorAction SilentlyContinue
        foreach ($d in $projDirs) {
            $ov = Join-Path $d.FullName 'overview.md'
            if (Test-Path $ov) {
                $hit = Select-String -Path $ov -Pattern '^status:\s*active' -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($hit) { $slug = $d.Name; $overview = $ov; break }
            }
        }
    }

    if ($overview) {
        $statusLine = Select-String -Path $overview -Pattern '^status:\s*(\S+)' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($statusLine) {
            $status = $statusLine.Matches[0].Groups[1].Value
            $proj = "$slug/$status"
        } else {
            $proj = $slug
        }
    }
}

# 3. Last auto-review age.
$reviewAge = 'none'
if ($mem) {
    $reviewFile = Join-Path $mem 'review_latest.md'
    if (Test-Path $reviewFile) {
        $age = ((Get-Date) - (Get-Item $reviewFile).LastWriteTime).Days
        if ($age -ge 3) { $reviewAge = "${age}d!" } else { $reviewAge = "${age}d" }
    }
}

# 4. Carried-over todo count.
$todoN = 0
if ($mem) {
    $todoFile = Join-Path $mem 'todos_latest.md'
    if (Test-Path $todoFile) {
        $todoN = (Select-String -Path $todoFile -Pattern '^- \[' -AllMatches -ErrorAction SilentlyContinue | Measure-Object).Count
    }
}

# 5. Memory file count.
$memN = 0
if ($mem) {
    $memN = (Get-ChildItem -Path $mem -Filter '*.md' -ErrorAction SilentlyContinue | Measure-Object).Count
}

Write-Host -NoNewline "$proj | review: $reviewAge | todos: $todoN | mem: $memN"
