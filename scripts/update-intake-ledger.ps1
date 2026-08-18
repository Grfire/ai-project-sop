param(
  [Parameter(Mandatory = $true)][string]$IntakePath,
  [Parameter(Mandatory = $true)][string]$Path,
  [Parameter(Mandatory = $true)]
  [ValidateSet("read", "indexed", "extracted-read", "skipped-sensitive", "skipped-generated", "unsupported")]
  [string]$Status,
  [string[]]$EvidenceIds = @(),
  [datetime]$ReadAt = [DateTime]::UtcNow,
  [string]$Reason
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\project-state.ps1")
$intake = (Resolve-Path $IntakePath).Path
$projectRoot = Split-Path $intake -Parent
Assert-ProjectWritable -ProjectRoot $projectRoot -Intent delivery
$ledgerPath = Join-Path $intake "reading-ledger.csv"
$manifestPath = Join-Path $intake "manifest.json"
if (-not (Test-Path -LiteralPath $ledgerPath -PathType Leaf)) {
  throw "Missing reading ledger: $ledgerPath"
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
  throw "Missing manifest: $manifestPath"
}

$normalizedPath = $Path.Replace("\", "/").TrimStart("./")
$rows = @(Import-Csv -LiteralPath $ledgerPath -Encoding utf8)
$matches = @($rows | Where-Object { $_.path -eq $normalizedPath })
if ($matches.Count -ne 1) {
  throw "Expected exactly one ledger row for '$normalizedPath'; found $($matches.Count)"
}

$cleanEvidenceIds = @(
  $EvidenceIds |
    ForEach-Object { $_ -split "," } |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ } |
    Select-Object -Unique
)
if (($Status -in @("read", "extracted-read")) -and $cleanEvidenceIds.Count -eq 0) {
  throw "Status '$Status' requires at least one evidence ID"
}

$row = $matches[0]
$row.status = $Status
$row.read_at = $ReadAt.ToUniversalTime().ToString("o")
$row.evidence_ids = $cleanEvidenceIds -join ";"
if ($PSBoundParameters.ContainsKey("Reason")) {
  $row.reason = $Reason
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 |
  ConvertFrom-Json
$statusCounts = [ordered]@{}
foreach ($group in $rows | Group-Object status) {
  $statusCounts[$group.Name] = $group.Count
}
$manifest.statuses = [pscustomobject]$statusCounts
$manifest.eligible_pending = @($rows | Where-Object status -eq "pending").Count
$manifest.total_ledger_files = $rows.Count
$updatedAt = [DateTime]::UtcNow.ToString("o")
if ($manifest.PSObject.Properties.Name -contains "updated_at") {
  $manifest.updated_at = $updatedAt
} else {
  $manifest | Add-Member -NotePropertyName updated_at -NotePropertyValue $updatedAt
}

$ledgerTemp = "$ledgerPath.tmp"
$manifestTemp = "$manifestPath.tmp"
try {
  $rows | Sort-Object path |
    Export-Csv -LiteralPath $ledgerTemp -NoTypeInformation -Encoding utf8
  $manifest | ConvertTo-Json -Depth 12 |
    Set-Content -LiteralPath $manifestTemp -Encoding utf8
  Move-Item -LiteralPath $ledgerTemp -Destination $ledgerPath -Force
  Move-Item -LiteralPath $manifestTemp -Destination $manifestPath -Force
} finally {
  Remove-Item -LiteralPath $ledgerTemp, $manifestTemp -Force -ErrorAction SilentlyContinue
}

Write-Output "Updated '$normalizedPath' to '$Status'."
Write-Output "Eligible pending: $($manifest.eligible_pending)"
