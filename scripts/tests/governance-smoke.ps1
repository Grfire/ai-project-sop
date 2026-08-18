$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("sop-governance-smoke-" + [guid]::NewGuid())
$shell = (Get-Process -Id $PID).Path
$slug = "gov-app"

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

function Assert-SopTimestamp {
  param(
    [string]$SopText,
    [string]$Field,
    $StateValue,
    [string]$Message
  )
  $match = [regex]::Match(
    $SopText,
    "(?m)^\|[ \t]*$([regex]::Escape($Field))[ \t]*\|[ \t]*([^|]+?)[ \t]*\|[ \t]*\r?$"
  )
  if (-not $match.Success) { throw "$Message. SOP row is missing or empty." }
  $stateInstant = [DateTimeOffset]$StateValue
  $sopInstant = [DateTimeOffset]$match.Groups[1].Value.Trim()
  if ($stateInstant.ToUniversalTime() -ne $sopInstant.ToUniversalTime()) {
    throw "$Message. State='$StateValue', SOP='$($match.Groups[1].Value.Trim())'."
  }
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
    (Join-Path $repoRoot "scripts\lib\project-state.ps1"),
    (Join-Path $repoRoot "scripts\set-lifecycle.ps1"),
    (Join-Path $repoRoot "scripts\record-gate.ps1"),
    (Join-Path $repoRoot "scripts\apply-gate-reset.ps1"),
    (Join-Path $repoRoot "scripts\touch-code-change.ps1"),
    (Join-Path $repoRoot "scripts\record-cancellation.ps1"),
    (Join-Path $repoRoot "scripts\write-governance.ps1")
  )

  $projectsRoot = Join-Path $tempRoot "projects"
  $templateDest = Join-Path $projectsRoot "_template"
  New-Item -ItemType Directory -Force -Path $projectsRoot | Out-Null
  Copy-Item -LiteralPath (Join-Path $repoRoot "projects\_template") -Destination $templateDest -Recurse
  $copiedModules = Join-Path $templateDest "test\product\node_modules"
  if (Test-Path -LiteralPath $copiedModules) {
    Remove-Item -LiteralPath $copiedModules -Recurse -Force
  }

  $created = Invoke-Script (Join-Path $repoRoot "scripts\new-project.ps1") @(
    "-Slug", $slug,
    "-SopRoot", $tempRoot,
    "-DoNotSetActive"
  )
  if ($created.Code -ne 0) { throw "new-project failed" }

  $statePath = Join-Path $tempRoot "projects\$slug\state.json"
  python (Join-Path $repoRoot "scripts\validate-json-schema.py") `
    (Join-Path $repoRoot "schemas\state.schema.json") $statePath
  if ($LASTEXITCODE -ne 0) { throw "new-project state.json failed schema validation" }

  $state = Get-Content -Raw $statePath | ConvertFrom-Json
  Assert-Equal "new" $state.origin "origin must be recorded"
  python -c "import json,sys; d=json.load(open(sys.argv[1],encoding='utf-8')); assert isinstance(d['governance']['regulated_data'], list); assert isinstance(d['governance']['active_waiver_ids'], list)" $statePath
  if ($LASTEXITCODE -ne 0) { throw "new-project must serialize governance arrays as JSON arrays" }

  $migrateSlug = "gov-migrate-app"
  $migrateCreated = Invoke-Script (Join-Path $repoRoot "scripts\new-project.ps1") @(
    "-Slug", $migrateSlug,
    "-SopRoot", $tempRoot,
    "-DoNotSetActive"
  )
  if ($migrateCreated.Code -ne 0) { throw "migration fixture new-project failed" }
  $migrateStatePath = Join-Path $tempRoot "projects\$migrateSlug\state.json"
  $legacyState = @{
    slug = $migrateSlug
    current_stage = "REQ"
  } | ConvertTo-Json
  Set-Content -LiteralPath $migrateStatePath -Value $legacyState -Encoding utf8
  $migrated = Invoke-Script (Join-Path $repoRoot "scripts\write-governance.ps1") @(
    "-Slug", $migrateSlug, "-SopRoot", $tempRoot,
    "-DataClassification", "internal",
    "-ComplianceOwner", "owner-a"
  )
  if ($migrated.Code -ne 0) { throw "legacy state migration via write-governance failed. $($migrated.Output)" }
  python (Join-Path $repoRoot "scripts\validate-json-schema.py") `
    (Join-Path $repoRoot "schemas\state.schema.json") $migrateStatePath
  if ($LASTEXITCODE -ne 0) { throw "migrated state.json failed schema validation" }
  $migratedState = Get-Content -Raw $migrateStatePath | ConvertFrom-Json
  foreach ($name in @("updated_at", "last_code_change_at", "last_regression_at", "intake_completed_at", "test_pack_at", "docs_completed_at", "lifecycle_changed_at")) {
    Assert-True ($null -ne $migratedState.timestamps.PSObject.Properties[$name]) "migrated timestamps must include $name"
  }
  Assert-True ($null -eq $migratedState.blocked -or $migratedState.blocked -is [pscustomobject]) "blocked must be null or object after migration"
  Assert-True ($null -ne $migratedState.approval_refs) "approval_refs must exist after migration"

  $touchWithoutDialogue = Invoke-Script (Join-Path $repoRoot "scripts\touch-code-change.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot
  )
  if ($touchWithoutDialogue.Code -eq 0) {
    throw "touch-code-change must require DecisionMaker, ConfirmationQuote, and Reason"
  }

  $noQuote = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "REQ_SIGNOFF", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", " "
  )
  if ($noQuote.Code -eq 0) { throw "record-gate must require a confirmation quote" }

  $uiFirst = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "UI_SIGNOFF", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "approve UI"
  )
  if ($uiFirst.Code -eq 0) { throw "UI_SIGNOFF before REQ_SIGNOFF must fail" }

  $reqBare = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "REQ_SIGNOFF", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "approve REQ"
  )
  if ($reqBare.Code -eq 0) { throw "REQ_SIGNOFF without governance fields must fail" }

  $gov = Invoke-Script (Join-Path $repoRoot "scripts\write-governance.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-DataClassification", "internal",
    "-ComplianceOwner", "owner-a",
    "-RegulatedData", "none"
  )
  if ($gov.Code -ne 0) { throw "write-governance failed" }

  $reqOk = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "REQ_SIGNOFF", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "I confirm REQ_SIGNOFF",
    "-Evidence", "PRD 已定稿 + governance fields"
  )
  if ($reqOk.Code -ne 0) { throw "REQ_SIGNOFF with governance should record. $($reqOk.Output)" }
  Assert-True ($reqOk.Output -match '"human_gate_approved":\s*false') "record-gate must not claim human approval"
  $state = Get-Content -Raw $statePath | ConvertFrom-Json
  Assert-Equal "approved" $state.stage_status.REQ "REQ status cache should be approved"
  Assert-True ([string]$state.approval_refs.REQ_SIGNOFF -match '^APR-') "approval_refs.REQ_SIGNOFF required"

  $intakeOk = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "INTAKE_COMPLETE", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "I confirm INTAKE_COMPLETE"
  )
  if ($intakeOk.Code -ne 0) { throw "INTAKE_COMPLETE should record. $($intakeOk.Output)" }
  $packEarly = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "TEST_PACK_READY", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "I confirm TEST_PACK_READY"
  )
  if ($packEarly.Code -eq 0) { throw "TEST_PACK_READY before ARCH_SIGNOFF must fail" }
  $docsEarly = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "DOCS_COMPLETE", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "I confirm DOCS_COMPLETE"
  )
  if ($docsEarly.Code -eq 0) { throw "DOCS_COMPLETE before REGRESSION_PASS must fail" }
  $state = Get-Content -Raw $statePath | ConvertFrom-Json
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$state.timestamps.intake_completed_at)) "INTAKE_COMPLETE must stamp intake_completed_at"
  $sopText = Get-Content -Raw (Join-Path $tempRoot "projects\$slug\SOP.md")
  Assert-SopTimestamp $sopText "intake_completed_at" $state.timestamps.intake_completed_at "SOP.md must mirror intake_completed_at"

  $codeEarly = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "CODE_READY", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "approve CODE_READY"
  )
  if ($codeEarly.Code -eq 0) { throw "CODE_READY before TEST_PACK_READY must fail" }

  $uiWaive = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "UI_SIGNOFF", "-Decision", "waived",
    "-Approver", "tester", "-ConfirmationQuote", "waive UI",
    "-WaiverReason", "try to complete UI without PRD",
    "-RiskOwner", "tester", "-Expiry", "never"
  )
  if ($uiWaive.Code -eq 0) { throw "UI_SIGNOFF cannot be waived to completion" }

  $archCompleteMode = Invoke-Script (Join-Path $repoRoot "scripts\write-governance.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot, "-UiInputMode", "complete"
  )
  if ($archCompleteMode.Code -ne 0) { throw "write-governance complete ui_input_mode failed" }
  $archBeforeUi = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "ARCH_SIGNOFF", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "approve ARCH before UI"
  )
  if ($archBeforeUi.Code -eq 0) { throw "ARCH_SIGNOFF ui_input_mode=complete requires UI_SIGNOFF" }

  $uiOk = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "UI_SIGNOFF", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "I confirm UI_SIGNOFF"
  )
  if ($uiOk.Code -ne 0) { throw "UI_SIGNOFF after REQ_SIGNOFF should record" }

  $archBare = Invoke-Script (Join-Path $repoRoot "scripts\write-governance.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot, "-UiInputMode", "none"
  )
  if ($archBare.Code -ne 0) { throw "write-governance ui_input_mode failed" }
  $archNoWaiver = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "ARCH_SIGNOFF", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "approve ARCH"
  )
  if ($archNoWaiver.Code -eq 0) { throw "ARCH_SIGNOFF partial/none without waiver must fail" }

  $archWaiver = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "ARCH_SIGNOFF", "-Decision", "waived",
    "-Approver", "tester", "-ConfirmationQuote", "waive missing UI for ARCH",
    "-WaiverReason", "no UI in this slice",
    "-RiskOwner", "architect",
    "-Expiry", "next UI_SIGNOFF"
  )
  if ($archWaiver.Code -ne 0) { throw "ARCH waiver should record. $($archWaiver.Output)" }

  $sopPath = Join-Path $tempRoot "projects\$slug\SOP.md"
  $escapedSop = (Get-Content -LiteralPath $sopPath -Raw) -replace `
    '(?m)^\|\s*ARCH\s*\|[^\r\n]+\r?$', '| ARCH | not_started | `ui_input_mode=complete\|partial\|none` |'
  Set-Content -LiteralPath $sopPath -Value $escapedSop -Encoding utf8
  $archOk = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "ARCH_SIGNOFF", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "I confirm ARCH_SIGNOFF"
  )
  if ($archOk.Code -ne 0) { throw "ARCH_SIGNOFF with ui_input_mode=none and waiver should record. $($archOk.Output)" }
  $sopAfterArch = Get-Content -LiteralPath $sopPath -Raw
  Assert-True ($sopAfterArch -match '(?m)^\|\s*ARCH\s*\|\s*approved\s*\|') "Update-SopStageRow must handle escaped pipes in ARCH note"

  $packOk = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "TEST_PACK_READY", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "I confirm TEST_PACK_READY"
  )
  if ($packOk.Code -ne 0) { throw "TEST_PACK_READY after ARCH_SIGNOFF should record. $($packOk.Output)" }
  $state = Get-Content -Raw $statePath | ConvertFrom-Json
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$state.timestamps.test_pack_at)) "TEST_PACK_READY must stamp test_pack_at"
  Assert-Equal "packaging" $state.mode "TEST_PACK_READY must set packaging mode"

  $codeStamp = "2026-08-17T00:00:00Z"
  $touchBeforeCode = Invoke-Script (Join-Path $repoRoot "scripts\touch-code-change.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot, "-Timestamp", $codeStamp,
    "-DecisionMaker", "tester",
    "-ConfirmationQuote", "record initial runtime code change",
    "-Reason", "initial implementation fixture"
  )
  if ($touchBeforeCode.Code -ne 0) { throw "touch-code-change fixture failed" }
  Assert-True ($touchBeforeCode.Output -match '"human_gate_approved":\s*false') `
    "touch-code-change must not claim human approval"
  $codeOk = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "CODE_READY", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "I confirm CODE_READY"
  )
  if ($codeOk.Code -ne 0) { throw "CODE_READY after TEST_PACK_READY should record. $($codeOk.Output)" }
  $state = Get-Content -Raw $statePath | ConvertFrom-Json
  $oldCodeRef = [string]$state.approval_refs.CODE_READY
  Assert-True ($oldCodeRef -match '^APR-') "CODE_READY approval ref must be cached"

  $rejected = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "CODE_READY", "-Decision", "rejected",
    "-Approver", "tester", "-ConfirmationQuote", "reject CODE_READY",
    "-Evidence", "slice not ready"
  )
  if ($rejected.Code -ne 0) { throw "CODE_READY rejected should record. $($rejected.Output)" }
  $state = Get-Content -Raw $statePath | ConvertFrom-Json
  Assert-Equal "CODE_READY" $state.blocked.gate_id "rejected gate must write blocked.gate_id"
  Assert-Equal "研发工程师" $state.blocked.owner_role "rejected gate must write blocked.owner_role"
  Assert-True (-not $state.approval_refs.CODE_READY) "rejected gate must remove its old approval_ref"
  Assert-True (-not ((Get-Content -Raw $statePath) -match [regex]::Escape($oldCodeRef))) "old CODE_READY ref must not remain in state"

  $lastRunPath = Join-Path $tempRoot "projects\$slug\test\last-run.json"
  $lastRun = [ordered]@{
    schema_version = 1
    slug = $slug
    mode = "full"
    started_at = "2026-08-17T00:30:00Z"
    finished_at = "2026-08-17T01:00:00Z"
    freshness = [ordered]@{
      last_code_change_at = $codeStamp
      regression_started_after_code_change = $true
    }
    overall = "PASS"
  }
  $lastRun | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $lastRunPath -Encoding utf8
  $regressionWithRejectedCode = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "REGRESSION_PASS", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "approve stale dependent regression"
  )
  if ($regressionWithRejectedCode.Code -eq 0) { throw "old CODE_READY ref must not bypass REGRESSION_PASS prerequisite" }

  $codeReapproved = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "CODE_READY", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "I reconfirm CODE_READY"
  )
  if ($codeReapproved.Code -ne 0) { throw "CODE_READY reapproval should record" }
  $lastRun.mode = "code-only"
  $lastRun | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $lastRunPath -Encoding utf8
  $partialRegression = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "REGRESSION_PASS", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "approve partial regression"
  )
  if ($partialRegression.Code -eq 0) { throw "REGRESSION_PASS must reject non-full mode evidence" }
  $lastRun.mode = "full"
  $lastRun | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $lastRunPath -Encoding utf8
  $regressionOk = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "REGRESSION_PASS", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "I confirm REGRESSION_PASS"
  )
  if ($regressionOk.Code -ne 0) { throw "fresh full REGRESSION_PASS should record. $($regressionOk.Output)" }

  $docsRoot = Join-Path $tempRoot "projects\$slug\docs"
  @"
