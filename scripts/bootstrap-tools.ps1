# Thin Windows wrapper; scripts/bootstrap.py is the cross-platform core.
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $python) {
  Write-Error "Python >=3.10 is required."
  exit 2
}
& $python.Source (Join-Path $root "scripts\bootstrap.py") --root $root @Arguments
exit $LASTEXITCODE
