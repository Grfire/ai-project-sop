# Append a decision/log entry for an already-cancelled project.
# This is the only post-cancellation writer and never changes lifecycle or gates.
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9-]*$")][string]$Slug,
  [Parameter(Mandatory = $true)][string]$DecisionMaker,
  [Parameter(Mandatory = $true)][string]$ConfirmationQuote,
  [Parameter(Mandatory = $true)][string]$Reason,
  [string]$SopRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$Reference = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\project-state.ps1")

if ([string]::IsNullOrWhiteSpace($DecisionMaker)) { throw "DecisionMaker is required from the conversation" }
if ([string]::IsNullOrWhiteSpace($ConfirmationQuote) -or $ConfirmationQuote.Trim().Length -lt 2) {
  throw "ConfirmationQuote from chat is required; this script only records an explicit cancellation follow-up."
}
if ([string]::IsNullOrWhiteSpace($Reason)) { throw "Reason is required" }

$projectRoot = Join-Path $SopRoot "projects\$Slug"
$stateFile = Join-Path $projectRoot "state.json"
$sopFile = Join-Path $projectRoot "SOP.md"
$decisionsFile = Join-Path $projectRoot "DECISIONS.md"
if (-not (Test-Path -LiteralPath $stateFile)) { throw "state.json missing: $stateFile" }

Assert-ProjectWritable -ProjectRoot $projectRoot -Intent cancellation
$state = Read-ProjectStateFile $stateFile
if ((Get-ProjectLifecycle $state) -ne "cancelled") {
  throw "Cancellation records may only be appended after lifecycle=cancelled."
}

$stamp = [DateTimeOffset]::UtcNow.ToString("o")
$decId = Get-NextRecordId -Path $decisionsFile -Prefix "DEC"
$safeQuote = $ConfirmationQuote.Trim() -replace '\|', "/"
$safeReason = $Reason.Trim() -replace '\|', "/"
$safeReference = $Reference.Trim() -replace '\|', "/"

$record = @"
### $decId — cancellation record

| Field | Value |
|-------|-------|
| Recorded at | $stamp |
| Decision maker | $DecisionMaker |
| Type | cancellation |
| Context | cancelled project follow-up |
| Decision | $safeReason |
| Affected gate IDs | none |
| Reference | $safeReference |
| Explicit confirmation quote | $safeQuote |

This append-only record does not reactivate the project and does not approve a delivery gate.
"@
Add-MarkdownRecord -Path $decisionsFile -Text $record
[void](Add-SopLogRow -SopPath $sopFile -When $stamp -Stage "SOP" -Role "orchestrator" `
  -Event "cancellation record" -Reference $decId)

[pscustomobject]@{
  slug = $Slug
  lifecycle = "cancelled"
  decision_id = $decId
  human_gate_approved = $false
  note = "Cancellation follow-up appended; lifecycle and delivery gates unchanged."
} | ConvertTo-Json -Compress
exit 0
