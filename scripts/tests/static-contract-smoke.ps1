$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$validator = Join-Path $repoRoot "scripts\validate-static-contracts.py"

$python = $null
foreach ($candidate in @("python", "py", "python3")) {
  $command = Get-Command $candidate -ErrorAction SilentlyContinue
  if ($command) {
    $python = $command.Source
    break
  }
}
if (-not $python) {
  throw "Python is required for static Skill/link/hook contract validation"
}

$output = & $python $validator
if ($LASTEXITCODE -ne 0) {
  throw "Static contract validator failed: $($output -join [Environment]::NewLine)"
}

try {
  $report = ($output -join [Environment]::NewLine) | ConvertFrom-Json
} catch {
  throw "Static contract validator returned invalid JSON"
}
if ($report.valid -ne $true) {
  throw "Static contract validator did not report valid=true"
}
if ($report.human_gate_approved -ne $false) {
  throw "Static validation must not claim human gate approval"
}
if ($report.skills_checked -lt 1 -or $report.markdown_links_checked -lt 1 -or
    $report.hook_targets_checked -lt 1) {
  throw "Static contract validator did not exercise every required contract class"
}

Write-Output "Static contract smoke tests passed."
exit 0
