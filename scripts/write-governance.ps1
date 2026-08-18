# Write governance / UI-input machine cache. Evidence only; never a gate.
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9-]*$")][string]$Slug,
  [string]$SopRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [ValidateSet("public", "internal", "confidential", "restricted")]
  [string]$DataClassification,
  [string[]]$RegulatedData,
  [string]$Residency,
  [string]$Retention,
  [string]$AccessAudit,
  [string]$ThirdPartyTransfer,
  [string]$ComplianceOwner,
  [ValidateSet("complete", "partial", "none")]
  [string]$UiInputMode,
  [string]$WaiverId
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\project-state.ps1")

$projectRoot = Join-Path $SopRoot "projects\$Slug"
Assert-ProjectWritable -ProjectRoot $projectRoot -Intent delivery
$stateFile = Join-Path $projectRoot "state.json"
$sopFile = Join-Path $projectRoot "SOP.md"
if (-not (Test-Path -LiteralPath $stateFile)) { throw "state.json missing: $stateFile" }

$state = Read-ProjectStateFile $stateFile
if (-not (Get-JsonProperty $state "governance")) {
  $state | Add-Member -NotePropertyName governance -NotePropertyValue ([pscustomobject]@{}) -Force
}
$gov = $state.governance
if ($PSBoundParameters.ContainsKey("DataClassification")) {
  $gov | Add-Member -NotePropertyName data_classification -NotePropertyValue $DataClassification -Force
  [void](Update-SopFieldRow -SopPath $sopFile -Field "Data classification" -Value $DataClassification)
}
if ($PSBoundParameters.ContainsKey("RegulatedData")) {
  $gov | Add-Member -NotePropertyName regulated_data -NotePropertyValue @($RegulatedData) -Force
  $regText = if ($RegulatedData.Count -eq 0) { "none" } else { ($RegulatedData -join ", ") }
  [void](Update-SopFieldRow -SopPath $sopFile -Field "Regulated data" -Value $regText)
}
if ($PSBoundParameters.ContainsKey("Residency")) {
  $gov | Add-Member -NotePropertyName residency -NotePropertyValue $Residency -Force
}
if ($PSBoundParameters.ContainsKey("Retention")) {
  $gov | Add-Member -NotePropertyName retention -NotePropertyValue $Retention -Force
  $resRet = @($Residency, $Retention) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  if ($resRet.Count -gt 0) {
    [void](Update-SopFieldRow -SopPath $sopFile -Field "Residency / retention" -Value ($resRet -join " / "))
  }
}
if ($PSBoundParameters.ContainsKey("AccessAudit")) {
  $gov | Add-Member -NotePropertyName access_audit -NotePropertyValue $AccessAudit -Force
  [void](Update-SopFieldRow -SopPath $sopFile -Field "Access / audit" -Value $AccessAudit)
}
if ($PSBoundParameters.ContainsKey("ThirdPartyTransfer")) {
  $gov | Add-Member -NotePropertyName third_party_transfer -NotePropertyValue $ThirdPartyTransfer -Force
  [void](Update-SopFieldRow -SopPath $sopFile -Field "Third-party transfer" -Value $ThirdPartyTransfer)
}
if ($PSBoundParameters.ContainsKey("ComplianceOwner")) {
  $gov | Add-Member -NotePropertyName compliance_owner -NotePropertyValue $ComplianceOwner -Force
  [void](Update-SopFieldRow -SopPath $sopFile -Field "Compliance owner" -Value $ComplianceOwner)
}
if ($PSBoundParameters.ContainsKey("UiInputMode")) {
  $state | Add-Member -NotePropertyName ui_input_mode -NotePropertyValue $UiInputMode -Force
  [void](Update-SopFieldRow -SopPath $sopFile -Field "UI input mode" -Value $UiInputMode)
}
if ($PSBoundParameters.ContainsKey("WaiverId") -and -not [string]::IsNullOrWhiteSpace($WaiverId)) {
  if ($WaiverId -notmatch '^DEC-[A-Za-z0-9_-]+$') { throw "WaiverId must be DEC-..." }
  $ids = New-Object System.Collections.Generic.List[string]
  foreach ($item in @((Get-JsonProperty $gov "active_waiver_ids"))) {
    if ($item) { $ids.Add([string]$item) }
  }
  if (-not $ids.Contains($WaiverId)) { $ids.Add($WaiverId) }
  $gov | Add-Member -NotePropertyName active_waiver_ids -NotePropertyValue @($ids) -Force
  [void](Update-SopFieldRow -SopPath $sopFile -Field "Active waiver IDs" -Value ($ids -join ", "))
}

$stamp = [DateTimeOffset]::UtcNow.ToString("o")
$state = Ensure-StateTimestamps $state
$state.timestamps | Add-Member -NotePropertyName updated_at -NotePropertyValue $stamp -Force
[void](Write-CanonicalState -Path $stateFile -Slug $Slug -State $state -RepoRoot $SopRoot)

[pscustomobject]@{
  slug = $Slug
  ui_input_mode = Get-JsonProperty $state "ui_input_mode"
  data_classification = Get-JsonProperty $gov "data_classification"
  note = "Machine cache only. REQ_SIGNOFF / ARCH_SIGNOFF remain conversational."
} | ConvertTo-Json -Compress
exit 0
