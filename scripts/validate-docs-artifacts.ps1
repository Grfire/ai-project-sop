param(
  [Parameter(Mandatory = $true)][string]$DocsPath
)

$ErrorActionPreference = "Stop"
$docs = (Resolve-Path $DocsPath).Path
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$registryPath = Join-Path $docs "registry.md"
$requiredHeaders = @(
  "Type", "Latest output", "Style card", "Sources",
  "Source revision", "Output revision", "Stale"
)

if (-not (Test-Path -LiteralPath $registryPath)) {
  $errors.Add("Missing registry.md")
} else {
  $lines = @(Get-Content -LiteralPath $registryPath -Encoding utf8)
  $headerIndex = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\|\s*Type\s*\|') { $headerIndex = $i; break }
  }
  if ($headerIndex -lt 0) {
    $errors.Add("registry.md missing Type header")
  } else {
    $headers = @($lines[$headerIndex].Trim().Trim("|").Split("|") | ForEach-Object { $_.Trim() })
    foreach ($required in $requiredHeaders) {
      if ($required -notin $headers) { $errors.Add("registry column missing: $required") }
    }
    for ($i = $headerIndex + 2; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -notmatch '^\s*\|') { break }
      $values = @($lines[$i].Trim().Trim("|").Split("|") | ForEach-Object { $_.Trim() })
      if ($values.Count -lt 2) { continue }
      $row = @{}
      for ($column = 0; $column -lt [Math]::Min($headers.Count, $values.Count); $column++) {
        $row[$headers[$column]] = $values[$column]
      }
      if (-not $row.Type) { continue }
      foreach ($field in @("Latest output", "Style card")) {
        $relative = $row[$field]
        if (-not $relative) {
          $errors.Add("$($row.Type): $field is empty")
          continue
        }
        $candidate = if ([IO.Path]::IsPathRooted($relative)) { $relative } else { Join-Path $docs $relative }
        if (-not (Test-Path -LiteralPath $candidate)) {
          $errors.Add("$($row.Type): $field does not exist: $relative")
        }
      }
      if (-not $row["Source revision"] -or -not $row["Output revision"]) {
        $errors.Add("$($row.Type): Source revision and Output revision are required")
      }
      $stale = [string]$row.Stale
      if ($stale -notin @("yes", "no")) {
        $errors.Add("$($row.Type): Stale must be yes or no")
      } elseif ($stale -eq "yes") {
        $warnings.Add("$($row.Type): marked stale against upstream revision")
      }
    }
  }
}

$report = [ordered]@{
  validator = "validate-docs-artifacts"
  docs_path = $docs
  checked_at = [DateTime]::UtcNow.ToString("o")
  artifact_evidence_valid = ($errors.Count -eq 0)
  human_gate_approved = $false
  note = "Freshness/path evidence only; DOCS_COMPLETE remains conversational."
  errors = $errors
  warnings = $warnings
}
$report | ConvertTo-Json -Depth 6
if ($errors.Count -gt 0) { exit 1 }
exit 0
