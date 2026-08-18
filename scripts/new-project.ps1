[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')]
    [string]$Slug,
    [ValidateSet("new", "historical")]
    [string]$Origin = "new",
    [string]$SopRoot,
    [switch]$DoNotSetActive
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\project-state.ps1")
$root = if (-not [string]::IsNullOrWhiteSpace($SopRoot)) {
    (Resolve-Path -LiteralPath $SopRoot).Path
} else {
    Split-Path $PSScriptRoot -Parent
}
$projectsRoot = Join-Path $root "projects"
$templateRoot = Join-Path $projectsRoot "_template"
$projectRoot = Join-Path $projectsRoot $Slug
$tempRoot = Join-Path $projectsRoot (".new-{0}-{1}" -f $Slug, [Guid]::NewGuid().ToString("N"))

if (-not (Test-Path -LiteralPath $templateRoot -PathType Container)) {
    throw "Project template is missing: $templateRoot"
}
if (Test-Path -LiteralPath $projectRoot) {
    throw "Project already exists: $projectRoot"
}

if ($PSCmdlet.ShouldProcess($projectRoot, "Create initialized SOP project")) {
    try {
        Copy-Item -LiteralPath $templateRoot -Destination $tempRoot -Recurse

        # Dependencies are installed per environment, never copied as project state.
        $templateDependencies = Join-Path $tempRoot "test\product\node_modules"
        if (Test-Path -LiteralPath $templateDependencies) {
            Remove-Item -LiteralPath $templateDependencies -Recurse -Force
        }

        Get-ChildItem -LiteralPath $tempRoot -Recurse -File |
            Where-Object { $_.Extension -in @(".md", ".json", ".yaml", ".yml", ".csv", ".ps1") } |
            ForEach-Object {
                $content = [IO.File]::ReadAllText($_.FullName)
                if ($content.Contains("{{project-slug}}")) {
                    [IO.File]::WriteAllText(
                        $_.FullName,
                        $content.Replace("{{project-slug}}", $Slug),
                        [Text.UTF8Encoding]::new($false)
                    )
                }
            }

        $intakeRoot = Join-Path $tempRoot "intake"
        if ($Origin -eq "new") {
            # INTAKE belongs only to existing/historical project onboarding.
            if (Test-Path -LiteralPath $intakeRoot) {
                Remove-Item -LiteralPath $intakeRoot -Recurse -Force
            }
        } else {
            # Inventory seeds analysis templates with {{slug}}/{{source_path}}.
            # Copying them here would freeze unresolved placeholders.
            foreach ($name in @(
                "actual-state.md",
                "evidence-map.md",
                "stage-gap-matrix.md",
                "supplement-plan.md"
            )) {
                $seeded = Join-Path $intakeRoot $name
                if (Test-Path -LiteralPath $seeded) {
                    Remove-Item -LiteralPath $seeded -Force
                }
            }
        }

        $statePath = Join-Path $tempRoot "state.json"
        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        $state | Add-Member -NotePropertyName origin -NotePropertyValue $Origin -Force
        if ($Origin -eq "historical") {
            $state.current_stage = "INTAKE"
            $state.stage_status.INTAKE = "in_progress"
            $state.stage_status.REQ = "not_started"
        }
        $state.timestamps.updated_at = [DateTimeOffset]::UtcNow.ToString("o")
        [void](Write-CanonicalState -Path $statePath -Slug $Slug -State $state -RepoRoot $root)

        $sopPath = Join-Path $tempRoot "SOP.md"
        $sop = [IO.File]::ReadAllText($sopPath)
        $sop = $sop.Replace("| Project origin | new / historical |", "| Project origin | $Origin |")
        if ($Origin -eq "historical") {
            $sop = $sop.Replace("| Current stage | REQ |", "| Current stage | INTAKE |")
            $sop = $sop.Replace("| INTAKE | na | |", "| INTAKE | in_progress | |")
            $sop = $sop.Replace("| REQ | in_progress | |", "| REQ | not_started | |")
        }
        [IO.File]::WriteAllText($sopPath, $sop, [Text.UTF8Encoding]::new($false))

        [IO.Directory]::Move($tempRoot, $projectRoot)
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }

    if (-not $DoNotSetActive) {
        & (Join-Path $PSScriptRoot "set-active-slug.ps1") -Slug $Slug | Out-Null
    }
}

[pscustomobject]@{
    Slug = $Slug
    Origin = $Origin
    ProjectRoot = $projectRoot
    Active = (-not $DoNotSetActive)
    Note = "Template placeholders initialized; no human gate was approved."
}
