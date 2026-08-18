param(
  [Parameter(Mandatory = $true)][string]$IntakePath,
  [string]$PythonExecutable
)

$ErrorActionPreference = "Stop"
$intake = (Resolve-Path $IntakePath).Path
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

$schemaValidator = Join-Path $PSScriptRoot "validate-intake-schema.py"
if (-not (Test-Path -LiteralPath $schemaValidator -PathType Leaf)) {
  $errors.Add("Missing intake schema validator: $schemaValidator")
} else {
  $py = $null
  $pythonCandidates = if ($PSBoundParameters.ContainsKey("PythonExecutable")) {
    @($PythonExecutable)
  } else {
    @("python", "py", "python3")
  }
  foreach ($name in $pythonCandidates) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($command) { $py = $command.Source; break }
  }
  if ($py) {
    $schemaOutput = & $py $schemaValidator $intake 2>&1
    if ($LASTEXITCODE -ne 0) {
      foreach ($line in @($schemaOutput)) {
        $text = [string]$line
        if ($text -match '^ERROR\s+(.*)$') { $errors.Add($Matches[1]) }
        elseif ($text.Trim()) { $errors.Add($text.Trim()) }
      }
    }
  } else {
    $requested = if ($PythonExecutable) { " '$PythonExecutable'" } else { "" }
    $errors.Add("Python$requested is unavailable; intake JSON Schema / SOURCE.md / placeholder checks are mandatory")
  }
}

function Read-RequiredText([string]$RelativePath, [int]$MinimumLength = 80) {
  $fullPath = Join-Path $intake $RelativePath
  if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
    $errors.Add("Missing $RelativePath")
    return ""
  }
  $text = Get-Content -LiteralPath $fullPath -Raw -Encoding utf8
  if ($text -match 'INTAKE_PLACEHOLDER|E-TODO|pending evidence review') {
    $errors.Add("$RelativePath still contains intake placeholder content")
  }
  if ($text.Trim().Length -lt $MinimumLength) {
    $errors.Add("$RelativePath is too short to demonstrate completed evidence review")
  }
  return $text
}

$manifestPath = Join-Path $intake "manifest.json"
$ledgerPath = Join-Path $intake "reading-ledger.csv"
$manifest = $null
$rows = @()
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
  $errors.Add("Missing manifest.json")
} else {
  try {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 |
      ConvertFrom-Json
  } catch {
    $errors.Add("manifest.json is not valid JSON")
  }
}
if (-not (Test-Path -LiteralPath $ledgerPath -PathType Leaf)) {
  $errors.Add("Missing reading-ledger.csv")
} else {
  try {
    $rows = @(Import-Csv -LiteralPath $ledgerPath -Encoding utf8)
  } catch {
    $errors.Add("reading-ledger.csv could not be parsed")
  }
}

$requiredColumns = @(
  "path", "bytes", "modified_utc", "extension", "sha256", "class", "status",
  "reason", "evidence_ids", "read_at"
)
if ($rows.Count -gt 0) {
  $columns = @($rows[0].PSObject.Properties.Name)
  foreach ($column in $requiredColumns) {
    if ($column -notin $columns) { $errors.Add("Ledger column missing: $column") }
  }
}

$pendingRows = @($rows | Where-Object status -eq "pending")
if ($pendingRows.Count -gt 0) {
  $errors.Add("Eligible pending ledger rows: $($pendingRows.Count)")
}
$terminalStatuses = @(
  "read", "indexed", "extracted-read", "skipped-sensitive",
  "skipped-generated", "unsupported"
)
$validStatuses = @("pending", "removed-at-source") + $terminalStatuses
foreach ($row in $rows) {
  if ($row.status -notin $validStatuses) {
    $errors.Add("Ledger '$($row.path)' has invalid status '$($row.status)'")
  }
  if (($row.status -in @("read", "extracted-read")) -and -not $row.evidence_ids) {
    $errors.Add("Ledger '$($row.path)' status '$($row.status)' lacks evidence_ids")
  }
  if (($row.status -in $terminalStatuses) -and -not $row.read_at) {
    $errors.Add("Ledger '$($row.path)' terminal status lacks read_at")
  }
  if (($row.status -in @("skipped-sensitive", "skipped-generated", "unsupported")) -and
      -not $row.reason) {
    $errors.Add("Ledger '$($row.path)' exclusion lacks a reason")
  }
  if (($row.status -eq "removed-at-source") -and
      $row.reason -notmatch "absent from the current source") {
    $errors.Add("Ledger '$($row.path)' removed-at-source status lacks the required source-removal reason")
  }
  if (($row.status -eq "skipped-sensitive") -and $row.sha256) {
    $errors.Add("Sensitive ledger '$($row.path)' must not contain a hash")
  }
}

