# Bootstrap SOP toolchain. Safe to re-run.
param(
  [string]$SopRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$PipIndex,
  [string]$NpmRegistry,
  [string]$PlaywrightDownloadHost
)

$ErrorActionPreference = "Continue"
$fail = @()
$officialPipIndex = "https://pypi.org/simple"
$officialNpmRegistry = "https://registry.npmjs.org"

if ([string]::IsNullOrWhiteSpace($PipIndex)) {
  $PipIndex = if ($env:SOP_PIP_INDEX) { $env:SOP_PIP_INDEX } else { "https://pypi.tuna.tsinghua.edu.cn/simple" }
}
if ([string]::IsNullOrWhiteSpace($NpmRegistry)) {
  $NpmRegistry = if ($env:SOP_NPM_REGISTRY) { $env:SOP_NPM_REGISTRY } else { "https://registry.npmmirror.com" }
}
if ([string]::IsNullOrWhiteSpace($PlaywrightDownloadHost)) {
  $PlaywrightDownloadHost = if ($env:SOP_PLAYWRIGHT_DOWNLOAD_HOST) { $env:SOP_PLAYWRIGHT_DOWNLOAD_HOST } else { "https://npmmirror.com/mirrors/playwright" }
}

function Test-Cmd($Name) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd) {
    Write-Host "OK  $Name -> $($cmd.Source)"
    return $true
  }
  Write-Host "MISS $Name"
  return $false
}

Write-Output "=== SOP tool check ($SopRoot) ==="

if (-not (Test-Cmd "node")) { $fail += "Install Node.js (LTS)" }
if (-not (Test-Cmd "npm")) { $fail += "Install npm" }
if (-not (Test-Cmd "npx")) { $fail += "Install npx" }

$py = $null
foreach ($c in @("python", "py", "python3")) {
  if (Get-Command $c -ErrorAction SilentlyContinue) { $py = $c; break }
}
if ($py) {
  Write-Output "OK  python -> $py"
  Write-Output "pip install -r requirements.txt (mirror: $PipIndex) ..."
  & $py -m pip install `
    --disable-pip-version-check `
    --index-url $PipIndex `
    --timeout 60 `
    --retries 3 `
    -r (Join-Path $SopRoot "requirements.txt")
  if ($LASTEXITCODE -ne 0 -and $PipIndex -ne $officialPipIndex) {
    Write-Warning "pip mirror failed: $PipIndex. Retrying with $officialPipIndex."
    & $py -m pip install `
      --disable-pip-version-check `
      --index-url $officialPipIndex `
      --timeout 60 `
      --retries 1 `
      -r (Join-Path $SopRoot "requirements.txt")
  }
  if ($LASTEXITCODE -ne 0) {
    $fail += "pip install failed. Retry with -PipIndex '$officialPipIndex' or set SOP_PIP_INDEX."
  }
} else {
  $fail += "Install Python 3.11+"
}

if (-not (Test-Cmd "docker")) {
  Write-Output "WARN docker not on PATH (needed for CODE verify/handoff)"
} else {
  docker version --format "{{.Server.Version}}" 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Docker CLI is installed, but the engine is not reachable. Start Docker Desktop before container-based CODE verification."
  } else {
    Write-Output "OK  Docker engine reachable"
  }
}

$installDeps = Join-Path $SopRoot "scripts\install-project-test-deps.ps1"
$productDirs = [System.Collections.Generic.List[string]]::new()
$templateProduct = Join-Path $SopRoot "projects\_template\test\product"
if (Test-Path -LiteralPath (Join-Path $templateProduct "package.json")) {
  $productDirs.Add($templateProduct)
}
$projectsRoot = Join-Path $SopRoot "projects"
if (Test-Path -LiteralPath $projectsRoot) {
  Get-ChildItem -LiteralPath $projectsRoot -Directory |
    Where-Object { $_.Name -ne "_template" } |
    ForEach-Object {
      $dir = Join-Path $_.FullName "test\product"
      if (Test-Path -LiteralPath (Join-Path $dir "package.json")) {
        $productDirs.Add($dir)
      }
    }
}
if ((Get-Command npm -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $installDeps)) {
  foreach ($dir in $productDirs) {
    Write-Output "install product deps: $dir"
    & $installDeps -ProductDir $dir -NpmRegistry $NpmRegistry -PlaywrightDownloadHost $PlaywrightDownloadHost
    if ($LASTEXITCODE -ne 0 -and (
        $NpmRegistry -ne $officialNpmRegistry -or
        -not [string]::IsNullOrWhiteSpace($PlaywrightDownloadHost)
      )) {
      Write-Warning "npm/Playwright mirror failed for $dir. Retrying with the official npm registry and Playwright's default download host."
      & $installDeps -ProductDir $dir -NpmRegistry $officialNpmRegistry -PlaywrightDownloadHost ""
    }
    if ($LASTEXITCODE -ne 0) {
      $fail += "product deps failed: $dir. Retry with -NpmRegistry '$officialNpmRegistry' -PlaywrightDownloadHost '' or set SOP_NPM_REGISTRY/SOP_PLAYWRIGHT_DOWNLOAD_HOST."
    }
  }
} elseif ($productDirs.Count -gt 0 -and -not (Get-Command npm -ErrorAction SilentlyContinue)) {
  $fail += "Install npm (needed for product test dependencies)"
}

Write-Output ""
Write-Output "MCP: project .cursor/mcp.json registers playwright (@playwright/mcp)."
Write-Output "Enable Cursor Browser (cursor-ide-browser) in Customize if UI visual gate has no browser tools."
Write-Output "PPT engines stay in $env:USERPROFILE\.agents\skills\ppt-studio"
Write-Output ""

if ($fail.Count -gt 0) {
  Write-Output "ISSUES:"
  $fail | ForEach-Object { Write-Output " - $_" }
  exit 1
}
Write-Output "Bootstrap OK"
exit 0
