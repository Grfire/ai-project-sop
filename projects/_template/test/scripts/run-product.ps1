param(
  [string]$Slug
)

$ErrorActionPreference = "Stop"
$arguments = @{ Mode = "product-only" }
if (-not [string]::IsNullOrWhiteSpace($Slug)) { $arguments.Slug = $Slug }
& (Join-Path $PSScriptRoot "run-all.ps1") @arguments
exit $LASTEXITCODE
