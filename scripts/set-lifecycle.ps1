# Atomically record project lifecycle. Never approves a delivery gate.
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9-]*$")][string]$Slug,
  [Parameter(Mandatory = $true)][ValidateSet("active", "paused", "cancelled", "archived")][string]$Lifecycle,
  [Parameter(Mandatory = $true)][string]$DecisionMaker,
  [Parameter(Mandatory = $true)][string]$ConfirmationQuote,
  [string]$SopRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$Reason = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\project-state.ps1")

if ([string]::IsNullOrWhiteSpace($DecisionMaker)) { throw "DecisionMaker is required from the conversation" }
if ([string]::IsNullOrWhiteSpace($ConfirmationQuote) -or $ConfirmationQuote.Trim().Length -lt 2) {
  throw "ConfirmationQuote from chat is required; this command does not infer lifecycle changes."
}

$projectRoot = Join-Path $SopRoot "projects\$Slug"
$stateFile = Join-Path $projectRoot "state.json"
$sopFile = Join-Path $projectRoot "SOP.md"
$decisionsFile = Join-Path $projectRoot "DECISIONS.md"
if (-not (Test-Path -LiteralPath $stateFile)) { throw "state.json missing: $stateFile" }

Assert-ProjectWritable -ProjectRoot $projectRoot -Intent lifecycle
$state = Read-ProjectStateFile $stateFile
$current = Get-ProjectLifecycle $state
if ($current -eq $Lifecycle) {
  throw "Lifecycle is already $Lifecycle"
}
if ($current -eq "cancelled" -and $Lifecycle -ne "cancelled") {
  throw "Cancelled projects accept no writes except cancellation records; cannot move to $Lifecycle."
}
if ($current -eq "archived" -and $Lifecycle -ne "active") {
  throw "Archived projects are read-only until conversational reactivation to active."
}

$stamp = [DateTimeOffset]::UtcNow.ToString("o")
$decId = Get-NextRecordId -Path $decisionsFile -Prefix "DEC"
$state = Ensure-StateTimestamps $state
$state | Add-Member -NotePropertyName lifecycle -NotePropertyValue $Lifecycle -Force
$state.timestamps | Add-Member -NotePropertyName lifecycle_changed_at -NotePropertyValue $stamp -Force
$state.timestamps | Add-Member -NotePropertyName updated_at -NotePropertyValue $stamp -Force
[void](Write-CanonicalState -Path $stateFile -Slug $Slug -State $state -RepoRoot $SopRoot)

[void](Update-SopFieldRow -SopPath $sopFile -Field "Lifecycle" -Value $Lifecycle)
[void](Update-SopTimestampRow -SopPath $sopFile -Field "lifecycle_changed_at" -Timestamp $stamp)
[void](Add-SopLogRow -SopPath $sopFile -When $stamp -Stage "SOP" -Role "编排官" `
  -Event "lifecycle:$current->$Lifecycle" -Reference $decId)

$quote = $ConfirmationQuote.Trim() -replace '\|', "/"
$record = @"
### $decId — lifecycle $current -> $Lifecycle

| Field | Value |
|-------|-------|
| Recorded at | $stamp |
| Decision maker | $DecisionMaker |
| Type | lifecycle |
| Context | machine cache update after conversational confirmation |
| Decision | Set lifecycle from $current to $Lifecycle. $Reason |
| Alternatives | remain $current |
| Consequences | paused blocks delivery writes; cancelled allows cancellation records only; archived is read-only until reactivation |
| Affected gate IDs | none (lifecycle is not a delivery gate) |
| Superseded approval IDs | none |
| Risk owner | $DecisionMaker |
| Compensating controls | scripts enforce write-stop; session-start warns |
| Expiry / review trigger | next conversational lifecycle change |
| Explicit confirmation quote | $quote |

This record does not approve INTAKE_COMPLETE, REQ_SIGNOFF, or any other delivery gate.
"@
Add-MarkdownRecord -Path $decisionsFile -Text $record

[pscustomobject]@{
  slug = $Slug
  from = $current
  lifecycle = $Lifecycle
  decision_id = $decId
  note = "Lifecycle recorded. Delivery gates remain conversational and unchanged."
} | ConvertTo-Json -Compress
exit 0
