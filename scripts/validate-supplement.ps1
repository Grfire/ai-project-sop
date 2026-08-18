param(
  [Parameter(Mandatory = $true)][string]$IntakePath,
  [ValidateSet("INTAKE", "REQ", "UI", "ARCH", "TEST", "CODE", "DOCS")]
  [string]$TargetStage,
  [string]$PlanPath
)

$ErrorActionPreference = "Stop"
$intake = (Resolve-Path $IntakePath).Path
$planPath = if ([string]::IsNullOrWhiteSpace($PlanPath)) {
  Join-Path $intake "supplement-plan.md"
} else {
  [IO.Path]::GetFullPath($PlanPath)
}
$evidencePath = Join-Path $intake "evidence-map.md"
$projectRoot = Split-Path $intake -Parent
$statePath = Join-Path $projectRoot "state.json"
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$state = $null
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
  try {
    $state = Get-Content -LiteralPath $statePath -Raw -Encoding utf8 | ConvertFrom-Json
  } catch {
    $errors.Add("state.json is not valid JSON; relative canonical targets cannot be resolved")
  }
}

function Resolve-CanonicalTarget {
  param([string]$Target, [string]$OwnerStage)
  if ([string]::IsNullOrWhiteSpace($Target)) { return $null }
  if ([IO.Path]::IsPathRooted($Target) -or $Target -match '^[A-Za-z]:[\\/]') {
    return [IO.Path]::GetFullPath($Target)
  }
  if ($null -eq $state) {
    throw "state.json is required to resolve relative canonical_target for owner_stage $OwnerStage"
  }
  $pathKey = $OwnerStage.ToLowerInvariant()
  $pathProperty = $state.paths.PSObject.Properties[$pathKey]
  if ($null -eq $pathProperty -or [string]::IsNullOrWhiteSpace([string]$pathProperty.Value)) {
    throw "state.json.paths.$pathKey is required to resolve owner_stage $OwnerStage"
  }
  $configuredRoot = [string]$pathProperty.Value
  $bundleRoot = Split-Path (Split-Path $projectRoot -Parent) -Parent
  $ownerRoot = if ($configuredRoot -match '^project://(.*)$') {
    $relative = $Matches[1].TrimStart("/", "\")
    if ($relative -match '(^|[\\/])\.\.([\\/]|$)') {
      throw "state.json.paths.$pathKey project URI escapes the project root"
    }
    [IO.Path]::GetFullPath((Join-Path $projectRoot $relative))
  } elseif ($configuredRoot -match '^bundle://(.*)$') {
    $relative = $Matches[1].TrimStart("/", "\")
    if ($relative -match '(^|[\\/])\.\.([\\/]|$)') {
      throw "state.json.paths.$pathKey bundle URI escapes the bundle root"
    }
    [IO.Path]::GetFullPath((Join-Path $bundleRoot $relative))
  } elseif ([IO.Path]::IsPathRooted($configuredRoot) -or $configuredRoot -match '^[A-Za-z]:[\\/]') {
    [IO.Path]::GetFullPath($configuredRoot)
  } else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $configuredRoot))
  }
  $resolved = [IO.Path]::GetFullPath((Join-Path $ownerRoot $Target))
  $rootPrefix = $ownerRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
  if (-not $resolved.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "canonical_target escapes state.json.paths.$pathKey"
  }
  return $resolved
}

if (-not (Test-Path -LiteralPath $planPath -PathType Leaf)) {
  $errors.Add("Missing supplement-plan.md")
}
if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
  $errors.Add("Missing evidence-map.md")
}

$evidenceIds = @{}
if (Test-Path -LiteralPath $evidencePath -PathType Leaf) {
  $evidenceText = Get-Content -LiteralPath $evidencePath -Raw -Encoding utf8
  foreach ($match in [regex]::Matches($evidenceText, '(?m)^\|\s*((?:E|BACKFILL)-[A-Za-z0-9_-]+)\s*\|')) {
    $evidenceIds[$match.Groups[1].Value] = $true
  }
}

$actions = @()
if (Test-Path -LiteralPath $planPath -PathType Leaf) {
  $lines = @(Get-Content -LiteralPath $planPath -Encoding utf8)
  $headerIndex = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\|\s*ID\s*\|\s*owner_stage\s*\|\s*canonical_target\s*\|') {
      $headerIndex = $i
      break
    }
  }
  if ($headerIndex -lt 0) {
    $errors.Add("Supplement action table header is missing or does not match the contract")
  } else {
    $headers = @($lines[$headerIndex].Trim().Trim("|").Split("|") | ForEach-Object { $_.Trim() })
    for ($i = $headerIndex + 2; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -notmatch '^\s*\|') { break }
      $values = @($lines[$i].Trim().Trim("|").Split("|") | ForEach-Object { $_.Trim() })
      if ($values.Count -ne $headers.Count) {
        $errors.Add("Malformed supplement table row at line $($i + 1)")
        continue
      }
      $action = [ordered]@{}
      for ($column = 0; $column -lt $headers.Count; $column++) {
        $action[$headers[$column]] = $values[$column]
      }
      $actions += [pscustomobject]$action
    }
  }
}

