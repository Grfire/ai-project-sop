[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')]
    [string]$Slug
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$projectsRoot = Join-Path $root "projects"
$projectRoot = Join-Path $projectsRoot $Slug
$currentPath = Join-Path $projectsRoot "CURRENT.md"

if (-not (Test-Path -LiteralPath $projectRoot -PathType Container)) {
    throw "Project '$Slug' does not exist at '$projectRoot'."
}

$statePath = Join-Path $projectRoot "state.json"
if (Test-Path -LiteralPath $statePath) {
    try {
        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    }
    catch {
        throw "Cannot set active project: invalid '$statePath'. $($_.Exception.Message)"
    }
    if ($state.slug -and $state.slug -ne $Slug) {
        throw "Slug mismatch: argument '$Slug' but state.json says '$($state.slug)'."
    }
}

$timestamp = [DateTimeOffset]::UtcNow.ToString("o")
$content = "# CURRENT`r`n`r`nslug: $Slug`r`nupdated_at: $timestamp`r`n"
$tempPath = Join-Path $projectsRoot (".CURRENT.{0}.tmp" -f [Guid]::NewGuid().ToString("N"))
$backupPath = "$tempPath.bak"

if ($PSCmdlet.ShouldProcess($currentPath, "Atomically select project '$Slug'")) {
    try {
        [IO.File]::WriteAllText($tempPath, $content, [Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $currentPath) {
            [IO.File]::Replace($tempPath, $currentPath, $backupPath)
        }
        else {
            [IO.File]::Move($tempPath, $currentPath)
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force
        }
        if (Test-Path -LiteralPath $backupPath) {
            Remove-Item -LiteralPath $backupPath -Force
        }
    }
    if ($state.lifecycle -and $state.lifecycle -ne "active") {
        Write-Warning "Active pointer set for '$Slug' with lifecycle '$($state.lifecycle)'. Delivery writes remain blocked until set-lifecycle."
    }
}

[pscustomobject]@{
    Slug = $Slug
    CurrentPath = $currentPath
    UpdatedAt = $timestamp
    Lifecycle = if ($state -and $state.lifecycle) { [string]$state.lifecycle } else { "unknown" }
    Note = "Active pointer only; no lifecycle or gate approval changed."
}