if ($null -ne $manifest) {
  if ([int]$manifest.version -ne 2) { $errors.Add("Manifest version must be 2") }
  if (-not $manifest.source_path) { $errors.Add("Manifest source_path is missing") }
  if ($null -eq $manifest.limits) { $errors.Add("Manifest limits contract is missing") }
  if ($null -eq $manifest.scan) { $errors.Add("Manifest scan contract is missing") }
  if ($manifest.scan.is_truncated -eq $true) {
    $errors.Add("Manifest reports a truncated scan: $($manifest.scan.truncation_reason)")
  }
  if ([int]$manifest.eligible_pending -ne $pendingRows.Count) {
    $errors.Add("Manifest eligible_pending does not match ledger")
  }
  $removedRows = @($rows | Where-Object status -eq "removed-at-source")
  if ([int]$manifest.removed_at_source -ne $removedRows.Count) {
    $errors.Add("Manifest removed_at_source does not match ledger")
  }
  if ([int]$manifest.total_ledger_files -ne $rows.Count) {
    $errors.Add("Manifest total_ledger_files does not match ledger")
  }
  $actualCounts = @{}
  foreach ($group in $rows | Group-Object status) { $actualCounts[$group.Name] = $group.Count }
  foreach ($status in $actualCounts.Keys) {
    $manifestCount = $manifest.statuses.PSObject.Properties[$status].Value
    if ([int]$manifestCount -ne [int]$actualCounts[$status]) {
      $errors.Add("Manifest status count '$status' does not match ledger")
    }
  }
}

$actualState = Read-RequiredText "actual-state.md" 200
$evidenceText = Read-RequiredText "evidence-map.md" 120
$gapText = Read-RequiredText "stage-gap-matrix.md" 180
$supplementText = Read-RequiredText "supplement-plan.md" 180

$definedEvidence = @{}
foreach ($match in [regex]::Matches($evidenceText, '(?m)^\|\s*((?:E|BACKFILL)-[A-Za-z0-9_-]+)\s*\|')) {
  $definedEvidence[$match.Groups[1].Value] = $true
}
if ($definedEvidence.Count -eq 0) {
  $errors.Add("evidence-map.md defines no evidence IDs")
}

$removedEvidence = @{}
$activeEvidence = @{}
foreach ($row in $rows | Where-Object { $_.evidence_ids }) {
  foreach ($id in @($row.evidence_ids -split '[,; ]+' | Where-Object { $_ })) {
    if ($row.status -eq "removed-at-source") {
      $removedEvidence[$id] = $true
    } else {
      $activeEvidence[$id] = $true
    }
  }
}
foreach ($id in $removedEvidence.Keys) {
  if ($definedEvidence.ContainsKey($id)) {
    $warnings.Add("evidence-map.md retains '$id' from a removed-at-source ledger path; treat it as historical evidence only")
  }
}

$referencesToCheck = [System.Collections.Generic.List[object]]::new()
foreach ($row in $rows | Where-Object { $_.evidence_ids }) {
  $referencesToCheck.Add([pscustomobject]@{
    source = "ledger:$($row.path)"
    ids = $row.evidence_ids
  })
}
foreach ($relative in @("actual-state.md", "stage-gap-matrix.md", "supplement-plan.md")) {
  $text = switch ($relative) {
    "actual-state.md" { $actualState }
    "stage-gap-matrix.md" { $gapText }
    default { $supplementText }
  }
  $ids = @([regex]::Matches($text, '(?:E|BACKFILL)-[A-Za-z0-9_-]+') |
    ForEach-Object { $_.Value } | Select-Object -Unique)
  if ($ids.Count -eq 0) {
    $warnings.Add("$relative has no evidence references")
  } else {
    $referencesToCheck.Add([pscustomobject]@{ source = $relative; ids = ($ids -join ";") })
  }
}

$handoffStages = @("REQ", "UI", "ARCH", "TEST", "CODE", "DOCS")
foreach ($stage in $handoffStages) {
  $relative = "handoffs/$stage.md"
  $text = Read-RequiredText $relative 180
  $ids = @([regex]::Matches($text, '(?:E|BACKFILL)-[A-Za-z0-9_-]+') |
    ForEach-Object { $_.Value } | Select-Object -Unique)
  if ($ids.Count -eq 0) {
    $errors.Add("$relative has no evidence references")
  } else {
    $referencesToCheck.Add([pscustomobject]@{ source = $relative; ids = ($ids -join ";") })
  }
}

foreach ($reference in $referencesToCheck) {
  foreach ($id in @($reference.ids -split '[,; ]+' | Where-Object { $_ })) {
    if (-not $definedEvidence.ContainsKey($id)) {
      $errors.Add("$($reference.source) references undefined evidence ID '$id'")
    }
    if (
      $reference.source -like "handoffs/*" -and
      $removedEvidence.ContainsKey($id) -and
      -not $activeEvidence.ContainsKey($id)
    ) {
      $errors.Add("$($reference.source) references evidence ID '$id' backed only by a removed-at-source path")
    }
  }
}

$report = [ordered]@{
  validator = "validate-intake-artifacts"
  intake_path = $intake
  checked_at = [DateTime]::UtcNow.ToString("o")
  artifact_evidence_valid = ($errors.Count -eq 0)
  human_gate_approved = $false
  note = "Completeness/provenance evidence only; human gates are checked in conversation and Markdown checkboxes are not parsed."
  ledger = [ordered]@{
    rows = $rows.Count
    eligible_pending = $pendingRows.Count
    removed_at_source = @($rows | Where-Object status -eq "removed-at-source").Count
  }
  handoffs_checked = $handoffStages
  errors = $errors
  warnings = $warnings
}
$report | ConvertTo-Json -Depth 8
if ($errors.Count -gt 0) { exit 1 }
exit 0
