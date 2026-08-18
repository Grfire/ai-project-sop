# Record a conversational gate decision into APPROVALS/DECISIONS/SOP/state.
# Never infers confirmation from files or Markdown checkboxes.
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9-]*$")][string]$Slug,
  [Parameter(Mandatory = $true)]
  [ValidateSet(
    "INTAKE_COMPLETE", "REQ_SIGNOFF", "UI_SIGNOFF", "ARCH_SIGNOFF",
    "TEST_PACK_READY", "CODE_READY", "REGRESSION_PASS", "DOCS_COMPLETE"
  )]
  [string]$GateId,
  [Parameter(Mandatory = $true)][ValidateSet("approved", "rejected", "waived")][string]$Decision,
  [Parameter(Mandatory = $true)][string]$Approver,
  [Parameter(Mandatory = $true)][string]$ConfirmationQuote,
  [string]$SopRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$Evidence = "",
  [string]$Scope = "",
  [string]$Supersedes = "none",
  [string]$WaiverReason = "",
  [string]$RiskOwner = "",
  [string]$Expiry = "",
  [string]$CompensatingControls = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\project-state.ps1")

if ([string]::IsNullOrWhiteSpace($Approver)) { throw "Approver identity from chat is required" }
if ([string]::IsNullOrWhiteSpace($ConfirmationQuote) -or $ConfirmationQuote.Trim().Length -lt 2) {
  throw "ConfirmationQuote from chat is required; this command does not approve gates by itself."
}

$projectRoot = Join-Path $SopRoot "projects\$Slug"
Assert-ProjectWritable -ProjectRoot $projectRoot -Intent delivery
$stateFile = Join-Path $projectRoot "state.json"
$sopFile = Join-Path $projectRoot "SOP.md"
$approvalsFile = Join-Path $projectRoot "APPROVALS.md"
$decisionsFile = Join-Path $projectRoot "DECISIONS.md"
if (-not (Test-Path -LiteralPath $stateFile)) { throw "state.json missing: $stateFile" }

$state = Read-ProjectStateFile $stateFile
$meta = $script:SopGateMeta[$GateId]
$stage = $meta.Stage
$owner = $meta.Owner
$stamp = [DateTimeOffset]::UtcNow.ToString("o")
$aprId = Get-NextRecordId -Path $approvalsFile -Prefix "APR"
$quote = $ConfirmationQuote.Trim() -replace '\|', "/"
$invalidatedRefs = New-Object System.Collections.Generic.List[string]

function Invoke-ArtifactValidator {
  param(
    [Parameter(Mandatory = $true)][string]$ScriptName,
    [Parameter(Mandatory = $true)][string]$ArgumentName,
    [Parameter(Mandatory = $true)][string]$ArtifactPath
  )
  $validator = Join-Path $PSScriptRoot $ScriptName
  if (-not (Test-Path -LiteralPath $validator)) { throw "Required validator missing: $validator" }
  $validatorArgs = @{ $ArgumentName = $ArtifactPath }
  $validatorOutput = & $validator @validatorArgs
  $validatorExit = $LASTEXITCODE
  if ($validatorExit -ne 0) {
    throw "$GateId evidence validation failed via ${ScriptName}: $($validatorOutput -join ' ')"
  }
  try {
    $report = ($validatorOutput -join [Environment]::NewLine) | ConvertFrom-Json
  } catch {
    throw "$GateId validator returned invalid JSON: $ScriptName"
  }
  if ((Get-JsonProperty $report "artifact_evidence_valid") -ne $true) {
    throw "$GateId validator did not report artifact_evidence_valid=true: $ScriptName"
  }
  return $report
}

function Test-ActiveWaiverForGate {
  param([Parameter(Mandatory = $true)][string]$RequiredGate)
  $activeIds = @(
    Get-JsonProperty (Get-JsonProperty $state "governance") "active_waiver_ids"
  )
  if ($activeIds.Count -eq 0 -or -not (Test-Path -LiteralPath $decisionsFile)) { return $false }
  $decisionText = [IO.File]::ReadAllText($decisionsFile)
  foreach ($id in $activeIds) {
    if ([string]::IsNullOrWhiteSpace([string]$id)) { continue }
    $sectionPattern = "(?ms)^###\s+$([regex]::Escape([string]$id))\b.*?(?=^###\s+|\z)"
    $match = [regex]::Match($decisionText, $sectionPattern)
    if ($match.Success -and
        $match.Value -match "(?im)^\|\s*Type\s*\|\s*waiver\s*\|" -and
        $match.Value -match "(?im)^\|\s*Context\s*\|\s*$([regex]::Escape($RequiredGate))\s*\|") {
      return $true
    }
  }
  return $false
}