| Type | Latest output | Style card | Sources | Source revision | Output revision | Stale |
|------|---------------|------------|---------|-----------------|-----------------|-------|
"@ | Set-Content -LiteralPath (Join-Path $docsRoot "registry.md") -Encoding utf8
  $docsOk = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "DOCS_COMPLETE", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "I confirm DOCS_COMPLETE"
  )
  if ($docsOk.Code -ne 0) { throw "DOCS_COMPLETE with validator evidence should record. $($docsOk.Output)" }
  $state = Get-Content -Raw $statePath | ConvertFrom-Json
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$state.timestamps.docs_completed_at)) "DOCS_COMPLETE must stamp docs_completed_at"

  $runtimeTouchRoot = Join-Path $tempRoot "runtime-touch-root"
  New-Item -ItemType Directory -Force -Path (Join-Path $runtimeTouchRoot "projects") | Out-Null
  Copy-Item -LiteralPath (Join-Path $tempRoot "projects\$slug") `
    -Destination (Join-Path $runtimeTouchRoot "projects\$slug") -Recurse
  $runtimeTouchStatePath = Join-Path $runtimeTouchRoot "projects\$slug\state.json"
  $beforeRuntimeTouch = Get-Content -LiteralPath $runtimeTouchStatePath -Raw | ConvertFrom-Json
  $oldRuntimeCodeRef = [string]$beforeRuntimeTouch.approval_refs.CODE_READY
  $oldRuntimeRegressionRef = [string]$beforeRuntimeTouch.approval_refs.REGRESSION_PASS
  $oldRuntimeDocsRef = [string]$beforeRuntimeTouch.approval_refs.DOCS_COMPLETE
  $runtimeTouch = Invoke-Script (Join-Path $repoRoot "scripts\touch-code-change.ps1") @(
    "-Slug", $slug, "-SopRoot", $runtimeTouchRoot,
    "-Timestamp", "2026-08-17T02:00:00Z",
    "-DecisionMaker", "tester",
    "-ConfirmationQuote", "record runtime change after approved regression",
    "-Reason", "runtime implementation changed"
  )
  if ($runtimeTouch.Code -ne 0) { throw "runtime touch after approvals failed. $($runtimeTouch.Output)" }
  Assert-True ($runtimeTouch.Output -match '"human_gate_approved":\s*false') `
    "runtime touch must only invalidate machine evidence"
  $afterRuntimeTouch = Get-Content -LiteralPath $runtimeTouchStatePath -Raw | ConvertFrom-Json
  foreach ($invalidatedGate in @("CODE_READY", "REGRESSION_PASS", "DOCS_COMPLETE")) {
    Assert-True (-not $afterRuntimeTouch.approval_refs.$invalidatedGate) `
      "runtime touch must invalidate stale $invalidatedGate approval_ref"
  }
  Assert-True ([string]::IsNullOrWhiteSpace([string]$afterRuntimeTouch.timestamps.last_regression_at)) `
    "runtime touch must clear last_regression_at"
  Assert-True ($null -eq $afterRuntimeTouch.PSObject.Properties["regression"]) `
    "runtime touch must remove regression cache"
  $runtimeApprovals = Get-Content -LiteralPath `
    (Join-Path $runtimeTouchRoot "projects\$slug\APPROVALS.md") -Raw
  foreach ($oldRef in @($oldRuntimeCodeRef, $oldRuntimeRegressionRef, $oldRuntimeDocsRef)) {
    Assert-True ($runtimeApprovals -match [regex]::Escape($oldRef)) `
      "runtime touch must preserve superseded approval history for $oldRef"
  }

  # Simulate a stale/corrupt cache restoration. DOCS_COMPLETE must independently
  # revalidate last-run freshness instead of trusting REGRESSION_PASS's ref.
  $afterRuntimeTouch.stage_status.CODE = "approved"
  $afterRuntimeTouch.stage_status.TEST = "approved"
  $afterRuntimeTouch.approval_refs | Add-Member -NotePropertyName CODE_READY `
    -NotePropertyValue $oldRuntimeCodeRef -Force
  $afterRuntimeTouch.approval_refs | Add-Member -NotePropertyName REGRESSION_PASS `
    -NotePropertyValue $oldRuntimeRegressionRef -Force
  $afterRuntimeTouch | ConvertTo-Json -Depth 12 |
    Set-Content -LiteralPath $runtimeTouchStatePath -Encoding utf8
  $staleDocs = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $runtimeTouchRoot,
    "-GateId", "DOCS_COMPLETE", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "attempt DOCS with stale regression"
  )
  if ($staleDocs.Code -eq 0) {
    throw "DOCS_COMPLETE must reject stale full regression even if REGRESSION_PASS ref is restored"
  }

  $cascadeRoot = Join-Path $tempRoot "cascade-root"
  New-Item -ItemType Directory -Force -Path (Join-Path $cascadeRoot "projects") | Out-Null
  Copy-Item -LiteralPath (Join-Path $tempRoot "projects\$slug") `
    -Destination (Join-Path $cascadeRoot "projects\$slug") -Recurse
  $cascadeReject = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $cascadeRoot,
    "-GateId", "ARCH_SIGNOFF", "-Decision", "rejected",
    "-Approver", "tester", "-ConfirmationQuote", "reject approved architecture",
    "-Evidence", "architecture changed"
  )
  if ($cascadeReject.Code -ne 0) { throw "upstream ARCH_SIGNOFF rejection should record" }
  $cascadeStatePath = Join-Path $cascadeRoot "projects\$slug\state.json"
  $cascadeState = Get-Content -LiteralPath $cascadeStatePath -Raw | ConvertFrom-Json
  foreach ($invalidatedGate in @("ARCH_SIGNOFF", "TEST_PACK_READY", "CODE_READY", "REGRESSION_PASS", "DOCS_COMPLETE")) {
    Assert-True (-not $cascadeState.approval_refs.$invalidatedGate) `
      "rejecting ARCH_SIGNOFF must invalidate stale $invalidatedGate approval_refs"
  }
  Assert-Equal "ARCH_SIGNOFF" $cascadeState.blocked.gate_id "upstream rejection must remain the active block"
  $staleCode = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $cascadeRoot,
    "-GateId", "CODE_READY", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "attempt stale CODE_READY"
  )
  if ($staleCode.Code -eq 0) { throw "upstream rejection must block stale CODE_READY approval" }
  $unrelatedApprove = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $cascadeRoot,
    "-GateId", "INTAKE_COMPLETE", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "record unrelated intake decision"
  )
  if ($unrelatedApprove.Code -ne 0) { throw "unrelated gate record should remain possible for a new project fixture" }
  $cascadeState = Get-Content -LiteralPath $cascadeStatePath -Raw | ConvertFrom-Json
  Assert-Equal "ARCH_SIGNOFF" $cascadeState.blocked.gate_id "unrelated approval must not clear an upstream block"

  $state.timestamps.last_regression_at = $lastRun.finished_at
  $state | Add-Member -NotePropertyName regression -NotePropertyValue ([pscustomobject]@{
    state = "passed"; mode = "full"; last_run = "test/last-run.json"; updated_at = $lastRun.finished_at
  }) -Force
  $state | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $statePath -Encoding utf8

  $reset = Invoke-Script (Join-Path $repoRoot "scripts\apply-gate-reset.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-ChangeClass", "architecture",
    "-DecisionMaker", "tester",
    "-ConfirmationQuote", "reset architecture after API change",
    "-Reason", "API contract changed"
  )
  if ($reset.Code -ne 0) { throw "apply-gate-reset failed. $($reset.Output)" }
  $state = Get-Content -Raw $statePath | ConvertFrom-Json
  Assert-Equal "in_progress" $state.stage_status.ARCH "reset should move ARCH to in_progress"
  Assert-True (-not $state.approval_refs.ARCH_SIGNOFF) "reset must drop superseded ARCH approval_ref"
  Assert-True ($state.approval_refs.REQ_SIGNOFF -match '^APR-') "product-unrelated REQ ref should remain"
  Assert-True ([string]::IsNullOrWhiteSpace([string]$state.timestamps.test_pack_at)) "architecture reset must clear test_pack_at"
  Assert-True ([string]::IsNullOrWhiteSpace([string]$state.timestamps.last_regression_at)) "reset containing REGRESSION_PASS must clear last_regression_at"
  Assert-True ($null -eq $state.PSObject.Properties["regression"]) "reset containing REGRESSION_PASS must remove regression cache"
  Assert-True ([string]::IsNullOrWhiteSpace([string]$state.mode)) "regression reset must clear regression mode"
  Assert-True ([string]::IsNullOrWhiteSpace([string]$state.timestamps.docs_completed_at)) "architecture reset must clear docs_completed_at"

  $archAgain = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "ARCH_SIGNOFF", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "reapprove ARCH"
  )
  if ($archAgain.Code -ne 0) { throw "ARCH reapproval after reset should record" }
  $packAgain = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "TEST_PACK_READY", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "reapprove TEST pack"
  )
  if ($packAgain.Code -ne 0) { throw "TEST pack reapproval after reset should record" }
  $packReset = Invoke-Script (Join-Path $repoRoot "scripts\apply-gate-reset.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-ChangeClass", "test_pack",
    "-DecisionMaker", "tester",
    "-ConfirmationQuote", "reset test pack",
    "-Reason", "test catalog changed"
  )
  if ($packReset.Code -ne 0) { throw "test_pack reset should record" }
  $state = Get-Content -Raw $statePath | ConvertFrom-Json
  Assert-True ([string]::IsNullOrWhiteSpace([string]$state.mode)) "TEST_PACK reset must clear packaging mode"

  $paused = Invoke-Script (Join-Path $repoRoot "scripts\set-lifecycle.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-Lifecycle", "paused",
    "-DecisionMaker", "tester",
    "-ConfirmationQuote", "pause this project"
  )
  if ($paused.Code -ne 0) { throw "set-lifecycle paused failed. $($paused.Output)" }
  $state = Get-Content -Raw $statePath | ConvertFrom-Json
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$state.timestamps.lifecycle_changed_at)) "set-lifecycle must stamp lifecycle_changed_at"
  $sopAfterPause = Get-Content -Raw (Join-Path $tempRoot "projects\$slug\SOP.md")
  Assert-SopTimestamp $sopAfterPause "lifecycle_changed_at" $state.timestamps.lifecycle_changed_at "SOP.md must mirror lifecycle_changed_at"
  $blockedWrite = Invoke-Script (Join-Path $repoRoot "scripts\touch-code-change.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-DecisionMaker", "tester", "-ConfirmationQuote", "attempt paused runtime change",
    "-Reason", "paused project write guard"
  )
  if ($blockedWrite.Code -eq 0) { throw "paused project must block delivery writes" }

  $archived = Invoke-Script (Join-Path $repoRoot "scripts\set-lifecycle.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-Lifecycle", "archived",
    "-DecisionMaker", "tester",
    "-ConfirmationQuote", "archive this project"
  )
  if ($archived.Code -ne 0) { throw "paused -> archived should work" }

  $reactivate = Invoke-Script (Join-Path $repoRoot "scripts\set-lifecycle.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-Lifecycle", "active",
    "-DecisionMaker", "tester",
    "-ConfirmationQuote", "reactivate this project"
  )
  if ($reactivate.Code -ne 0) { throw "archived -> active should work. $($reactivate.Output)" }
  $touch = Invoke-Script (Join-Path $repoRoot "scripts\touch-code-change.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-DecisionMaker", "tester", "-ConfirmationQuote", "record active runtime change",
    "-Reason", "active lifecycle write fixture"
  )
  if ($touch.Code -ne 0) { throw "active project must allow touch-code-change. $($touch.Output)" }

  $cancelled = Invoke-Script (Join-Path $repoRoot "scripts\set-lifecycle.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-Lifecycle", "cancelled",
    "-DecisionMaker", "tester",
    "-ConfirmationQuote", "cancel this project"
  )
  if ($cancelled.Code -ne 0) { throw "set-lifecycle cancelled failed" }
  $cancelRecord = Invoke-Script (Join-Path $repoRoot "scripts\record-cancellation.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-DecisionMaker", "tester",
    "-ConfirmationQuote", "append cancellation follow-up",
    "-Reason", "Retain the shutdown evidence",
    "-Reference", "ticket-123"
  )
  if ($cancelRecord.Code -ne 0) { throw "cancelled project must allow cancellation records. $($cancelRecord.Output)" }
  Assert-True ($cancelRecord.Output -match '"human_gate_approved":\s*false') "cancellation record must not claim gate approval"
  $cancelledGateWrite = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-GateId", "REQ_SIGNOFF", "-Decision", "rejected",
    "-Approver", "tester", "-ConfirmationQuote", "try regular write after cancellation"
  )
  if ($cancelledGateWrite.Code -eq 0) { throw "cancelled project must block regular gate writes" }
  $cancelledTouch = Invoke-Script (Join-Path $repoRoot "scripts\touch-code-change.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-DecisionMaker", "tester", "-ConfirmationQuote", "attempt cancelled runtime change",
    "-Reason", "cancelled project write guard"
  )
  if ($cancelledTouch.Code -eq 0) { throw "cancelled project must block delivery writers" }
  $uncancel = Invoke-Script (Join-Path $repoRoot "scripts\set-lifecycle.ps1") @(
    "-Slug", $slug, "-SopRoot", $tempRoot,
    "-Lifecycle", "active",
    "-DecisionMaker", "tester",
    "-ConfirmationQuote", "try to uncancel"
  )
  if ($uncancel.Code -eq 0) { throw "cancelled projects must not return to active" }

  $historicalSlug = "gov-historical"
  $historicalCreated = Invoke-Script (Join-Path $repoRoot "scripts\new-project.ps1") @(
    "-Slug", $historicalSlug,
    "-SopRoot", $tempRoot,
    "-DoNotSetActive"
  )
  if ($historicalCreated.Code -ne 0) { throw "historical governance fixture creation failed" }
  $historicalStatePath = Join-Path $tempRoot "projects\$historicalSlug\state.json"
  $historicalState = Get-Content -LiteralPath $historicalStatePath -Raw | ConvertFrom-Json
  $historicalState.origin = "historical"
  $historicalState | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $historicalStatePath -Encoding utf8
  $historicalIntake = Invoke-Script (Join-Path $repoRoot "scripts\record-gate.ps1") @(
    "-Slug", $historicalSlug, "-SopRoot", $tempRoot,
    "-GateId", "INTAKE_COMPLETE", "-Decision", "approved",
    "-Approver", "tester", "-ConfirmationQuote", "approve incomplete historical intake"
  )
  if ($historicalIntake.Code -eq 0) { throw "historical INTAKE_COMPLETE must invoke and enforce intake validator evidence" }

  python (Join-Path $repoRoot "scripts\validate-json-schema.py") `
    (Join-Path $repoRoot "schemas\state.schema.json") $statePath
  if ($LASTEXITCODE -ne 0) { throw "final state.json failed schema validation" }

  $sessionRoot = Join-Path $tempRoot "session-root"
  $sessionProject = Join-Path $sessionRoot "projects\paused-app"
  New-Item -ItemType Directory -Force -Path $sessionProject | Out-Null
  "slug: paused-app" | Set-Content -Path (Join-Path $sessionRoot "projects\CURRENT.md") -Encoding utf8
  Copy-Item -LiteralPath $statePath -Destination (Join-Path $sessionProject "state.json")
  $sessionJson = & $shell -NoProfile -File (Join-Path $repoRoot ".cursor\hooks\session-start.ps1") -SopRoot $sessionRoot
  if ($sessionJson -notmatch "cancelled") {
    throw "session-start must warn on cancelled lifecycle. Output: $sessionJson"
  }

  $identityRoot = Join-Path $tempRoot "identity-root"
  New-Item -ItemType Directory -Force -Path (Join-Path $identityRoot "projects") | Out-Null
  Copy-Item -LiteralPath (Join-Path $repoRoot "projects\_template") `
    -Destination (Join-Path $identityRoot "projects\_template") -Recurse
  $identitySlug = "identity-app"
  $identityCreated = Invoke-Script (Join-Path $repoRoot "scripts\new-project.ps1") @(
    "-Slug", $identitySlug, "-SopRoot", $identityRoot, "-DoNotSetActive"
  )
  if ($identityCreated.Code -ne 0) { throw "identity fixture creation failed" }
  "slug: another-app" | Set-Content -LiteralPath (Join-Path $identityRoot "projects\CURRENT.md") -Encoding utf8
  $currentMismatch = Invoke-Script (Join-Path $repoRoot "scripts\write-governance.ps1") @(
    "-Slug", $identitySlug, "-SopRoot", $identityRoot, "-DataClassification", "internal"
  )
  if ($currentMismatch.Code -eq 0) { throw "delivery writer must fail closed when CURRENT differs from parameter/directory/state slug" }
  $lifecycleCurrentMismatch = Invoke-Script (Join-Path $repoRoot "scripts\set-lifecycle.ps1") @(
    "-Slug", $identitySlug, "-SopRoot", $identityRoot,
    "-Lifecycle", "paused", "-DecisionMaker", "tester",
    "-ConfirmationQuote", "attempt lifecycle write against a different CURRENT project"
  )
  if ($lifecycleCurrentMismatch.Code -eq 0) {
    throw "lifecycle writer must fail closed when CURRENT differs from parameter/directory/state slug"
  }
  "slug: $identitySlug" | Set-Content -LiteralPath (Join-Path $identityRoot "projects\CURRENT.md") -Encoding utf8
  $identityStatePath = Join-Path $identityRoot "projects\$identitySlug\state.json"
  $identityState = Get-Content -LiteralPath $identityStatePath -Raw | ConvertFrom-Json
  $identityState.slug = "different-state-slug"
  $identityState | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $identityStatePath -Encoding utf8
  $stateMismatch = Invoke-Script (Join-Path $repoRoot "scripts\write-governance.ps1") @(
    "-Slug", $identitySlug, "-SopRoot", $identityRoot, "-DataClassification", "internal"
  )
  if ($stateMismatch.Code -eq 0) { throw "delivery writer must fail closed when state.slug differs from parameter/directory" }

  Write-Output "Governance smoke tests passed."
  exit 0
} finally {
  Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}
