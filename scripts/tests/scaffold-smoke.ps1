$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("sop-scaffold-smoke-" + [guid]::NewGuid())
$shell = (Get-Process -Id $PID).Path

function Assert-PowerShellSyntax {
  param([string[]]$Paths)
  foreach ($path in $Paths) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
      (Resolve-Path $path),
      [ref]$tokens,
      [ref]$errors
    )
    if ($errors.Count -gt 0) {
      throw "PowerShell syntax error in ${path}: $($errors[0].Message)"
    }
  }
}

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Invoke-Script {
  param([string]$File, [string[]]$Arguments)
  $output = & $shell -NoProfile -File $File @Arguments
  $code = $LASTEXITCODE
  if ($output) { $output | ForEach-Object { Write-Host $_ } }
  return @{ Code = $code; Output = ($output | Out-String) }
}

try {
  Assert-PowerShellSyntax @(
    (Join-Path $repoRoot "scripts\scaffold-sibling-stage.ps1"),
    (Join-Path $repoRoot "scripts\register-sop-validation-task.ps1")
  )

  $workflow = Join-Path $repoRoot ".github\workflows\sop-validation.yml"
  Assert-True (Test-Path -LiteralPath $workflow) "GitHub Actions workflow must exist"
  $workflowText = Get-Content -Raw $workflow
  Assert-True ($workflowText -match "run-sop-validation\.ps1") "CI workflow must invoke unified validation"
  Assert-True ($workflowText -match "windows-latest") "CI workflow must run on Windows"

  $printed = Invoke-Script (Join-Path $repoRoot "scripts\register-sop-validation-task.ps1") @(
    "-SopRoot", $repoRoot,
    "-PrintDefinition"
  )
  if ($printed.Code -ne 0) { throw "PrintDefinition failed. $($printed.Output)" }
  Assert-True ($printed.Output -match "run-sop-validation\.ps1") "task definition must point at unified validation"
  Assert-True ($printed.Output -match '"human_gate_approved"' -or $printed.Output -match "conversational") `
    "task definition must not claim gate approval"

  $slug = "scaffold-app"
  $projectsRoot = Join-Path $tempRoot "projects"
  New-Item -ItemType Directory -Force -Path $projectsRoot | Out-Null
  Copy-Item -LiteralPath (Join-Path $repoRoot "projects\_template") -Destination (Join-Path $projectsRoot "_template") -Recurse
  $copiedModules = Join-Path $projectsRoot "_template\test\product\node_modules"
  if (Test-Path -LiteralPath $copiedModules) {
    Remove-Item -LiteralPath $copiedModules -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot "vendor-templates") | Out-Null
  Copy-Item -LiteralPath (Join-Path $repoRoot "vendor-templates\req-project") `
    -Destination (Join-Path $tempRoot "vendor-templates\req-project") -Recurse
  Copy-Item -LiteralPath (Join-Path $repoRoot "vendor-templates\ui-project") `
    -Destination (Join-Path $tempRoot "vendor-templates\ui-project") -Recurse
  Copy-Item -LiteralPath (Join-Path $repoRoot "vendor-templates\arch-project") `
    -Destination (Join-Path $tempRoot "vendor-templates\arch-project") -Recurse
  Copy-Item -LiteralPath (Join-Path $repoRoot "vendor-templates\code-project") `
    -Destination (Join-Path $tempRoot "vendor-templates\code-project") -Recurse

  $created = Invoke-Script (Join-Path $repoRoot "scripts\new-project.ps1") @(
    "-Slug", $slug,
    "-SopRoot", $tempRoot,
    "-DoNotSetActive"
  )
  if ($created.Code -ne 0) { throw "new-project failed for scaffold fixture" }
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $projectsRoot "$slug\intake"))) `
    "new projects must not copy the historical INTAKE placeholder scaffold"

  $reqTarget = Join-Path $tempRoot "siblings\req\$slug"
  $first = Invoke-Script (Join-Path $repoRoot "scripts\scaffold-sibling-stage.ps1") @(
    "-Slug", $slug,
    "-Stage", "REQ",
    "-SopRoot", $tempRoot,
    "-TargetRoot", $reqTarget
  )
  if ($first.Code -ne 0) { throw "first REQ scaffold failed. $($first.Output)" }
  Assert-True (Test-Path -LiteralPath (Join-Path $reqTarget "PRD.md")) "REQ scaffold must copy PRD.md"
  $readme = Get-Content -Raw -Encoding utf8 (Join-Path $reqTarget "README.md")
  Assert-True ($readme -match [regex]::Escape($slug)) "REQ scaffold must replace project placeholders"
  Assert-True ($readme -notmatch "\{\{项目名称\}\}|\{\{project-slug\}\}") "REQ scaffold must not leave placeholders"
  Assert-True ($readme -match "state\.paths\.req") "REQ README must use the portable configured root"

  $second = Invoke-Script (Join-Path $repoRoot "scripts\scaffold-sibling-stage.ps1") @(
    "-Slug", $slug,
    "-Stage", "REQ",
    "-SopRoot", $tempRoot,
    "-TargetRoot", $reqTarget
  )
  if ($second.Code -ne 0) { throw "idempotent REQ scaffold failed. $($second.Output)" }
  Assert-True ($second.Output -match '"skipped":\s*true') "existing sibling must skip without -Force"

  foreach ($item in @(
      @{ Stage = "UI"; File = "README.md" },
      @{ Stage = "ARCH"; File = "README.md" },
      @{ Stage = "CODE"; File = "README.md" }
    )) {
    $target = Join-Path $tempRoot "siblings\$($item.Stage.ToLower())\$slug"
    $result = Invoke-Script (Join-Path $repoRoot "scripts\scaffold-sibling-stage.ps1") @(
      "-Slug", $slug,
      "-Stage", $item.Stage,
      "-SopRoot", $tempRoot,
      "-TargetRoot", $target
    )
    if ($result.Code -ne 0) { throw "$($item.Stage) scaffold failed. $($result.Output)" }
    Assert-True (Test-Path -LiteralPath (Join-Path $target $item.File)) "$($item.Stage) scaffold must copy $($item.File)"
  }

  Write-Output "Scaffold smoke tests passed."
} finally {
  Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}
