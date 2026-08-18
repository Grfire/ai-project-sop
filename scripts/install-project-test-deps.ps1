# Install per-project Playwright product-test dependencies from the lockfile.
# Evidence only: never treats install success as a human gate.
param(
  [string]$ProductDir,
  [string]$Slug,
  [string]$SopRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$NpmRegistry = "https://registry.npmmirror.com",
  [string]$PlaywrightDownloadHost = "https://npmmirror.com/mirrors/playwright",
  [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProductDir)) {
  if ([string]::IsNullOrWhiteSpace($Slug)) {
    throw "Provide -ProductDir or -Slug"
  }
  $ProductDir = Join-Path $SopRoot "projects\$Slug\test\product"
}

if (-not (Test-Path -LiteralPath (Join-Path $ProductDir "package.json"))) {
  Write-Output "SKIP product deps: no package.json under $ProductDir"
  exit 0
}

$lockfile = $null
foreach ($name in @("package-lock.json", "npm-shrinkwrap.json", "pnpm-lock.yaml", "yarn.lock")) {
  $candidate = Join-Path $ProductDir $name
  if (Test-Path -LiteralPath $candidate) {
    $lockfile = $name
    break
  }
}
if (-not $lockfile) {
  throw "Product tests require a lockfile in $ProductDir (package-lock.json preferred)"
}

$nodeModules = Join-Path $ProductDir "node_modules"
$playwrightPkg = Join-Path $nodeModules "@playwright\test"

function Test-PlaywrightChromium {
  $roots = [System.Collections.Generic.List[string]]::new()
  if (-not [string]::IsNullOrWhiteSpace($env:PLAYWRIGHT_BROWSERS_PATH)) {
    $roots.Add($env:PLAYWRIGHT_BROWSERS_PATH)
  }
  if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    $roots.Add((Join-Path $env:LOCALAPPDATA "ms-playwright"))
  }
  if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
    $roots.Add((Join-Path $env:USERPROFILE "AppData\Local\ms-playwright"))
  }
  $home = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
  if ($home) {
    $roots.Add((Join-Path $home ".cache\ms-playwright"))
    $roots.Add((Join-Path $home "Library\Caches\ms-playwright"))
  }
  foreach ($root in $roots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $hit = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -like "chromium-*" }
    if ($hit) { return $true }
  }
  return $false
}

if ($CheckOnly) {
  if (-not (Test-Path -LiteralPath $playwrightPkg)) {
    throw "CheckOnly: node_modules/@playwright/test missing in $ProductDir (run install-project-test-deps.ps1)"
  }
  if (-not (Test-PlaywrightChromium)) {
    throw "CheckOnly: Playwright Chromium is not installed"
  }
  Write-Output "OK product deps present: $ProductDir"
  exit 0
}

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  throw "npm is required to install product test dependencies"
}

Push-Location $ProductDir
try {
  $env:PLAYWRIGHT_DOWNLOAD_HOST = $PlaywrightDownloadHost
  $env:PLAYWRIGHT_DOWNLOAD_CONNECTION_TIMEOUT = "120000"
  if ($lockfile -eq "package-lock.json" -or $lockfile -eq "npm-shrinkwrap.json") {
    Write-Output "npm ci ($lockfile, registry $NpmRegistry) in $ProductDir ..."
    npm ci --registry $NpmRegistry --no-fund --no-audit
  } else {
    Write-Output "npm install ($lockfile, registry $NpmRegistry) in $ProductDir ..."
    npm install --registry $NpmRegistry --no-fund --no-audit
  }
  if ($LASTEXITCODE -ne 0) {
    throw "npm install/ci failed for $ProductDir"
  }
  if (-not (Test-Path -LiteralPath $playwrightPkg)) {
    throw "Playwright package missing after install: $playwrightPkg"
  }
  Write-Output "playwright install chromium ..."
  npx --yes --registry $NpmRegistry playwright install chromium
  if ($LASTEXITCODE -ne 0) {
    throw "Playwright Chromium install failed for $ProductDir"
  }
  if (-not (Test-PlaywrightChromium)) {
    throw "Playwright Chromium still missing after install"
  }
} finally {
  Remove-Item Env:PLAYWRIGHT_DOWNLOAD_HOST -ErrorAction SilentlyContinue
  Remove-Item Env:PLAYWRIGHT_DOWNLOAD_CONNECTION_TIMEOUT -ErrorAction SilentlyContinue
  Pop-Location
}

Write-Output "OK product deps: $ProductDir"
exit 0