if ($Decision -eq "waived" -and $GateId -eq "UI_SIGNOFF") {
  throw "UI_SIGNOFF cannot be waived to completion. Record a provisional UI draft waiver against REQ_SIGNOFF instead."
}

if ($Decision -eq "approved") {
  Assert-GatePrerequisites -State $state -GateId $GateId
}

if ($Decision -eq "approved" -and $GateId -eq "UI_SIGNOFF") {
  # Covered by the canonical prerequisite map; kept as an explicit stage rule.
}

if ($Decision -eq "approved" -and $GateId -eq "ARCH_SIGNOFF") {
  $uiMode = Get-JsonProperty $state "ui_input_mode"
  if ([string]::IsNullOrWhiteSpace([string]$uiMode)) {
    throw "ARCH_SIGNOFF requires ui_input_mode complete|partial|none in state.json"
  }
  if ($uiMode -eq "complete") {
    [void](Assert-GateApprovedCache -State $state -GateId "UI_SIGNOFF")
  } elseif ($uiMode -in @("partial", "none")) {
    if (-not (Test-ActiveWaiverForGate -RequiredGate "ARCH_SIGNOFF")) {
      throw "ARCH_SIGNOFF with ui_input_mode=$uiMode requires an active ARCH_SIGNOFF waiver record."
    }
  } else {
    throw "ARCH_SIGNOFF requires ui_input_mode complete|partial|none in state.json"
  }
}

if ($Decision -eq "approved" -and $GateId -eq "REQ_SIGNOFF") {
  $classification = Get-JsonProperty (Get-JsonProperty $state "governance") "data_classification"
  $ownerName = Get-JsonProperty (Get-JsonProperty $state "governance") "compliance_owner"
  if ([string]::IsNullOrWhiteSpace([string]$classification) -or [string]::IsNullOrWhiteSpace([string]$ownerName)) {
    throw "REQ_SIGNOFF requires data_classification and compliance_owner in state.governance (write-governance.ps1)."
  }
}

if ($Decision -eq "waived") {
  if ([string]::IsNullOrWhiteSpace($WaiverReason) -or [string]::IsNullOrWhiteSpace($RiskOwner) -or [string]::IsNullOrWhiteSpace($Expiry)) {
    throw "waived decisions require WaiverReason, RiskOwner, and Expiry/review trigger"
  }
}

