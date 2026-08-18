# Reset downstream gates after a governed change. Does not approve replacement gates.
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9-]*$")][string]$Slug,
  [Parameter(Mandatory = $true)]
  [ValidateSet("product", "visual", "architecture", "test_pack", "runtime_code", "documentation")]
  [string]$ChangeClass,
  [Parameter(Mandatory = $true)][string]$DecisionMaker,
  [Parameter(Mandatory = $true)][string]$ConfirmationQuote,
  [Parameter(Mandatory = $true)][string]$Reason,
  [string]$SopRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [ValidateSet("in_progress", "blocked")]
  [string]$TargetStatus = "in_progress"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\project-state.ps1")

if ([string]::IsNullOrWhiteSpace($ConfirmationQuote) -or $ConfirmationQuote.Trim().Length -lt 2) {
  throw "ConfirmationQuote from chat is required; reset is not an approval."
}

$projectRoot = Join-Path $SopRoot "projects\$Slug"
Assert-ProjectWritable -ProjectRoot $projectRoot -Intent delivery
$stateFile = Join-Path $projectRoot "state.json"
$sopFile = Join-Path $projectRoot "SOP.md"
$approvalsFile = Join-Path $projectRoot "APPROVALS.md"
$decisionsFile = Join-Path $projectRoot "DECISIONS.md"
if (-not (Test-Path -LiteralPath $stateFile)) { throw "state.json missing: $stateFile" }

$state = Read-ProjectStateFile $stateFile
$stamp = [DateTimeOffset]::UtcNow.ToString("o")
$decId = Get-NextRecordId -Path $decisionsFile -Prefix "DEC"
$gates = @($script:SopResetMatrix[$ChangeClass])
$superseded = New-Object System.Collections.Generic.List[string]
$quote = $ConfirmationQuote.Trim() -replace '\|', "/"

if (-not (Get-JsonProperty $state "stage_status")) {
  $state | Add-Member -NotePropertyName stage_status -NotePropertyValue ([pscustomobject]@{}) -Force
}
if (-not (Get-JsonProperty $state "approval_refs")) {
  $state | Add-Member -NotePropertyName approval_refs -NotePropertyValue ([pscustomobject]@{}) -Force
}

$newRefs = [ordered]@{}
$existingRefs = Get-JsonProperty $state "approval_refs"
foreach ($gate in $script:SopStableGates) {
  $value = Get-JsonProperty $existingRefs $gate
  if ($gates -contains $gate) {
    if (-not [string]::IsNullOrWhiteSpace([string]$value)) { $superseded.Add([string]$value) }
    $stage = $script:SopGateMeta[$gate].Stage
    $state.stage_status | Add-Member -NotePropertyName $stage -NotePropertyValue $TargetStatus -Force
  } elseif (-not [string]::IsNullOrWhiteSpace([string]$value)) {
    $newRefs[$gate] = [string]$value
  }
}
$state | Add-Member -NotePropertyName approval_refs -NotePropertyValue $newRefs -Force
$state | Add-Member -NotePropertyName blocked -NotePropertyValue $(
  if ($TargetStatus -eq "blocked") {
    [ordered]@{
      gate_id = $gates[0]
      owner_role = $script:SopGateMeta[$gates[0]].Owner
      reason = $Reason
      since = $stamp
    }
  } else { $null }
) -Force
$state = Ensure-StateTimestamps $state
foreach ($gate in $gates) {
  $tsField = Get-GateTimestampField $gate
  if ($tsField) {
    $state.timestamps | Add-Member -NotePropertyName $tsField -NotePropertyValue $null -Force
  }
}
if ($gates -contains "REGRESSION_PASS") {
  $state.timestamps | Add-Member -NotePropertyName last_regression_at -NotePropertyValue $null -Force
  $state.PSObject.Properties.Remove("regression")
  if ((Get-JsonProperty $state "mode") -eq "regression") {
    $state | Add-Member -NotePropertyName mode -NotePropertyValue $null -Force
  }
}
if (($gates -contains "TEST_PACK_READY") -and (Get-JsonProperty $state "mode") -eq "packaging") {
  $state | Add-Member -NotePropertyName mode -NotePropertyValue $null -Force
}
$state.timestamps | Add-Member -NotePropertyName updated_at -NotePropertyValue $stamp -Force
[void](Write-CanonicalState -Path $stateFile -Slug $Slug -State $state -RepoRoot $SopRoot)

foreach ($gate in $gates) {
  $stage = $script:SopGateMeta[$gate].Stage
  [void](Update-SopStageRow -SopPath $sopFile -Stage $stage -Status $TargetStatus -Note "reset $decId")
  $tsField = Get-GateTimestampField $gate
  if ($tsField) {
    [void](Update-SopTimestampRow -SopPath $sopFile -Field $tsField -Timestamp "")
  }
}
if ($gates -contains "REGRESSION_PASS") {
  [void](Update-SopTimestampRow -SopPath $sopFile -Field "last_regression_at" -Timestamp "")
}
if (($gates -contains "REGRESSION_PASS") -or ($gates -contains "TEST_PACK_READY")) {
  [void](Update-SopFieldRow -SopPath $sopFile -Field "Stage mode" -Value "none")
}
if ($TargetStatus -eq "blocked") {
  [void](Update-SopFieldRow -SopPath $sopFile -Field "Blocked by" -Value "$($gates[0]) / $($script:SopGateMeta[$gates[0]].Owner)")
} else {
  [void](Update-SopFieldRow -SopPath $sopFile -Field "Blocked by" -Value "none")
}
[void](Add-SopLogRow -SopPath $sopFile -When $stamp -Stage "SOP" -Role "编排官" `
  -Event "reset $ChangeClass" -Reference $decId)

if (Test-Path -LiteralPath $approvalsFile) {
  $mark = @"

### SUPERSEDED by $decId

The following approval IDs were superseded on $stamp because of change class ``$ChangeClass``: $($superseded -join ", ").
History is preserved; replacement gates require a new conversational confirmation.
"@
  Add-MarkdownRecord -Path $approvalsFile -Text $mark
}

$record = @"
### $decId — reset $ChangeClass

| Field | Value |
|-------|-------|
| Recorded at | $stamp |
| Decision maker | $DecisionMaker |
| Type | change |
| Context | $Reason |
| Decision | Reset gates $($gates -join ", ") to $TargetStatus |
| Alternatives | restore last approved artifacts |
| Consequences | prior approvals $($superseded -join ", ") are superseded; new chat confirmation is required |
| Affected gate IDs | $($gates -join ", ") |
| Superseded approval IDs | $($superseded -join ", ") |
| Risk owner | $DecisionMaker |
| Compensating controls | history retained in APPROVALS.md |
| Expiry / review trigger | next conversational re-approval |
| Explicit confirmation quote | $quote |
"@
Add-MarkdownRecord -Path $decisionsFile -Text $record

[pscustomobject]@{
  slug = $Slug
  change_class = $ChangeClass
  reset_gates = @($gates)
  superseded = @($superseded)
  decision_id = $decId
  human_gate_approved = $false
  note = "Reset recorded. Replacement gates still require conversational confirmation."
} | ConvertTo-Json -Compress -Depth 5
exit 0
