# prepare-desktop-pack.ps1 -- package desktop-skills/ as ONE Claude Desktop plugin zip.
#
# Output: dist-desktop\research-pack.zip
# Layout inside the zip (forward-slash entries):
#   .claude-plugin/plugin.json             <- plugin manifest (declares namespace)
#   skills/academic-deep-research/SKILL.md
#   skills/academic-deep-research/modes/...
#   skills/paper-capture/SKILL.md
#   ... etc., one folder per skill under skills/
#
# Why one bundled zip instead of seven per-skill zips?
#
# Our v2 prepared seven raw-SKILL.md zips (SKILL.md at zip root, no plugin
# manifest). On Claude Desktop they imported, but the loader registered them
# WITHOUT a namespace prefix; the runtime Skill registry then silently dropped
# the larger ones (academic-deep-research) so invocation returned
# `Unknown skill: academic-deep-research`. Anthropic's own skills appear under
# a real namespace (e.g. `anthropic-skills:pdf`). The plugin manifest at
# .claude-plugin/plugin.json is what declares the namespace, and Desktop's
# loader requires it for stable registration.
#
# The bundled v3 plugin namespace is `research-pack`, so skills appear in the
# runtime registry as `research-pack:academic-deep-research`,
# `research-pack:paper-capture`, etc. One Settings -> Skills -> Import gets
# the user all seven.
#
# IMPORTANT: We do NOT use Compress-Archive -- on Windows it writes entries
# with backslash separators which break Claude Desktop's importer. We use the
# .NET ZipArchive API and force forward slashes.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Info { param($m) Write-Host "[desktop-pack] $m" -ForegroundColor Cyan }
function Warn { param($m) Write-Host "[warn]         $m" -ForegroundColor Yellow }

function New-PortableZip {
    # Walk a source directory and write each file as a forward-slash zip entry.
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
                $entryName = $relPath -replace '\\', '/'
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

# Bundle the helper into each continuity skill's bin/ before zipping. Claude Desktop
# sets CLAUDE_PLUGIN_ROOT to the extracted plugin dir at runtime, so the helper
# resolves at ${CLAUDE_PLUGIN_ROOT}/skills/<name>/bin/research_sync_agent.py.
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

# Build the staging dir for the plugin zip.
$Staging = Join-Path $env:TEMP "claude-research-pack-staging"
if (Test-Path $Staging) { Remove-Item -Recurse -Force $Staging }
New-Item -ItemType Directory -Force -Path $Staging | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Staging '.claude-plugin') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Staging 'skills') | Out-Null

# Plugin manifest. The "name" field becomes the runtime namespace prefix
# ("research-pack:academic-deep-research", etc.).
$manifest = @{
    name        = 'research-pack'
    version     = '0.3.0'
    description = 'Claude research pack: literature pipeline, vault paper capture, library queries, cross-device research continuity.'
    author      = @{ name = 'claude-research-pack' }
    license     = 'CC-BY-NC-4.0'
    keywords    = @('research', 'literature', 'obsidian', 'mcp', 'continuity')
    skills      = './skills/'
}
$manifestJson = $manifest | ConvertTo-Json -Depth 5
Set-Content -Path (Join-Path $Staging '.claude-plugin\plugin.json') -Value $manifestJson -Encoding UTF8

# Copy each skill folder under staging\skills\
$skillFolders = Get-ChildItem -Path $SkillsDir -Directory
$copied = 0
foreach ($s in $skillFolders) {
    if (-not (Test-Path (Join-Path $s.FullName 'SKILL.md'))) {
        Warn "Skipping $($s.Name): no SKILL.md inside."
        continue
    }
    $dst = Join-Path $Staging "skills\$($s.Name)"
    Copy-Item -Recurse -Force -Path $s.FullName -Destination $dst
    Info "Bundled skill: $($s.Name)"
    $copied++
}

if ($copied -eq 0) {
    Warn 'No skills bundled. Nothing to zip.'
    exit 0
}

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

# Clean up old per-skill zips from the v2 layout if present.
foreach ($oldZip in @('academic-deep-research.zip','deep-research.zip','paper-capture.zip','lit-status.zip','capture-research-state.zip','resume-research-state.zip','sync-check.zip','paper-map.zip')) {
    $p = Join-Path $DistDir $oldZip
    if (Test-Path $p) {
        Remove-Item -Force $p
        Info "Removed stale v2 zip: $oldZip"
    }
}

$zipPath = Join-Path $DistDir 'research-pack.zip'
Info "Zipping $copied skills + plugin manifest -> $zipPath"
New-PortableZip -SourceDir $Staging -ZipPath $zipPath

Remove-Item -Recurse -Force $Staging | Out-Null

Info 'Done.'
@"

Next steps:
  1. Open Claude Desktop.
  2. Settings -> Skills.
  3. **Remove any previously-imported skills from this pack** (academic-deep-research,
     paper-capture, lit-status, capture-research-state, resume-research-state,
     sync-check, paper-map). The new bundle replaces them under a single plugin
     namespace, so the old standalone imports must go first or they'll conflict.
  4. Click Import. Select:
       $zipPath
     This single import installs all $copied skills under the namespace `research-pack:`.
  5. Restart Claude Desktop so the new MCP servers in
     %APPDATA%\Claude\claude_desktop_config.json take effect.

After restart, smoke-test (free text -- avoid the literal phrase "deep-research"):
  > Do an academic literature review on ion-gated transistors for reservoir computing.
  > Cite real papers from Semantic Scholar / arXiv.
"@ | Write-Host
