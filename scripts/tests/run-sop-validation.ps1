# Unified SOP validation entry. Runs every *-smoke.ps1 under scripts/tests.
# Machine evidence only; does not approve human gates.
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $here "..\..")).Path
$shell = (Get-Process -Id $PID).Path
$failed = [System.Collections.Generic.List[string]]::new()

Write-Output "=== SOP unified validation ($repoRoot) ==="

Get-ChildItem -LiteralPath $here -Filter "*-smoke.ps1" |
  Sort-Object Name |
  ForEach-Object {
    Write-Output ""
    Write-Output "=== $($_.Name) ==="
    & $shell -NoProfile -File $_.FullName
    if ($LASTEXITCODE -ne 0) {
      $failed.Add("$($_.Name) exit $LASTEXITCODE")
    }
  }

if ($failed.Count -gt 0) {
  Write-Output ""
  Write-Output "FAILED:"
  $failed | ForEach-Object { Write-Output " - $_" }
  exit 1
}
Write-Output ""
Write-Output "SOP unified validation passed."
exit 0