if ($actions.Count -eq 0) {
  $errors.Add("Supplement plan has no actions")
}
$validStatuses = @("proposed", "confirmed", "applied", "waived")
$validStages = @("INTAKE", "REQ", "UI", "ARCH", "TEST", "CODE", "DOCS")
foreach ($action in $actions) {
  $label = if ($action.ID) { $action.ID } else { "<missing ID>" }
  if ($action.ID -notmatch '^SUP-[A-Za-z0-9_-]+$') {
    $errors.Add("$label has an invalid action ID")
  }
  if ($action.owner_stage -notin $validStages) {
    $errors.Add("$label owner_stage must be INTAKE/REQ/UI/ARCH/TEST/CODE/DOCS")
  }
  if (-not $action.canonical_target -or $action.canonical_target -match '^(pending|todo|tbd)$') {
    $errors.Add("$label requires a non-placeholder canonical_target")
  }
  if ($action.status -notin $validStatuses) {
    $errors.Add("$label has invalid status '$($action.status)'")
  }
  $actionEvidence = @($action.evidence_ids -split '[,; ]+' | Where-Object { $_ })
  if ($actionEvidence.Count -eq 0 -or $actionEvidence -contains "E-TODO") {
    $errors.Add("$label requires non-placeholder evidence_ids")
  }
  foreach ($id in $actionEvidence) {
    if (-not $evidenceIds.ContainsKey($id)) {
      $errors.Add("$label references undefined evidence ID '$id'")
    }
  }
  if ($action.status -in @("confirmed", "applied", "waived")) {
    if (-not $action.confirmed_by) { $errors.Add("$label requires confirmed_by") }
    $confirmedAt = [datetime]::MinValue
    if (-not [datetime]::TryParse($action.confirmed_at, [ref]$confirmedAt)) {
      $errors.Add("$label requires an ISO-8601 confirmed_at")
    }
  }
  if ($action.status -eq "applied") {
    $appliedAt = [datetime]::MinValue
    if (-not [datetime]::TryParse($action.applied_at, [ref]$appliedAt)) {
      $errors.Add("$label requires an ISO-8601 applied_at")
    }
    if (@($actionEvidence | Where-Object { $_ -match '^BACKFILL-[A-Za-z0-9_-]+$' }).Count -eq 0) {
      $errors.Add("$label status applied requires a BACKFILL evidence ID")
    }
    try {
      $resolvedTarget = Resolve-CanonicalTarget $action.canonical_target $action.owner_stage
      if (-not $resolvedTarget -or -not (Test-Path -LiteralPath $resolvedTarget)) {
        $errors.Add("$label applied canonical_target does not exist in owner root: $($action.canonical_target)")
      }
    } catch {
      $errors.Add("$label canonical_target resolution failed: $($_.Exception.Message)")
    }
  }
  if (($action.status -eq "waived") -and
      (-not $action.notes -or $action.notes -match '^(pending|todo|tbd)$')) {
    $errors.Add("$label status waived requires a non-placeholder reason in notes")
  }
}

if ($TargetStage) {
  $related = @($actions | Where-Object { $_.owner_stage -eq $TargetStage })
  foreach ($action in $related) {
    $label = if ($action.ID) { $action.ID } else { "<missing ID>" }
    if ($action.status -notin @("applied", "waived")) {
      $errors.Add("$label must be applied or waived before entering $TargetStage (status='$($action.status)')")
    }
  }
  $otherOpen = @(
    $actions |
      Where-Object { $_.owner_stage -ne $TargetStage -and $_.status -in @("proposed", "confirmed") }
  )
  foreach ($action in $otherOpen) {
    $warnings.Add("$($action.ID) ($($action.owner_stage)/$($action.status)) remains open; it is not required for $TargetStage entry evidence")
  }
}

$report = [ordered]@{
  validator = "validate-supplement"
  intake_path = $intake
  target_stage = if ($TargetStage) { $TargetStage } else { $null }
  checked_at = [DateTime]::UtcNow.ToString("o")
  provenance_valid = ($errors.Count -eq 0)
  iteration_entry_evidence_valid = if ($TargetStage) { ($errors.Count -eq 0) } else { $null }
  human_gate_approved = $false
  note = "Evidence/provenance validation only; human gates are decided in conversation. Applied/waived status does not approve INTAKE_COMPLETE or any stage gate."
  action_count = $actions.Count
  errors = $errors
  warnings = $warnings
}
$report | ConvertTo-Json -Depth 8
if ($errors.Count -gt 0) { exit 1 }
exit 0