if ($Decision -eq "approved") {
  switch ($GateId) {
    "INTAKE_COMPLETE" {
      if ((Get-JsonProperty $state "origin") -eq "historical") {
        [void](Invoke-ArtifactValidator -ScriptName "validate-intake-artifacts.ps1" `
          -ArgumentName "IntakePath" -ArtifactPath (Join-Path $projectRoot "intake"))
      }
    }
    "TEST_PACK_READY" {
      # Prerequisites are checked by Assert-GatePrerequisites above.
    }
    "CODE_READY" {
      # Prerequisites are checked by Assert-GatePrerequisites above.
    }
    "REGRESSION_PASS" {
      $lastRunPath = Join-Path $projectRoot "test\last-run.json"
      [void](Assert-FreshFullRegressionEvidence -State $state -Slug $Slug `
        -LastRunPath $lastRunPath -GateId "REGRESSION_PASS")
    }
    "DOCS_COMPLETE" {
      $lastRunPath = Join-Path $projectRoot "test\last-run.json"
      [void](Assert-FreshFullRegressionEvidence -State $state -Slug $Slug `
        -LastRunPath $lastRunPath -GateId "DOCS_COMPLETE")
      [void](Invoke-ArtifactValidator -ScriptName "validate-docs-artifacts.ps1" `
        -ArgumentName "DocsPath" -ArtifactPath (Join-Path $projectRoot "docs"))
    }
  }
}

$state = Ensure-StateTimestamps $state
if (-not (Get-JsonProperty $state "stage_status")) {
  $state | Add-Member -NotePropertyName stage_status -NotePropertyValue ([pscustomobject]@{}) -Force
}
if (-not (Get-JsonProperty $state "approval_refs")) {
  $state | Add-Member -NotePropertyName approval_refs -NotePropertyValue ([pscustomobject]@{}) -Force
}
if (-not (Get-JsonProperty $state "governance")) {
  $state | Add-Member -NotePropertyName governance -NotePropertyValue ([pscustomobject]@{ active_waiver_ids = @() }) -Force
}

$decId = "none"
if ($Decision -eq "approved") {
  $state.stage_status | Add-Member -NotePropertyName $stage -NotePropertyValue "approved" -Force
  $state.approval_refs | Add-Member -NotePropertyName $GateId -NotePropertyValue $aprId -Force
  $existingBlocked = Get-JsonProperty $state "blocked"
  if ($null -eq $existingBlocked -or (Get-JsonProperty $existingBlocked "gate_id") -eq $GateId) {
    $state | Add-Member -NotePropertyName blocked -NotePropertyValue $null -Force
  }
  if ($GateId -eq "INTAKE_COMPLETE") {
    $state.timestamps | Add-Member -NotePropertyName intake_completed_at -NotePropertyValue $stamp -Force
  }
  if ($GateId -eq "TEST_PACK_READY") {
    $state.timestamps | Add-Member -NotePropertyName test_pack_at -NotePropertyValue $stamp -Force
    $state | Add-Member -NotePropertyName mode -NotePropertyValue "packaging" -Force
  }
  if ($GateId -eq "REGRESSION_PASS") {
    $state | Add-Member -NotePropertyName mode -NotePropertyValue "regression" -Force
  }
  if ($GateId -eq "DOCS_COMPLETE") {
    $state.timestamps | Add-Member -NotePropertyName docs_completed_at -NotePropertyValue $stamp -Force
  }
} elseif ($Decision -eq "rejected") {
  $invalidatedGates = @(Get-GateAndDownstream -GateId $GateId)
  foreach ($invalidatedGate in $invalidatedGates) {
    $oldRef = Get-JsonProperty $state.approval_refs $invalidatedGate
    if (-not [string]::IsNullOrWhiteSpace([string]$oldRef)) {
      $invalidatedRefs.Add([string]$oldRef)
    }
    $state.approval_refs.PSObject.Properties.Remove($invalidatedGate)
    if ($invalidatedGate -ne $GateId) {
      $downstreamStage = $script:SopGateMeta[$invalidatedGate].Stage
      if ($downstreamStage -ne $stage) {
        $state.stage_status | Add-Member -NotePropertyName $downstreamStage -NotePropertyValue "in_progress" -Force
      }
    }
    $invalidatedTimestamp = Get-GateTimestampField $invalidatedGate
    if ($invalidatedTimestamp) {
      $state.timestamps | Add-Member -NotePropertyName $invalidatedTimestamp -NotePropertyValue $null -Force
    }
  }
  if ($invalidatedGates -contains "REGRESSION_PASS") {
    $state.timestamps | Add-Member -NotePropertyName last_regression_at -NotePropertyValue $null -Force
    $state.PSObject.Properties.Remove("regression")
    if ((Get-JsonProperty $state "mode") -eq "regression") {
      $state | Add-Member -NotePropertyName mode -NotePropertyValue $null -Force
    }
  }
  if (($invalidatedGates -contains "TEST_PACK_READY") -and (Get-JsonProperty $state "mode") -eq "packaging") {
    $state | Add-Member -NotePropertyName mode -NotePropertyValue $null -Force
  }
  $state.stage_status | Add-Member -NotePropertyName $stage -NotePropertyValue "blocked" -Force
  $state | Add-Member -NotePropertyName blocked -NotePropertyValue ([ordered]@{
    gate_id = $GateId
    owner_role = $owner
    reason = $(if ($Evidence) { $Evidence } else { "rejected in conversation" })
    since = $stamp
  }) -Force
} else {
  $decId = Get-NextRecordId -Path $decisionsFile -Prefix "DEC"
  $ids = New-Object System.Collections.Generic.List[string]
  foreach ($item in @((Get-JsonProperty (Get-JsonProperty $state "governance") "active_waiver_ids"))) {
    if ($item) { $ids.Add([string]$item) }
  }
  if (-not $ids.Contains($decId)) { $ids.Add($decId) }
  $state.governance | Add-Member -NotePropertyName active_waiver_ids -NotePropertyValue @($ids) -Force
}

$state.timestamps | Add-Member -NotePropertyName updated_at -NotePropertyValue $stamp -Force
[void](Write-CanonicalState -Path $stateFile -Slug $Slug -State $state -RepoRoot $SopRoot)

[void](Update-SopStageRow -SopPath $sopFile -Stage $stage -Status $(
  if ($Decision -eq "approved") { "approved" } elseif ($Decision -eq "rejected") { "blocked" } else { "in_progress" }
) -Note $aprId)
if ($Decision -eq "rejected") {
  foreach ($invalidatedGate in $invalidatedGates) {
    if ($invalidatedGate -eq $GateId) { continue }
    $downstreamStage = $script:SopGateMeta[$invalidatedGate].Stage
    if ($downstreamStage -ne $stage) {
      [void](Update-SopStageRow -SopPath $sopFile -Stage $downstreamStage `
        -Status "in_progress" -Note "invalidated by $aprId")
    }
    $invalidatedTimestamp = Get-GateTimestampField $invalidatedGate
    if ($invalidatedTimestamp) {
      [void](Update-SopTimestampRow -SopPath $sopFile -Field $invalidatedTimestamp -Timestamp "")
    }
  }
  if ($invalidatedGates -contains "REGRESSION_PASS") {
    [void](Update-SopTimestampRow -SopPath $sopFile -Field "last_regression_at" -Timestamp "")
    [void](Update-SopFieldRow -SopPath $sopFile -Field "Stage mode" -Value "none")
  } elseif ($invalidatedGates -contains "TEST_PACK_READY") {
    [void](Update-SopFieldRow -SopPath $sopFile -Field "Stage mode" -Value "none")
  }
}
$tsField = Get-GateTimestampField $GateId
if ($Decision -eq "approved" -and $tsField) {
  [void](Update-SopTimestampRow -SopPath $sopFile -Field $tsField -Timestamp $stamp)
}
if ($Decision -eq "rejected") {
  [void](Update-SopFieldRow -SopPath $sopFile -Field "Blocked by" -Value "$GateId / $owner")
} else {
  $remainingBlock = Get-JsonProperty $state "blocked"
  if ($null -eq $remainingBlock) {
    [void](Update-SopFieldRow -SopPath $sopFile -Field "Blocked by" -Value "none")
  } else {
    [void](Update-SopFieldRow -SopPath $sopFile -Field "Blocked by" `
      -Value "$((Get-JsonProperty $remainingBlock 'gate_id')) / $((Get-JsonProperty $remainingBlock 'owner_role'))")
  }
}
[void](Add-SopLogRow -SopPath $sopFile -When $stamp -Stage $stage -Role $owner `
  -Event "$GateId $Decision" -Reference $aprId)

$approval = @"
### $aprId — $GateId

| Field | Value |
|-------|-------|
| Project slug | $Slug |
| Decision | $Decision |
| Approver | $Approver |
| Confirmed at | $stamp |
| Scope / version | $Scope |
| Evidence snapshot / links | $Evidence |
| Confirmation quote | $quote |
| Supersedes | $(
  $allSupersedes = @($Supersedes -split '[,; ]+' | Where-Object { $_ -and $_ -ne "none" })
  $allSupersedes += @($invalidatedRefs)
  if ($allSupersedes.Count -gt 0) { ($allSupersedes | Select-Object -Unique) -join ", " } else { "none" }
) |
| Decision reference | $decId |

Machine checks and Markdown checkboxes are not approval authority. This file only records the conversational decision.
"@
Add-MarkdownRecord -Path $approvalsFile -Text $approval

if ($Decision -eq "waived") {
  $waiver = @"
### $decId — waiver $GateId

| Field | Value |
|-------|-------|
| Recorded at | $stamp |
| Decision maker | $Approver |
| Type | waiver |
| Context | $GateId |
| Decision | waived: $WaiverReason |
| Alternatives | produce missing evidence |
| Consequences | does not fabricate evidence; does not silently pass unrelated gates |
| Affected gate IDs | $GateId |
| Superseded approval IDs | $Supersedes |
| Risk owner | $RiskOwner |
| Compensating controls | $CompensatingControls |
| Expiry / review trigger | $Expiry |
| Explicit confirmation quote | $quote |
"@
  Add-MarkdownRecord -Path $decisionsFile -Text $waiver
}

[pscustomobject]@{
  slug = $Slug
  gate_id = $GateId
  decision = $Decision
  approval_id = $aprId
  decision_id = $decId
  human_gate_approved = $false
  note = "Recorded conversational decision only. Scripts never approve gates."
} | ConvertTo-Json -Compress
exit 0
