# prepare-desktop-pack.ps1 -- package desktop-skills/ as Claude Desktop import zips.
#
# Output: dist-desktop\<skill-name>.zip (one zip per skill).
#
# Required layout per Claude Desktop's Skills importer:
#   - Each zip MUST have exactly one top-level folder.
#   - That folder MUST contain exactly one SKILL.md.
#   - Subfolders inside the skill folder (modes/, references/, templates/, bin/)
#     are fine and may contain regular .md files, but NOT another SKILL.md.
#
# So a zip looks like:
#   academic-deep-research/
#     SKILL.md
#     modes/
#     references/
#     templates/
#
# IMPORTANT: We do NOT use Compress-Archive -- on Windows it writes entries
# with backslash separators which break Claude Desktop's importer. We use the
# .NET ZipArchive API and force forward slashes.
#
# History note: an earlier v3 build of this script tried two things that BOTH
# violated the importer's rule and have now been reverted:
#   1. Loose SKILL.md at zip root (no top-level folder).
#   2. A single bundled `research-pack.zip` containing `.claude-plugin/` plus
#      `skills/<name>/SKILL.md` for all seven skills under one namespace.
# Both were rejected. The current per-skill, folder-wrapped layout is the only
# one Desktop's importer accepts.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Info { param($m) Write-Host "[desktop-pack] $m" -ForegroundColor Cyan }
function Warn { param($m) Write-Host "[warn]         $m" -ForegroundColor Yellow }

function New-SkillZip {
    # Zip a single skill folder so the resulting archive has the skill's name
    # as its single top-level folder, with SKILL.md and any subfolders inside.
    # Forward-slash entry names for cross-platform unzippers.
    param(
        [Parameter(Mandatory = $true)] [string]$SkillDir,
        [Parameter(Mandatory = $true)] [string]$ZipPath
    )

    if (Test-Path $ZipPath) { Remove-Item -Force $ZipPath }

    $skipDirs  = @('.venv', '__pycache__', 'node_modules', '.git')
    $skipFiles = @('.DS_Store', 'Thumbs.db')

    $skillFull = (Resolve-Path $SkillDir).Path.TrimEnd('\','/')
    $skillName = Split-Path -Leaf $skillFull
    $parentLen = ([System.IO.Path]::GetDirectoryName($skillFull)).Length + 1

    $zipStream = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::Create)
    try {
        $zip = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            $files = Get-ChildItem -Path $skillFull -Recurse -File -Force | Where-Object {
                $rel = $_.FullName.Substring($skillFull.Length + 1)
                $parts = $rel -split '[\\/]'
                $skipPart = $false
                foreach ($p in $parts[0..($parts.Length - 2)]) { if ($skipDirs -contains $p) { $skipPart = $true; break } }
                -not $skipPart -and ($skipFiles -notcontains $_.Name)
            }

            foreach ($f in $files) {
                # Entry path: <skill-name>/<rel-path-inside-skill>
                $relInside = $f.FullName.Substring($skillFull.Length + 1) -replace '\\', '/'
                $entryName = "$skillName/$relInside"
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
# Claude Desktop sets CLAUDE_PLUGIN_ROOT to the extracted skill directory at
# runtime, so the helper has to live INSIDE each continuity skill's folder at
# bin/. We copy tools/research_sync_agent.py into desktop-skills/<name>/bin/
# before zipping so it ends up as <skill-name>/bin/research_sync_agent.py
# inside the zip.
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

# Clean up zips from earlier v3 layouts that no longer apply.
foreach ($oldZip in @('research-pack.zip', 'deep-research.zip')) {
    $p = Join-Path $DistDir $oldZip
    if (Test-Path $p) {
        Remove-Item -Force $p
        Info "Removed stale zip from earlier layout: $oldZip"
    }
}

$skills = Get-ChildItem -Path $SkillsDir -Directory
if (-not $skills) {
    Warn 'No skill folders found under desktop-skills/. Nothing to package.'
    exit 0
}

$count = 0
foreach ($skill in $skills) {
    if (-not (Test-Path (Join-Path $skill.FullName 'SKILL.md'))) {
        Warn "Skipping $($skill.Name): no SKILL.md inside."
        continue
    }
    # Sanity: importer demands exactly one SKILL.md per zip.
    $extraSkillMd = Get-ChildItem -Path $skill.FullName -Recurse -File -Filter 'SKILL.md'
    if ($extraSkillMd.Count -gt 1) {
        Warn "Skipping $($skill.Name): contains $($extraSkillMd.Count) SKILL.md files; importer requires exactly one."
        continue
    }

    $zipPath = Join-Path $DistDir "$($skill.Name).zip"
    Info "Zipping $($skill.Name) -> $zipPath (top-level folder = $($skill.Name)/)"
    New-SkillZip -SkillDir $skill.FullName -ZipPath $zipPath
    $count++
}

Info "Done. Built $count skill zip(s) under $DistDir"
@"

Each zip has exactly one top-level folder named after the skill, with SKILL.md
inside it -- the layout Claude Desktop's importer requires.

Next steps:
  1. Open Claude Desktop -> Settings -> Skills.
  2. **If you imported any skills from this pack before** (e.g.
     academic-deep-research, deep-research, paper-capture, lit-status,
     capture-research-state, resume-research-state, sync-check, paper-map,
     or a `research-pack` plugin from an earlier v3 attempt), remove them
     all first to avoid name conflicts.
  3. Click Import. Import each .zip from $DistDir one at a time.
     There are seven: academic-deep-research, paper-capture, lit-status,
     capture-research-state, resume-research-state, sync-check, paper-map.
  4. Restart Claude Desktop so the new MCP servers in
     %APPDATA%\Claude\claude_desktop_config.json take effect.

Smoke-test (free text -- avoid the literal phrase 'deep-research'):
  > Do an academic literature review on ion-gated transistors for reservoir
  > computing. Cite real papers from Semantic Scholar / arXiv.
"@ | Write-Host
