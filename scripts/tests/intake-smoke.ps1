$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("sop-intake-smoke-" + [guid]::NewGuid())
$shell = (Get-Process -Id $PID).Path
$slug = "hist-merge-app"

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

function Assert-Equal {
  param($Expected, $Actual, [string]$Message)
  if ("$Expected" -ne "$Actual") {
    throw "$Message. Expected '$Expected', got '$Actual'."
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
  return $code
}

function Invoke-ScriptCapture {
  param([string]$File, [string[]]$Arguments)
  $output = @(& $shell -NoProfile -File $File @Arguments 2>&1 | ForEach-Object { [string]$_ })
  return [pscustomobject]@{
    code = $LASTEXITCODE
    text = ($output -join "`n")
  }
}

try {
  Assert-PowerShellSyntax @(
    (Join-Path $repoRoot "scripts\new-project.ps1"),
    (Join-Path $repoRoot "scripts\inventory-historical-project.ps1"),
    (Join-Path $repoRoot "scripts\validate-intake-artifacts.ps1"),
    (Join-Path $repoRoot "scripts\validate-supplement.ps1"),
    (Join-Path $repoRoot "scripts\update-intake-ledger.ps1"),
    (Join-Path $repoRoot "scripts\apply-supplement.ps1")
  )

  $projectsRoot = Join-Path $tempRoot "projects"
  $templateDest = Join-Path $projectsRoot "_template"
  New-Item -ItemType Directory -Force -Path $projectsRoot | Out-Null
  Copy-Item -LiteralPath (Join-Path $repoRoot "projects\_template") -Destination $templateDest -Recurse
  $copiedModules = Join-Path $templateDest "test\product\node_modules"
  if (Test-Path -LiteralPath $copiedModules) {
    Remove-Item -LiteralPath $copiedModules -Recurse -Force
  }

  $handoffDir = Join-Path $tempRoot ".cursor\skills\historical-project-onboarding\templates"
  New-Item -ItemType Directory -Force -Path $handoffDir | Out-Null
  Copy-Item -LiteralPath (Join-Path $repoRoot ".cursor\skills\historical-project-onboarding\templates\handoff.md") `
    -Destination $handoffDir

  $exit = Invoke-Script (Join-Path $repoRoot "scripts\new-project.ps1") @(
    "-Slug", $slug,
    "-Origin", "historical",
    "-SopRoot", $tempRoot,
    "-DoNotSetActive"
  )
  if ($exit -ne 0) { throw "historical new-project failed with exit $exit" }

  $projectRoot = Join-Path $projectsRoot $slug
  $intake = Join-Path $projectRoot "intake"
  $reqRoot = Join-Path $tempRoot "sibling-req\$slug"
  New-Item -ItemType Directory -Force -Path $reqRoot | Out-Null
  $statePath = Join-Path $projectRoot "state.json"
  $state = Get-Content -LiteralPath $statePath -Raw -Encoding utf8 | ConvertFrom-Json
  $state.paths.req = $reqRoot
  $state | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $statePath -Encoding utf8
  foreach ($name in @("actual-state.md", "evidence-map.md", "stage-gap-matrix.md", "supplement-plan.md")) {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $intake $name))) `
      "historical new-project must not seed $name"
  }

  $source = Join-Path $tempRoot "historical-source"
  New-Item -ItemType Directory -Force -Path $source | Out-Null
  "hello source" | Set-Content -Path (Join-Path $source "README.md") -Encoding utf8
  "notes v1" | Set-Content -Path (Join-Path $source "notes.txt") -Encoding utf8

  $exit = Invoke-Script (Join-Path $repoRoot "scripts\inventory-historical-project.ps1") @(
    "-SourcePath", $source,
    "-Slug", $slug,
    "-SopRoot", $tempRoot,
    "-MaxFiles", "50"
  )
  if ($exit -ne 0) { throw "first inventory failed with exit $exit" }

  $actual = Get-Content -Raw (Join-Path $intake "actual-state.md")
  Assert-True ($actual -notmatch "\{\{slug\}\}|\{\{source_path\}\}") "inventory must replace intake placeholders"
  Assert-True ($actual -match [regex]::Escape($slug)) "inventory must write the slug into analysis templates"
  $sopText = Get-Content -Raw (Join-Path $projectRoot "SOP.md")
  Assert-True ($sopText -match [regex]::Escape($source)) "SOP.md Historical source must index the inventoried path"
  Assert-True ($sopText -match "intake/SOURCE.md") "SOP.md Historical source must point at SOURCE.md"
  $sourceDoc = Get-Content -Raw (Join-Path $intake "SOURCE.md")
  Assert-True ($sourceDoc -match [regex]::Escape($source)) "SOURCE.md must record the source path"
  Assert-True ($sourceDoc -match "authoritative historical source") "SOURCE.md must declare itself the source record"

  $ledger = @(Import-Csv -LiteralPath (Join-Path $intake "reading-ledger.csv") -Encoding utf8)
  $readme = $ledger | Where-Object path -eq "README.md"
  Assert-Equal "pending" $readme.status "README should start pending"

  @"
# Evidence map

| ID | Fact | Source | Confidence |
|----|------|--------|------------|
| E-001 | README describes the historical root | README.md | observed |
| E-REM | Historical notes informed an earlier finding | notes.txt | observed |
| BACKFILL-REQ-001 | Canonical PRD created from intake | canonical-prd.md | observed |
"@ | Set-Content -Path (Join-Path $intake "evidence-map.md") -Encoding utf8

  $exit = Invoke-Script (Join-Path $repoRoot "scripts\update-intake-ledger.ps1") @(
    "-IntakePath", $intake,
    "-Path", "README.md",
    "-Status", "read",
    "-EvidenceIds", "E-001"
  )
  if ($exit -ne 0) { throw "update-intake-ledger failed with exit $exit" }
  $exit = Invoke-Script (Join-Path $repoRoot "scripts\update-intake-ledger.ps1") @(
    "-IntakePath", $intake,
    "-Path", "notes.txt",
    "-Status", "read",
    "-EvidenceIds", "E-001"
  )
  if ($exit -ne 0) { throw "update-intake-ledger notes failed with exit $exit" }

  $exit = Invoke-Script (Join-Path $repoRoot "scripts\inventory-historical-project.ps1") @(
    "-SourcePath", $source,
    "-Slug", $slug,
    "-SopRoot", $tempRoot,
    "-MaxFiles", "500"
  )
  if ($exit -ne 0) { throw "resume inventory failed with exit $exit" }
  $ledger = @(Import-Csv -LiteralPath (Join-Path $intake "reading-ledger.csv") -Encoding utf8)
  $readme = $ledger | Where-Object path -eq "README.md"
  Assert-Equal "read" $readme.status "unchanged README must keep read status after rerun"
  Assert-True ($readme.evidence_ids -match "E-001") "unchanged README must keep evidence_ids"
  $notes = $ledger | Where-Object path -eq "notes.txt"
  Assert-Equal "read" $notes.status "unchanged notes.txt must keep read status"

  "notes v2 changed" | Set-Content -Path (Join-Path $source "notes.txt") -Encoding utf8
  $exit = Invoke-Script (Join-Path $repoRoot "scripts\inventory-historical-project.ps1") @(
    "-SourcePath", $source,
    "-Slug", $slug,
    "-SopRoot", $tempRoot
  )
  if ($exit -ne 0) { throw "changed-file inventory failed with exit $exit" }
  $ledger = @(Import-Csv -LiteralPath (Join-Path $intake "reading-ledger.csv") -Encoding utf8)
  $readme = $ledger | Where-Object path -eq "README.md"
  Assert-Equal "read" $readme.status "unchanged README must survive a sibling content change"
  $notes = $ledger | Where-Object path -eq "notes.txt"
  Assert-Equal "pending" $notes.status "changed notes.txt must return to pending"
  Assert-Equal "" $notes.evidence_ids "changed notes.txt must clear evidence_ids"

  $exit = Invoke-Script (Join-Path $repoRoot "scripts\update-intake-ledger.ps1") @(
    "-IntakePath", $intake,
    "-Path", "notes.txt",
    "-Status", "read",
    "-EvidenceIds", "E-REM"
  )
  if ($exit -ne 0) { throw "updated notes reread failed with exit $exit" }
  $beforeRemoval = @(Import-Csv -LiteralPath (Join-Path $intake "reading-ledger.csv") -Encoding utf8) |
    Where-Object path -eq "notes.txt"
  Remove-Item -LiteralPath (Join-Path $source "notes.txt") -Force
  $exit = Invoke-Script (Join-Path $repoRoot "scripts\inventory-historical-project.ps1") @(
    "-SourcePath", $source,
    "-Slug", $slug,
    "-SopRoot", $tempRoot
  )
  if ($exit -ne 0) { throw "removed-file inventory failed with exit $exit" }
  $ledger = @(Import-Csv -LiteralPath (Join-Path $intake "reading-ledger.csv") -Encoding utf8)
  $removed = $ledger | Where-Object path -eq "notes.txt"
  Assert-Equal "removed-at-source" $removed.status "deleted source path must remain in the ledger"
  Assert-Equal $beforeRemoval.sha256 $removed.sha256 "removed source path must preserve sha256"
  Assert-Equal $beforeRemoval.evidence_ids $removed.evidence_ids "removed source path must preserve evidence_ids"
  Assert-Equal $beforeRemoval.read_at $removed.read_at "removed source path must preserve read_at"
  $manifest = Get-Content -LiteralPath (Join-Path $intake "manifest.json") -Raw -Encoding utf8 |
    ConvertFrom-Json
  Assert-Equal 1 $manifest.removed_at_source "manifest must expose removed-at-source count"
  Assert-Equal 1 $manifest.statuses.'removed-at-source' "manifest status counts must include removed-at-source"

  $proposedPlan = @"
# Supplement plan

| ID | owner_stage | canonical_target | proposed_change | status | evidence_ids | confirmed_by | confirmed_at | applied_at | notes |
|----|-------------|------------------|-----------------|--------|--------------|--------------|--------------|------------|-------|
| SUP-001 | REQ | canonical-prd.md | restore PRD | proposed | E-001 |  |  |  | owner review |
"@
  $proposedPlan | Set-Content -Path (Join-Path $intake "supplement-plan.md") -Encoding utf8
  $exit = Invoke-Script (Join-Path $repoRoot "scripts\validate-supplement.ps1") @(
    "-IntakePath", $intake,
    "-TargetStage", "REQ"
  )
  if ($exit -eq 0) { throw "TargetStage REQ must fail while SUP-001 is proposed" }

  $missingApplied = @"
# Supplement plan

| ID | owner_stage | canonical_target | proposed_change | status | evidence_ids | confirmed_by | confirmed_at | applied_at | notes |
|----|-------------|------------------|-----------------|--------|--------------|--------------|--------------|------------|-------|
| SUP-001 | REQ | canonical-prd.md | restore PRD | applied | E-001;BACKFILL-REQ-001 | tester | 2026-08-17T00:00:00Z | 2026-08-17T00:00:00Z | applied |
"@
  $missingApplied | Set-Content -Path (Join-Path $intake "supplement-plan.md") -Encoding utf8
  $exit = Invoke-Script (Join-Path $repoRoot "scripts\validate-supplement.ps1") @(
    "-IntakePath", $intake,
    "-TargetStage", "REQ"
  )
  if ($exit -eq 0) { throw "applied SUP without canonical file must fail" }

  "canonical prd" | Set-Content -Path (Join-Path $projectRoot "canonical-prd.md") -Encoding utf8
  $exit = Invoke-Script (Join-Path $repoRoot "scripts\validate-supplement.ps1") @(
    "-IntakePath", $intake,
    "-TargetStage", "REQ"
  )
  if ($exit -eq 0) { throw "same-name SOP-root pseudo target must not satisfy a sibling REQ target" }
  "canonical prd" | Set-Content -Path (Join-Path $reqRoot "canonical-prd.md") -Encoding utf8
  $exit = Invoke-Script (Join-Path $repoRoot "scripts\validate-supplement.ps1") @(
    "-IntakePath", $intake,
    "-TargetStage", "REQ"
  )
  if ($exit -ne 0) { throw "relative REQ target must resolve from state.json.paths.req" }

  $absolutePlan = $missingApplied.Replace(
    "| canonical-prd.md |",
    "| $(Join-Path $projectRoot 'canonical-prd.md') |"
  )
  $absolutePlan | Set-Content -Path (Join-Path $intake "supplement-plan.md") -Encoding utf8
  $exit = Invoke-Script (Join-Path $repoRoot "scripts\validate-supplement.ps1") @(
    "-IntakePath", $intake,
    "-TargetStage", "REQ"
  )
  if ($exit -ne 0) { throw "existing absolute canonical target must remain valid" }

  $testPlan = $missingApplied.Replace("| REQ |", "| TEST |").Replace(
    "| canonical-prd.md |",
    "| smoke-only-catalog.yaml |"
  )
  $testPlan | Set-Content -Path (Join-Path $intake "supplement-plan.md") -Encoding utf8
  "fake catalog" | Set-Content -Path (Join-Path $projectRoot "smoke-only-catalog.yaml") -Encoding utf8
  $exit = Invoke-Script (Join-Path $repoRoot "scripts\validate-supplement.ps1") @(
    "-IntakePath", $intake,
    "-TargetStage", "TEST"
  )
  if ($exit -eq 0) { throw "TEST target must not resolve from the SOP project root" }
  "test catalog" | Set-Content -Path (Join-Path $projectRoot "test\smoke-only-catalog.yaml") -Encoding utf8
  $exit = Invoke-Script (Join-Path $repoRoot "scripts\validate-supplement.ps1") @(
    "-IntakePath", $intake,
    "-TargetStage", "TEST"
  )
  if ($exit -ne 0) { throw "relative TEST target must resolve from state.json.paths.test" }

  $applyPlan = @"
# Supplement plan

| ID | owner_stage | canonical_target | proposed_change | status | evidence_ids | confirmed_by | confirmed_at | applied_at | notes |
|----|-------------|------------------|-----------------|--------|--------------|--------------|--------------|------------|-------|
| SUP-001 | REQ | pending | restore PRD | proposed | E-001 |  |  |  | owner review |
"@
  $applyPlan | Set-Content -Path (Join-Path $intake "supplement-plan.md") -Encoding utf8
  $planBeforeFailedApply = Get-Content -LiteralPath (Join-Path $intake "supplement-plan.md") -Raw
  $failedApply = Invoke-Script (Join-Path $repoRoot "scripts\apply-supplement.ps1") @(
    "-Slug", $slug,
    "-SopRoot", $tempRoot,
    "-SupplementId", "SUP-001",
    "-CanonicalTarget", "missing-canonical.md",
    "-BackfillId", "BACKFILL-REQ-001",
    "-AppliedBy", "tester",
    "-TargetStage", "REQ"
  )
  if ($failedApply -eq 0) { throw "apply-supplement must reject a missing canonical target" }
  $planAfterFailedApply = Get-Content -LiteralPath (Join-Path $intake "supplement-plan.md") -Raw
  if ($planAfterFailedApply -ne $planBeforeFailedApply) {
    throw "failed apply-supplement validation must leave supplement-plan.md unchanged"
  }
  $exit = Invoke-Script (Join-Path $repoRoot "scripts\apply-supplement.ps1") @(
    "-Slug", $slug,
    "-SopRoot", $tempRoot,
    "-SupplementId", "SUP-001",
    "-CanonicalTarget", "canonical-prd.md",
    "-BackfillId", "BACKFILL-REQ-001",
    "-AppliedBy", "tester",
    "-TargetStage", "REQ"
  )
  if ($exit -ne 0) { throw "apply-supplement closeout failed" }

  @"
# Actual state

The historical README is the current observed entry evidence (E-001). This smoke
fixture deliberately contains enough reviewed narrative to exercise completeness
validation without asserting a product gate. Runtime behavior remains unknown,
and the validator output is evidence only rather than approval.
"@ | Set-Content -Path (Join-Path $intake "actual-state.md") -Encoding utf8
  @"
# Stage gap matrix

The reviewed historical root provides only a README observation (E-001).
REQ, UI, ARCH, TEST, CODE, and DOCS owners must still evaluate their canonical
artifacts. This fixture records explicit gaps and does not infer acceptance,
readiness, lifecycle progress, or any conversational gate approval.
"@ | Set-Content -Path (Join-Path $intake "stage-gap-matrix.md") -Encoding utf8

  foreach ($stage in @("REQ", "UI", "ARCH", "TEST", "CODE", "DOCS")) {
    $handoffEvidence = if ($stage -eq "CODE") { "E-REM" } else { "E-001" }
    @"
# Historical intake handoff — $stage

## Confirmed evidence

| Evidence id | Fact | Source | Confidence |
|-------------|------|--------|------------|
| $handoffEvidence | Reviewed historical observation for validator coverage | source path | observed |

## Existing artifacts / behavior

The handoff preserves only observed evidence and records missing canonical work.

## Missing or stale items

Owner review remains required. This machine report never approves a human gate.
"@ | Set-Content -Path (Join-Path $intake "handoffs\$stage.md") -Encoding utf8
  }

  $validation = Invoke-ScriptCapture (Join-Path $repoRoot "scripts\validate-intake-artifacts.ps1") @(
    "-IntakePath", $intake
  )
  Assert-True ($validation.code -ne 0) "handoff backed only by removed source evidence must fail"
  Assert-True ($validation.text -match "backed only by a removed-at-source path") `
    "removed-source handoff failure must be explicit"

  $codeHandoffPath = Join-Path $intake "handoffs\CODE.md"
  $codeHandoff = Get-Content -LiteralPath $codeHandoffPath -Raw -Encoding utf8
  $codeHandoff.Replace("E-REM", "E-001") |
    Set-Content -LiteralPath $codeHandoffPath -Encoding utf8
  $validation = Invoke-ScriptCapture (Join-Path $repoRoot "scripts\validate-intake-artifacts.ps1") @(
    "-IntakePath", $intake
  )
  if ($validation.code -ne 0) { throw "valid intake artifacts failed: $($validation.text)" }
  Assert-True ($validation.text -match "historical evidence only") `
    "removed evidence retained in evidence-map.md must produce an explicit warning"

  $missingPython = Invoke-ScriptCapture (Join-Path $repoRoot "scripts\validate-intake-artifacts.ps1") @(
    "-IntakePath", $intake,
    "-PythonExecutable", (Join-Path $tempRoot "missing-python.exe")
  )
  Assert-True ($missingPython.code -ne 0) "missing Python must fail closed"
  Assert-True ($missingPython.text -match "schema.*mandatory|checks are mandatory") `
    "missing Python failure must explain mandatory schema checks"

  python (Join-Path $repoRoot "scripts\validate-intake-schema.py") $intake
  if ($LASTEXITCODE -ne 0) { throw "intake schema/SOURCE/placeholder validation failed" }
  $savedErrorAction = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $schemaUnavailableOutput = @(
    & python -S (Join-Path $repoRoot "scripts\validate-intake-schema.py") $intake 2>&1 |
      ForEach-Object { [string]$_ }
  )
  $schemaUnavailableCode = $LASTEXITCODE
  $ErrorActionPreference = $savedErrorAction
  Assert-Equal 3 $schemaUnavailableCode "missing jsonschema must use the unavailable dependency exit code"
  Assert-True (($schemaUnavailableOutput -join "`n") -match "jsonschema is unavailable") `
    "missing jsonschema must fail with an explicit error"

  "legacy ppt bytes" | Set-Content -Path (Join-Path $source "old.ppt") -Encoding utf8
  $exit = Invoke-Script (Join-Path $repoRoot "scripts\inventory-historical-project.ps1") @(
    "-SourcePath", $source,
    "-Slug", $slug,
    "-SopRoot", $tempRoot
  )
  if ($exit -ne 0) { throw "inventory with .ppt failed" }
  $queue = Get-Content -Raw (Join-Path $intake "conversion-queue.md")
  Assert-True ($queue -match "old\.ppt") "conversion-queue.md must list legacy .ppt"

  $xlsx = Join-Path $source "grid.xlsx"
  python -c "from openpyxl import Workbook; import sys; wb=Workbook(); wb.active['A1']='hello-xlsx'; wb.save(sys.argv[1])" $xlsx
  $extracted = Join-Path $intake "extracted\grid.xlsx.md"
  python (Join-Path $repoRoot "scripts\extract-office-text.py") $xlsx $extracted
  if ($LASTEXITCODE -ne 0) { throw "xlsx extract failed" }
  Assert-True ((Get-Content -Raw $extracted) -match "hello-xlsx") "xlsx extract must capture cell text"

  python (Join-Path $repoRoot "scripts\extract-office-text.py") (Join-Path $source "old.ppt") (Join-Path $intake "extracted\old.ppt.md")
  if ($LASTEXITCODE -ne 4) { throw "legacy .ppt must exit 4 for human conversion" }

  Write-Output "Intake smoke tests passed."
} finally {
  Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}
