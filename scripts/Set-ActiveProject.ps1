# Set-ActiveProject.ps1 -- helper functions for switching the active sub-project
# in a multi-project Obsidian vault.
#
# Source this file from your PowerShell profile to get Set-ActiveProject /
# Get-ActiveProject in every session. The pack's setup.ps1 (Path B) will append
# `. <pack>\scripts\Set-ActiveProject.ps1` to $PROFILE during install.
#
# Vault layout assumed:
#   $env:OBSIDIAN_VAULT_PATH\
#     10_Projects\
#       <slug>\
#         overview.md       <- frontmatter: project, status, started, goal, ...
#       <other-slug>\
#         overview.md
#
# Set-ActiveProject does two things:
#   1. Updates 10_Projects\*\overview.md frontmatter -- sets `status: active`
#      on the chosen slug, sets `status: paused` on any others currently active.
#      This is the canonical signal: the statusline hook, the handoff skill,
#      and the /status command all scan overview frontmatter to find the
#      active project, so updating frontmatter is what makes the switch real
#      across all skills.
#   2. Sets $env:ACTIVE_PROJECT (current shell) and persists via setx (next
#      session). Skills that prefer the env-var fast path read this; skills
#      that don't fall back to scanning frontmatter and end up at the same
#      answer.

function Set-ActiveProject {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Slug,

    [switch]$NoPersist,        # don't call setx; only update current shell + frontmatter
    [switch]$NoFrontmatter     # don't touch overview.md frontmatter; env-var only
  )

  $vault = $env:OBSIDIAN_VAULT_PATH
  if (-not $vault) {
    $vault = [System.Environment]::GetEnvironmentVariable('OBSIDIAN_VAULT_PATH', 'User')
  }
  if (-not $vault) {
    Write-Warning "OBSIDIAN_VAULT_PATH is not set. Set it first: setx OBSIDIAN_VAULT_PATH 'D:\path\to\vault'"
    return
  }

  $projDir = Join-Path $vault "10_Projects\$Slug"
  if (-not (Test-Path $projDir)) {
    Write-Warning "No project folder at $projDir. Create it first (mkdir + add overview.md from 70_Templates\project-overview.md), or check the slug spelling."
    return
  }

  if (-not $NoFrontmatter) {
    # Pause any project currently marked active; activate the new one.
    $projects = Get-ChildItem (Join-Path $vault '10_Projects') -Directory -ErrorAction SilentlyContinue
    foreach ($p in $projects) {
      $ovPath = Join-Path $p.FullName 'overview.md'
      if (-not (Test-Path $ovPath)) { continue }

      $content = Get-Content -Raw -Path $ovPath
      # Only touch the first occurrence in the YAML frontmatter block.
      if ($p.Name -eq $Slug) {
        $newContent = [regex]::Replace($content, '(?m)^status:\s*\w+', 'status: active', 1)
      } else {
        $newContent = [regex]::Replace($content, '(?m)^status:\s*active', 'status: paused', 1)
      }
      if ($newContent -ne $content) {
        Set-Content -Path $ovPath -Value $newContent -NoNewline:$false -Encoding UTF8
      }
    }
  }

  $env:ACTIVE_PROJECT = $Slug
  if (-not $NoPersist) {
    setx ACTIVE_PROJECT $Slug | Out-Null
  }
  Write-Host "Active project: $Slug" -ForegroundColor Cyan
  Write-Host "  Vault:        $vault" -ForegroundColor DarkGray
  Write-Host "  Project dir:  $projDir" -ForegroundColor DarkGray
  if (-not $NoFrontmatter) {
    Write-Host "  Frontmatter:  updated (status: active on $Slug, paused on others)" -ForegroundColor DarkGray
  }
  if (-not $NoPersist) {
    Write-Host "  Persistence:  setx (visible to next PowerShell / Claude Code session)" -ForegroundColor DarkGray
  }
}

function Get-ActiveProject {
  $vault = $env:OBSIDIAN_VAULT_PATH
  if (-not $vault) {
    $vault = [System.Environment]::GetEnvironmentVariable('OBSIDIAN_VAULT_PATH', 'User')
  }

  $current    = $env:ACTIVE_PROJECT
  $persistent = [System.Environment]::GetEnvironmentVariable('ACTIVE_PROJECT', 'User')

  $frontmatterActive = @()
  if ($vault -and (Test-Path (Join-Path $vault '10_Projects'))) {
    Get-ChildItem (Join-Path $vault '10_Projects') -Directory | ForEach-Object {
      $ov = Join-Path $_.FullName 'overview.md'
      if (Test-Path $ov) {
        $head = (Get-Content -Path $ov -TotalCount 30 -ErrorAction SilentlyContinue) -join "`n"
        if ($head -match '(?m)^status:\s*active') {
          $frontmatterActive += $_.Name
        }
      }
    }
  }

  [pscustomobject]@{
    CurrentSession     = $current
    Persistent         = $persistent
    Vault              = $vault
    FrontmatterActive  = ($frontmatterActive -join ', ')
  }
}
