# prepare-desktop-pack.ps1 -- package the desktop-skills/ tree as Claude Desktop import bundles.
#
# Claude Desktop installs Skills via Settings -> Skills -> Import (one .zip per skill).
# This script zips each subfolder under desktop-skills/ into dist-desktop\<name>.zip.
#
# Idempotent: existing zips are overwritten.
#
# Called automatically by `setup.ps1 -Mode Desktop`. Can also be run standalone:
#   PS> .\scripts\prepare-desktop-pack.ps1
#
# IMPORTANT: We do NOT use `Compress-Archive` here -- on Windows it writes entry
# names with backslash separators (`subdir\file.md`), which violates the ZIP spec
# (4.4.17.1: paths must use forward slashes) and is rejected by Claude Desktop's
# skill importer and many cross-platform unzippers. Instead, we use the .NET
# `ZipArchive` API directly and write entries with forward slashes.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Info { param($m) Write-Host "[desktop-pack] $m" -ForegroundColor Cyan }
function Warn { param($m) Write-Host "[warn]         $m" -ForegroundColor Yellow }

function New-PortableZip {
    # Walk a source directory and write each file as a forward-slash zip entry.
    # Skip macOS/Windows junk and hidden virtual-env / cache folders.
    param([string]$SourceDir, [string]$ZipPath)

    if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }

    $skipDirs  = @('.venv', '__pycache__', 'node_modules', '.git', '.DS_Store')
    $skipFiles = @('.DS_Store', 'Thumbs.db')

    $zipStream = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::Create)
    try {
        $zip = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            $sourceFull = (Resolve-Path $SourceDir).Path.TrimEnd('\','/')
            $files = Get-ChildItem -Path $sourceFull -Recurse -File -Force | Where-Object {
                $rel = $_.FullName.Substring($sourceFull.Length + 1)
                $parts = $rel -split '[\\/]'
                $skipPart = $false
                foreach ($p in $parts[0..($parts.Length - 2)]) { if ($skipDirs -contains $p) { $skipPart = $true; break } }
                -not $skipPart -and ($skipFiles -notcontains $_.Name)
            }

            foreach ($f in $files) {
                $relPath  = $f.FullName.Substring($sourceFull.Length + 1)
                $entryName = $relPath -replace '\\', '/'   # <- forward slashes for cross-platform unzippers
                $entry = $zip.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
                $entryStream = $entry.Open()
                try {
                    $fileStream = [System.IO.File]::OpenRead($f.FullName)
                    try { $fileStream.CopyTo($entryStream) } finally { $fileStream.Dispose() }
                } finally { $entryStream.Dispose() }
            }
        } finally { $zip.Dispose() }
    } finally { $zipStream.Dispose() }
}

$PackDir   = (Resolve-Path "$PSScriptRoot\..").Path
$SkillsDir = Join-Path $PackDir 'desktop-skills'
$DistDir   = Join-Path $PackDir 'dist-desktop'
$Helper    = Join-Path $PackDir 'tools\research_sync_agent.py'

if (-not (Test-Path $SkillsDir)) {
    Write-Host "[err] desktop-skills/ not found at $SkillsDir" -ForegroundColor Red
    exit 1
}

# The continuity skills reference ${CLAUDE_PLUGIN_ROOT}/bin/research_sync_agent.py.
# Claude Desktop sets CLAUDE_PLUGIN_ROOT to the extracted skill directory at runtime,
# so the helper has to live INSIDE each continuity skill's zip at bin/. We copy
# tools/research_sync_agent.py into desktop-skills/<name>/bin/ before zipping.
$ContinuitySkills = @('capture-research-state', 'resume-research-state', 'sync-check', 'paper-map')
if (Test-Path $Helper) {
    foreach ($s in $ContinuitySkills) {
        $skillDir = Join-Path $SkillsDir $s
        if (Test-Path (Join-Path $skillDir 'SKILL.md')) {
            $binDir = Join-Path $skillDir 'bin'
            New-Item -ItemType Directory -Force -Path $binDir | Out-Null
            Copy-Item -Force -Path $Helper -Destination (Join-Path $binDir 'research_sync_agent.py')
            Info "Bundled helper into $s\bin\research_sync_agent.py"
        }
    }
} else {
    Warn "tools\research_sync_agent.py not found -- continuity skills will fall back to in-context schema walking."
}

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

$skills = Get-ChildItem -Path $SkillsDir -Directory
if (-not $skills) {
    Warn 'No skill folders found under desktop-skills/. Nothing to package.'
    exit 0
}

foreach ($skill in $skills) {
    $skillMd = Join-Path $skill.FullName 'SKILL.md'
    if (-not (Test-Path $skillMd)) {
        Warn "Skipping $($skill.Name): no SKILL.md inside."
        continue
    }

    $zipPath = Join-Path $DistDir "$($skill.Name).zip"
    Info "Zipping $($skill.Name) -> $zipPath (forward-slash entries)"
    New-PortableZip -SourceDir $skill.FullName -ZipPath $zipPath
}

Info 'Done.'
@"

Next steps:
  1. Open Claude Desktop.
  2. Settings -> Skills -> Import.
  3. Import each .zip file from:
       $DistDir
  4. Restart Claude Desktop so the new MCP servers in
     %APPDATA%\Claude\claude_desktop_config.json take effect.
"@ | Write-Host
