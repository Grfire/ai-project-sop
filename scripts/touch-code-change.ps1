# Fail-closed runtime change transaction: invalidate governed caches first,
# preserve the reset decision trail, then stamp last_code_change_at.
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9-]*$")][string]$Slug,
  [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$DecisionMaker,
  [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ConfirmationQuote,
  [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Reason,
  [string]$SopRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$Timestamp
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\project-state.ps1")

$projectRoot = Join-Path $SopRoot "projects\$Slug"
Assert-ProjectWritable -ProjectRoot $projectRoot -Intent delivery
$stateFile = Join-Path $projectRoot "state.json"
$sopFile = Join-Path $projectRoot "SOP.md"
if (-not (Test-Path -LiteralPath $projectRoot)) {
  throw "Project root missing: $projectRoot"
}
if ([string]::IsNullOrWhiteSpace($DecisionMaker)) {
  throw "DecisionMaker identity from chat is required"
}
if ([string]::IsNullOrWhiteSpace($ConfirmationQuote) -or $ConfirmationQuote.Trim().Length -lt 2) {
  throw "ConfirmationQuote from chat is required; runtime evidence invalidation is not an approval."
}
if ([string]::IsNullOrWhiteSpace($Reason)) {
  throw "Reason for the runtime-affecting code change is required"
}

$stamp = if ([string]::IsNullOrWhiteSpace($Timestamp)) {
  [DateTimeOffset]::UtcNow.ToString("o")
} else {
  (Convert-ToUtcDate $Timestamp "Timestamp").ToString("o")
}

$existingState = Read-ProjectStateFile $stateFile
if ($null -eq $existingState) { throw "state.json missing or unreadable: $stateFile" }
$priorCodeAt = Convert-ToUtcDate `
  (Get-JsonProperty (Get-JsonProperty $existingState "timestamps") "last_code_change_at") `
  "state.timestamps.last_code_change_at"
$newCodeAt = Convert-ToUtcDate $stamp "Timestamp"
if ($priorCodeAt -and $newCodeAt -lt $priorCodeAt) {
  throw "Timestamp cannot move last_code_change_at backwards"
}

# Run reset in a child PowerShell process because apply-gate-reset.ps1 exits
# explicitly. If stamping later fails, the project remains safely invalidated.
$resetScript = Join-Path $PSScriptRoot "apply-gate-reset.ps1"
if (-not (Test-Path -LiteralPath $resetScript)) {
  throw "Required reset script missing: $resetScript"
}
$shell = (Get-Process -Id $PID).Path
$resetOutput = & $shell -NoProfile -File $resetScript `
  -Slug $Slug `
  -ChangeClass runtime_code `
  -DecisionMaker $DecisionMaker `
  -ConfirmationQuote $ConfirmationQuote `
  -Reason $Reason `
  -SopRoot $SopRoot
$resetExit = $LASTEXITCODE
if ($resetExit -ne 0) {
  throw "runtime_code gate reset failed before timestamp update: $($resetOutput -join ' ')"
}
try {
  $resetReport = ($resetOutput -join [Environment]::NewLine) | ConvertFrom-Json
} catch {
  throw "runtime_code gate reset returned invalid JSON; caches were invalidated but timestamp was not updated"
}

$updated = [System.Collections.Generic.List[string]]::new()
if (Test-Path -LiteralPath $stateFile) {
  $state = Read-ProjectStateFile $stateFile
  if ($null -eq $state) { throw "state.json unreadable: $stateFile" }
  $state = Ensure-StateTimestamps $state
  $state.timestamps | Add-Member -NotePropertyName last_code_change_at -NotePropertyValue $stamp -Force
  $state.timestamps | Add-Member -NotePropertyName updated_at -NotePropertyValue $stamp -Force
  [void](Write-CanonicalState -Path $stateFile -Slug $Slug -State $state -RepoRoot $SopRoot)
  $updated.Add("state.json")
}

if (Test-Path -LiteralPath $sopFile) {
  if (Update-SopTimestampRow -SopPath $sopFile -Field "last_code_change_at" -Timestamp $stamp) {
    $updated.Add("SOP.md")
  }
}

if ($updated.Count -eq 0) {
  throw "Neither state.json nor SOP.md last_code_change_at could be updated for $Slug"
}

[pscustomobject]@{
  slug = $Slug
  last_code_change_at = $stamp
  updated = @($updated)
  reset_gates = @("CODE_READY", "REGRESSION_PASS", "DOCS_COMPLETE")
  reset_decision_id = $resetReport.decision_id
  human_gate_approved = $false
  note = "Runtime evidence caches invalidated before timestamp update. Replacement gates require conversational confirmation."
} | ConvertTo-Json -Compress
exit 0
