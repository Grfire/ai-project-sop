# Record an applied intake supplement. Evidence/provenance only; never a gate.
param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9-]*$")][string]$Slug,
  [Parameter(Mandatory = $true)][string]$SupplementId,
  [Parameter(Mandatory = $true)][string]$CanonicalTarget,
  [Parameter(Mandatory = $true)][string]$BackfillId,
  [Parameter(Mandatory = $true)][string]$AppliedBy,
  [string]$SopRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [ValidateSet("REQ", "UI", "ARCH", "TEST", "CODE", "DOCS")]
  [string]$TargetStage,
  [string]$ConfirmedBy,
  [string]$Notes = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\project-state.ps1")

if ($SupplementId -notmatch '^SUP-[A-Za-z0-9_-]+$') { throw "SupplementId must be SUP-..." }
if ($BackfillId -notmatch '^BACKFILL-[A-Za-z0-9_-]+$') { throw "BackfillId must be BACKFILL-..." }

$projectRoot = Join-Path $SopRoot "projects\$Slug"
Assert-ProjectWritable -ProjectRoot $projectRoot -Intent delivery
$intake = Join-Path $projectRoot "intake"
$planPath = Join-Path $intake "supplement-plan.md"
$evidencePath = Join-Path $intake "evidence-map.md"
if (-not (Test-Path -LiteralPath $planPath)) { throw "Missing $planPath" }
if (-not (Test-Path -LiteralPath $evidencePath)) { throw "Missing $evidencePath" }

$evidenceText = [IO.File]::ReadAllText($evidencePath)
if ($evidenceText -notmatch [regex]::Escape($BackfillId)) {
  throw "BackfillId $BackfillId is not defined in evidence-map.md"
}

$stamp = [DateTimeOffset]::UtcNow.ToString("o")
$confirmer = if ([string]::IsNullOrWhiteSpace($ConfirmedBy)) { $AppliedBy } else { $ConfirmedBy }
$lines = [Collections.Generic.List[string]]::new()
foreach ($line in @(Get-Content -LiteralPath $planPath -Encoding utf8)) {
  $lines.Add([string]$line)
}
$headerIndex = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^\|\s*ID\s*\|\s*owner_stage\s*\|\s*canonical_target\s*\|') {
    $headerIndex = $i
    break
  }
}
if ($headerIndex -lt 0) { throw "Supplement action table header is missing" }
$headers = @($lines[$headerIndex].Trim().Trim("|").Split("|") | ForEach-Object { $_.Trim() })
$found = $false
$rowOwnerStage = $null
for ($i = $headerIndex + 2; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -notmatch '^\s*\|') { break }
  $values = @($lines[$i].Trim().Trim("|").Split("|") | ForEach-Object { $_.Trim() })
  if ($values.Count -ne $headers.Count) { continue }
  $row = @{}
  for ($column = 0; $column -lt $headers.Count; $column++) { $row[$headers[$column]] = $values[$column] }
  if ($row.ID -ne $SupplementId) { continue }
  $found = $true
  $rowOwnerStage = [string]$row.owner_stage
  if ($TargetStage -and $TargetStage -ne $rowOwnerStage) {
    throw "TargetStage $TargetStage does not match $SupplementId owner_stage $rowOwnerStage"
  }
  $ids = New-Object System.Collections.Generic.List[string]
  foreach ($item in @($row.evidence_ids -split '[,; ]+' | Where-Object { $_ })) {
    if (-not $ids.Contains($item)) { $ids.Add($item) }
  }
  if (-not $ids.Contains($BackfillId)) { $ids.Add($BackfillId) }
  $row.canonical_target = $CanonicalTarget
  $row.status = "applied"
  $row.evidence_ids = ($ids -join ";")
  if (-not $row.confirmed_by) { $row.confirmed_by = $confirmer }
  if (-not $row.confirmed_at) { $row.confirmed_at = $stamp }
  $row.applied_at = $stamp
  if ($Notes) { $row.notes = $Notes }
  $lines[$i] = "| " + (($headers | ForEach-Object { $row[$_] }) -join " | ") + " |"
  break
}
if (-not $found) { throw "Supplement $SupplementId not found" }

$utf8 = [Text.UTF8Encoding]::new($false)
$temp = "$planPath.$([Guid]::NewGuid().ToString('N')).tmp"
try {
  [IO.File]::WriteAllText($temp, (($lines -join "`r`n") + "`r`n"), $utf8)
  $validate = Join-Path $PSScriptRoot "validate-supplement.ps1"
  $validateArgs = @("-IntakePath", $intake, "-PlanPath", $temp)
  if ($TargetStage) { $validateArgs += @("-TargetStage", $TargetStage) }
  $output = & (Get-Process -Id $PID).Path -NoProfile -File $validate @validateArgs
  $code = $LASTEXITCODE
  $output | ForEach-Object { Write-Output $_ }
  if ($code -ne 0) {
    throw "Supplement validation failed; supplement-plan.md was not changed."
  }
  [IO.File]::Copy($temp, $planPath, $true)
} finally {
  if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
}

[pscustomobject]@{
  slug = $Slug
  supplement_id = $SupplementId
  backfill_id = $BackfillId
  canonical_target = $CanonicalTarget
  human_gate_approved = $false
  note = "Provenance recorded. Stage gates remain conversational."
} | ConvertTo-Json -Compress
exit 0
