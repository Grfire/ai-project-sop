param(
  [string]$Slug,
  [ValidateSet("full", "code-only", "product-only")]
  [string]$Mode,
  [switch]$SkipProduct,
  [switch]$SkipCode
)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$dir = Get-Item $here
$runner = $null
while ($null -ne $dir) {
  $candidate = Join-Path $dir.FullName "scripts\run-full-regression.ps1"
  if (Test-Path $candidate) {
    $runner = $candidate
    $sopRoot = $dir.FullName
    break
  }
  $dir = $dir.Parent
}
if (-not $runner) { throw "Cannot find scripts/run-full-regression.ps1" }
if ([string]::IsNullOrWhiteSpace($Slug)) {
  $testRoot = (Resolve-Path (Join-Path $here "..")).Path
  $projectRoot = Split-Path $testRoot -Parent
  $Slug = Split-Path $projectRoot -Leaf
}
if ($Slug -eq "test") { throw "Resolved invalid slug 'test'; pass -Slug explicitly." }
$arguments = @{
  Slug = $Slug
  SopRoot = $sopRoot
  SkipProduct = $SkipProduct
  SkipCode = $SkipCode
}
if ($PSBoundParameters.ContainsKey("Mode")) {
  $arguments.Mode = $Mode
}
& $runner @arguments
exit $LASTEXITCODE
