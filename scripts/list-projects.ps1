[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$projectsRoot = Join-Path $root "projects"
$currentPath = Join-Path $projectsRoot "CURRENT.md"
$activeSlug = $null

if (Test-Path -LiteralPath $currentPath) {
    $match = Select-String -LiteralPath $currentPath -Pattern '^\s*slug:\s*([a-z0-9][a-z0-9-]*)\s*$' |
        Select-Object -First 1
    if ($match) { $activeSlug = $match.Matches[0].Groups[1].Value }
}

Get-ChildItem -LiteralPath $projectsRoot -Directory |
    Where-Object { $_.Name -ne "_template" } |
    ForEach-Object {
        $statePath = Join-Path $_.FullName "state.json"
        $state = $null
        $warning = $null
        if (Test-Path -LiteralPath $statePath) {
            try {
                $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
                if ($state.slug -and $state.slug -ne $_.Name) {
                    $warning = "state slug '$($state.slug)' differs from directory"
                }
            }
            catch {
                $warning = "invalid state.json: $($_.Exception.Message)"
            }
        }
        else {
            $warning = "state.json missing"
        }

        [pscustomobject]@{
            Slug       = $_.Name
            Active     = ($_.Name -eq $activeSlug)
            Lifecycle  = if ($state.lifecycle) { $state.lifecycle } else { "unknown" }
            Stage      = if ($state.current_stage) { $state.current_stage } else { "unknown" }
            Mode       = if ($state.mode) { $state.mode } else { "" }
            Blocked    = if ($state.blocked) { $state.blocked | ConvertTo-Json -Compress } else { "" }
            Warning    = $warning
        }
    } |
    Sort-Object Slug
