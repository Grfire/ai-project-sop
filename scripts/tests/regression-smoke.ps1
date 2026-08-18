$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("sop-regression-smoke-" + [guid]::NewGuid())
$shell = (Get-Process -Id $PID).Path

function Assert-PowerShellSyntax {
  param([string[]]$Paths)
  foreach ($path in $Paths) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
      (Resolve-Path $path),
      [ref]$tokens,
      [ref]$errors
    )
    if ($errors.Count -gt 0) {
      throw "PowerShell syntax error in ${path}: $($errors[0].Message)"
    }
  }
}

function Assert-Equal {
  param($Expected, $Actual, [string]$Message)
  if ($Expected -ne $Actual) {
    throw "$Message. Expected '$Expected', got '$Actual'."
  }
}

function Set-TextFileWithRetry {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Value
  )
  $utf8 = [Text.UTF8Encoding]::new($false)
  for ($attempt = 1; $attempt -le 20; $attempt++) {
    try {
      [IO.File]::WriteAllText($Path, $Value, $utf8)
      return
    } catch [IO.IOException] {
      if ($attempt -eq 20) { throw }
      Start-Sleep -Milliseconds 100
    }
  }
}

function New-RuntimeProject {
  param(
    [string]$Name,
    [string]$CodeTestCmd,
    [string]$AccessUrl = "http://127.0.0.1:18088",
    [string]$ProductTestCmd = "",
    [bool]$SkipHealthCheck = $true,
    [bool]$WithProductTests = $false,
    [bool]$WithPackageJson = $false
  )
  $projectRoot = Join-Path $tempRoot "projects\$Name"
  $testRoot = Join-Path $projectRoot "test"
  $productDir = Join-Path $testRoot "product"
  New-Item -ItemType Directory -Force -Path $testRoot, (Join-Path $productDir "tests") | Out-Null
  $skipHealth = if ($SkipHealthCheck) { '$true' } else { '$false' }
  @"
`$CodeRoot = `$PSScriptRoot
`$AccessUrl = "$AccessUrl"
`$CodeTestCmd = '$CodeTestCmd'
`$ProductDir = Join-Path `$PSScriptRoot "product"
`$StartCmd = ""
`$StopCmd = ""
`$HealthUrl = ""
`$StartupTimeoutSeconds = 5
`$ProductTestCmd = '$ProductTestCmd'
`$SkipHealthCheck = $skipHealth
`$CodeReportPath = ""
"@ | Set-Content -Path (Join-Path $testRoot "runtime.ps1") -Encoding utf8
  @{
    slug = $Name
    timestamps = @{
      last_code_change_at = [DateTimeOffset]::UtcNow.AddMinutes(-1).ToString("o")
      last_regression_at = $null
    }
  } | ConvertTo-Json | Set-Content -Path (Join-Path $projectRoot "state.json") -Encoding utf8
  if ($WithProductTests) {
    Set-Content -Path (Join-Path $productDir "tests\smoke.spec.ts") -Value "export {}" -Encoding utf8
  }
  if ($WithPackageJson) {
    '{"name":"smoke-product","private":true}' | Set-Content -Path (Join-Path $productDir "package.json") -Encoding utf8
  }
  $layer = if ($WithProductTests) { "both" } else { "code" }
  $productLine = if ($WithProductTests) { "    product: product/tests/smoke.spec.ts`r`n" } else { "" }
  @"
version: 1
slug: "$Name"
source:
  prd: E:/workspace/ai_req_analysis/projects/$Name/PRD.md
  arch: E:/workspace/ai_architecture_design/projects/$Name/design/05-api-data.md
  ui: E:/workspace/ai-font-design/projects/$Name/design/design-spec.md
generated_at: "2026-08-17T00:00:00Z"
cases:
  - id: AC-01
    title: Smoke configured suite
    layer: $layer
    priority: P0
    trace: [AC-01]
    code: echo-suite
$productLine    deferred: false
    notes: ""
"@ | Set-Content -Path (Join-Path $testRoot "catalog.yaml") -Encoding utf8
  return $testRoot
}

function Invoke-Runner {
  param(
    [string]$Slug,
    [switch]$SkipProduct,
    [switch]$SkipCode,
    [string]$Mode
  )
  $argList = @(
    "-NoProfile",
    "-File", (Join-Path $repoRoot "scripts\run-full-regression.ps1"),
    "-Slug", $Slug,
    "-SopRoot", $tempRoot
  )
  if ($SkipProduct) { $argList += "-SkipProduct" }
  if ($SkipCode) { $argList += "-SkipCode" }
  if ($Mode) { $argList += @("-Mode", $Mode) }
  $output = & $shell @argList
  $code = $LASTEXITCODE
  if ($output) { $output | ForEach-Object { Write-Host $_ } }
  return $code
}

try {
  Assert-PowerShellSyntax @(
    (Join-Path $repoRoot "scripts\run-full-regression.ps1"),
    (Join-Path $repoRoot "scripts\bootstrap-tools.ps1"),
    (Join-Path $repoRoot "scripts\touch-code-change.ps1"),
    (Join-Path $repoRoot "scripts\install-project-test-deps.ps1"),
    (Join-Path $repoRoot "scripts\lib\project-state.ps1"),
    (Join-Path $repoRoot "projects\_template\test\runtime.ps1"),
    (Join-Path $repoRoot "projects\_template\test\scripts\run-all.ps1"),
    (Join-Path $repoRoot "projects\_template\test\scripts\run-code.ps1"),
    (Join-Path $repoRoot "projects\_template\test\scripts\run-product.ps1")
  )

  $testScripts = Join-Path $tempRoot "projects\sample-app\test\scripts"
  $runnerDir = Join-Path $tempRoot "scripts"
  New-Item -ItemType Directory -Force -Path $testScripts, $runnerDir | Out-Null
  Copy-Item (Join-Path $repoRoot "projects\_template\test\scripts\run-all.ps1") $testScripts
  Copy-Item (Join-Path $repoRoot "projects\_template\test\scripts\run-code.ps1") $testScripts
  Copy-Item (Join-Path $repoRoot "projects\_template\test\scripts\run-product.ps1") $testScripts

  @'
param(
  [string]$Slug,
  [string]$SopRoot,
  [switch]$SkipProduct,
  [switch]$SkipCode,
  [string]$Mode
)
@{
  slug = $Slug
  sop_root = $SopRoot
  skip_product = [bool]$SkipProduct
  skip_code = [bool]$SkipCode
  mode = $Mode
} | ConvertTo-Json | Set-Content -Path $env:SOP_SMOKE_CAPTURE -Encoding utf8
exit 0
'@ | Set-Content -Path (Join-Path $runnerDir "run-full-regression.ps1") -Encoding utf8

  $capture = Join-Path $tempRoot "capture.json"
  $env:SOP_SMOKE_CAPTURE = $capture
  & $shell -NoProfile -File (Join-Path $testScripts "run-all.ps1")
  if ($LASTEXITCODE -ne 0) { throw "run-all auto-slug smoke failed with exit $LASTEXITCODE" }
  $auto = Get-Content -Raw $capture | ConvertFrom-Json
  Assert-Equal "sample-app" $auto.slug "run-all must resolve the project slug, not 'test'"

  & $shell -NoProfile -File (Join-Path $testScripts "run-all.ps1") -Slug "explicit-app" -Mode "product-only"
  if ($LASTEXITCODE -ne 0) { throw "run-all explicit-slug smoke failed with exit $LASTEXITCODE" }
  $explicit = Get-Content -Raw $capture | ConvertFrom-Json
  Assert-Equal "explicit-app" $explicit.slug "run-all must honor explicit -Slug"
  Assert-Equal "product-only" $explicit.mode "run-all must expose and forward -Mode"

  & $shell -NoProfile -File (Join-Path $testScripts "run-code.ps1")
  if ($LASTEXITCODE -ne 0) { throw "run-code wrapper smoke failed with exit $LASTEXITCODE" }
  $codeOnly = Get-Content -Raw $capture | ConvertFrom-Json
  Assert-Equal "code-only" $codeOnly.mode "run-code must use code-only mode"

  & $shell -NoProfile -File (Join-Path $testScripts "run-product.ps1")
  if ($LASTEXITCODE -ne 0) { throw "run-product wrapper smoke failed with exit $LASTEXITCODE" }
  $productOnly = Get-Content -Raw $capture | ConvertFrom-Json
  Assert-Equal "product-only" $productOnly.mode "run-product must use product-only mode"

  $runtimePath = Join-Path $repoRoot "projects\_template\test\runtime.ps1"
  . $runtimePath
  $expectedProductDir = Join-Path (Split-Path $runtimePath -Parent) "product"
  Assert-Equal $expectedProductDir $ProductDir "runtime ProductDir must be relative to test root"

  $templateProduct = Join-Path $repoRoot "projects\_template\test\product"
  $requiredProductFiles = @(
    "package.json",
    "package-lock.json",
    "playwright.config.ts",
    "tests\smoke.spec.ts"
  )
  foreach ($relativePath in $requiredProductFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $templateProduct $relativePath))) {
      throw "product template missing required file: $relativePath"
    }
  }
  if (Test-Path -LiteralPath (Join-Path $templateProduct "node_modules")) {
    throw "product template must not contain node_modules; dependencies are restored with npm ci"
  }
  $package = Get-Content -Raw (Join-Path $templateProduct "package.json") | ConvertFrom-Json
  $playwrightVersion = [string]$package.devDependencies.'@playwright/test'
  if ($playwrightVersion -notmatch '^\d+\.\d+\.\d+$') {
    throw "@playwright/test must be exact-pinned in package.json, got '$playwrightVersion'"
  }
  $lockedPlaywrightVersion = & python -c `
    "import json,sys; print(json.load(open(sys.argv[1], encoding='utf-8-sig'))['packages']['node_modules/@playwright/test']['version'])" `
    (Join-Path $templateProduct "package-lock.json")
  if ($LASTEXITCODE -ne 0) { throw "package-lock.json must be valid JSON" }
  Assert-Equal $playwrightVersion ([string]$lockedPlaywrightVersion) `
    "package-lock.json must lock the exact @playwright/test version"
  $configText = Get-Content -Raw (Join-Path $templateProduct "playwright.config.ts")
  if ($configText -notmatch 'ACCESS_URL' -or $configText -notmatch 'testDir') {
    throw "playwright.config.ts must configure ACCESS_URL and the tests directory"
  }
  $specText = Get-Content -Raw (Join-Path $templateProduct "tests\smoke.spec.ts")
  if ($specText -notmatch 'test\(' -or $specText -notmatch 'page\.goto') {
    throw "tests/smoke.spec.ts must contain a runnable browser smoke test"
  }

  $dualSkipRoot = New-RuntimeProject -Name "dual-skip-app" -CodeTestCmd "echo 1 passed"
  $exit = Invoke-Runner -Slug "dual-skip-app" -SkipProduct -SkipCode
  if ($exit -eq 0) { throw "SkipCode+SkipProduct must exit non-zero" }
  $dualSkipLast = Join-Path $dualSkipRoot "last-run.json"
  if (Test-Path -LiteralPath $dualSkipLast) {
    throw "dual skip must fail before writing last-run.json"
  }

  $codeOnlyRoot = New-RuntimeProject -Name "runtime-app" -CodeTestCmd "echo 1 passed"
  $exit = Invoke-Runner -Slug "runtime-app" -SkipProduct
  if ($exit -ne 0) { throw "code-only regression smoke failed with exit $exit" }
  $lastRun = Get-Content -Raw (Join-Path $codeOnlyRoot "last-run.json") | ConvertFrom-Json
  Assert-Equal "PASS" $lastRun.overall "code-only regression must pass"
  Assert-Equal "code-only" $lastRun.mode "code-only mode must be recorded"
  Assert-Equal 0 $lastRun.code.exit_code "code command exit code must be recorded"
  Assert-Equal 1 $lastRun.code.passed "obtainable code counts must be recorded"
  $updatedState = Get-Content -Raw (Join-Path $tempRoot "projects\runtime-app\state.json") | ConvertFrom-Json
  Assert-Equal "partial" $updatedState.regression.state "code-only PASS must not mark full REGRESSION passed"
  if ($updatedState.timestamps.last_regression_at) {
    throw "code-only PASS must not refresh last_regression_at"
  }

  $catalogCheck = Join-Path $tempRoot "catalog-valid.yaml"
  Copy-Item (Join-Path $repoRoot "scripts\tests\fixtures\catalog-valid.yaml") $catalogCheck
  & python (Join-Path $repoRoot ".cursor\skills\project-test\scripts\validate-test-artifacts.py") `
    $catalogCheck --last-run (Join-Path $codeOnlyRoot "last-run.json") --allow-unconfigured
  if ($LASTEXITCODE -ne 0) { throw "generated last-run.json failed schema validation" }

  $schemaGuardRoot = New-RuntimeProject -Name "schema-guard-app" -CodeTestCmd "echo 1 passed"
  $schemaGuardRuntime = Join-Path $schemaGuardRoot "runtime.ps1"
  $schemaGuardRuntimeText = (Get-Content -Raw $schemaGuardRuntime) -replace
    '\$AccessUrl = "http://127\.0\.0\.1:18088"',
    '$AccessUrl = @("invalid", "array")'
  Set-TextFileWithRetry -Path $schemaGuardRuntime -Value $schemaGuardRuntimeText
  $exit = Invoke-Runner -Slug "schema-guard-app" -Mode "code-only"
  if ($exit -eq 0) { throw "post-write last-run schema failure must fail the runner" }
  $schemaGuardRun = Get-Content -Raw (Join-Path $schemaGuardRoot "last-run.json") | ConvertFrom-Json
  Assert-Equal "FAIL" $schemaGuardRun.overall "schema guard failure must rewrite overall=FAIL"
  $schemaGuardState = Get-Content -Raw (Join-Path $tempRoot "projects\schema-guard-app\state.json") | ConvertFrom-Json
  if ($schemaGuardState.regression.state -eq "passed") {
    throw "post-write schema failure must never mark regression.state=passed"
  }
  if ($schemaGuardState.timestamps.last_regression_at) {
    throw "post-write schema failure must not refresh last_regression_at"
  }

  $zeroRoot = New-RuntimeProject -Name "zero-app" -CodeTestCmd "echo ok"
  $exit = Invoke-Runner -Slug "zero-app" -SkipProduct
  if ($exit -eq 0) { throw "zero-test regression smoke should fail" }
  $zeroRun = Get-Content -Raw (Join-Path $zeroRoot "last-run.json") | ConvertFrom-Json
  Assert-Equal "FAIL" $zeroRun.overall "zero executed tests must FAIL"
  $zeroState = Get-Content -Raw (Join-Path $tempRoot "projects\zero-app\state.json") | ConvertFrom-Json
  Assert-Equal "failed" $zeroState.regression.state "zero-test FAIL must write regression.state=failed"

  $failRoot = New-RuntimeProject -Name "fail-app" -CodeTestCmd "echo 1 passed"
  $exit = Invoke-Runner -Slug "fail-app" -SkipProduct
  if ($exit -ne 0) { throw "setup PASS for fail-downgrade smoke failed" }
  $failCode = Join-Path $tempRoot "fail-code.ps1"
  @'
Write-Output "0 passed 1 failed"
exit 1
'@ | Set-Content -Path $failCode -Encoding utf8
  $failRuntime = Join-Path $failRoot "runtime.ps1"
  $failRuntimeText = (Get-Content -Raw $failRuntime) -replace `
    "echo 1 passed", ("powershell -NoProfile -File `"$failCode`"")
  Set-TextFileWithRetry -Path $failRuntime -Value $failRuntimeText
  $exit = Invoke-Runner -Slug "fail-app" -SkipProduct
  if ($exit -eq 0) { throw "failing code suite should fail" }
  $failRun = Get-Content -Raw (Join-Path $failRoot "last-run.json") | ConvertFrom-Json
  Assert-Equal "FAIL" $failRun.overall "failed suite must write overall=FAIL"
  $failState = Get-Content -Raw (Join-Path $tempRoot "projects\fail-app\state.json") | ConvertFrom-Json
  Assert-Equal "failed" $failState.regression.state "FAIL must downgrade regression.state"

  $writeReport = Join-Path $tempRoot "write-product-report.ps1"
  @'
$target = $env:PLAYWRIGHT_JSON_OUTPUT_NAME
if ([string]::IsNullOrWhiteSpace($target)) { throw "PLAYWRIGHT_JSON_OUTPUT_NAME missing" }
@{ stats = @{ expected = 1; unexpected = 0; skipped = 0 } } |
  ConvertTo-Json -Depth 5 |
  Set-Content -Path $target -Encoding utf8
exit 0
'@ | Set-Content -Path $writeReport -Encoding utf8
  $productCmd = "powershell -NoProfile -File `"$writeReport`""
  $fullRoot = New-RuntimeProject -Name "full-app" -CodeTestCmd "echo 1 passed" `
    -ProductTestCmd $productCmd -WithProductTests $true
  $exit = Invoke-Runner -Slug "full-app"
  if ($exit -ne 0) { throw "full regression smoke failed with exit $exit" }
  $fullRun = Get-Content -Raw (Join-Path $fullRoot "last-run.json") | ConvertFrom-Json
  Assert-Equal "PASS" $fullRun.overall "full regression must pass"
  Assert-Equal "full" $fullRun.mode "full mode must be recorded"
  Assert-Equal "passed" $fullRun.code.status "full run must execute code suite"
  Assert-Equal "passed" $fullRun.product.status "full run must execute product suite"
  $fullState = Get-Content -Raw (Join-Path $tempRoot "projects\full-app\state.json") | ConvertFrom-Json
  Assert-Equal "passed" $fullState.regression.state "full PASS may stamp regression.state=passed"
  if (-not $fullState.timestamps.last_regression_at) {
    throw "full PASS must update last_regression_at"
  }

  $staleStatePath = Join-Path $tempRoot "projects\runtime-app\state.json"
  @{
    slug = "runtime-app"
    timestamps = @{
      last_code_change_at = [DateTimeOffset]::UtcNow.AddMinutes(5).ToString("o")
      last_regression_at = $null
    }
  } | ConvertTo-Json | Set-Content -Path $staleStatePath -Encoding utf8
  $exit = Invoke-Runner -Slug "runtime-app" -SkipProduct
  if ($exit -eq 0) { throw "stale regression smoke should fail" }
  $staleRun = Get-Content -Raw (Join-Path $codeOnlyRoot "last-run.json") | ConvertFrom-Json
  Assert-Equal "FAIL" $staleRun.overall "regression started before code timestamp must be stale"

  $sopPath = Join-Path $tempRoot "projects\runtime-app\SOP.md"
  @"
# runtime-app

| Event | When |
|-------|------|
| last_code_change_at | |
| last_regression_at | |
"@ | Set-Content -Path $sopPath -Encoding utf8
  "# Approvals" | Set-Content -Path `
    (Join-Path $tempRoot "projects\runtime-app\APPROVALS.md") -Encoding utf8
  "# Decisions" | Set-Content -Path `
    (Join-Path $tempRoot "projects\runtime-app\DECISIONS.md") -Encoding utf8
  $touchFixtureStatePath = Join-Path $tempRoot "projects\runtime-app\state.json"
  $touchFixtureState = Get-Content -LiteralPath $touchFixtureStatePath -Raw | ConvertFrom-Json
  $touchFixtureState.timestamps.last_code_change_at = [DateTimeOffset]::UtcNow.AddMinutes(-1).ToString("o")
  $touchFixtureState | ConvertTo-Json -Depth 10 |
    Set-Content -LiteralPath $touchFixtureStatePath -Encoding utf8
  $touchOut = & $shell -NoProfile -File (Join-Path $repoRoot "scripts\touch-code-change.ps1") `
    -Slug "runtime-app" -SopRoot $tempRoot `
    -DecisionMaker "tester" `
    -ConfirmationQuote "record runtime smoke change" `
    -Reason "regression smoke runtime fixture"
  if ($LASTEXITCODE -ne 0) { throw "touch-code-change failed: $touchOut" }
  if (($touchOut -join [Environment]::NewLine) -notmatch '"human_gate_approved":\s*false') {
    throw "touch-code-change must not claim human approval"
  }
  $touched = Get-Content -Raw (Join-Path $tempRoot "projects\runtime-app\state.json") | ConvertFrom-Json
  if ([string]::IsNullOrWhiteSpace($touched.timestamps.last_code_change_at)) {
    throw "touch-code-change must write state.json last_code_change_at"
  }
  $sopText = Get-Content -Raw $sopPath
  if ($sopText -notmatch [regex]::Escape($touched.timestamps.last_code_change_at)) {
    throw "touch-code-change must write the same timestamp into SOP.md"
  }

  $sessionRoot = Join-Path $tempRoot "session-root"
  $sessionProject = Join-Path $sessionRoot "projects\session-app"
  New-Item -ItemType Directory -Force -Path (Join-Path $sessionProject "test") | Out-Null
  "slug: session-app" | Set-Content -Path (Join-Path $sessionRoot "projects\CURRENT.md") -Encoding utf8
  @{
    slug = "session-app"
    current_stage = "TEST"
    mode = "regression"
    lifecycle = "active"
    timestamps = @{
      last_code_change_at = [DateTimeOffset]::UtcNow.AddMinutes(-2).ToString("o")
      last_regression_at = [DateTimeOffset]::UtcNow.AddMinutes(-1).ToString("o")
    }
    regression = @{ state = "passed"; last_run = "test/last-run.json" }
  } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $sessionProject "state.json") -Encoding utf8
  Copy-Item (Join-Path $repoRoot "scripts\tests\fixtures\last-run-valid.json") (Join-Path $sessionProject "test\last-run.json")
  $failLastRun = Get-Content -Raw (Join-Path $sessionProject "test\last-run.json") | ConvertFrom-Json
  $failLastRun.overall = "FAIL"
  $failLastRun | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $sessionProject "test\last-run.json") -Encoding utf8
  $sessionJson = & $shell -NoProfile -File (Join-Path $repoRoot ".cursor\hooks\session-start.ps1") -SopRoot $sessionRoot
  if ($sessionJson -notmatch "overall=FAIL") {
    throw "session-start must warn when last-run.json overall=FAIL. Output: $sessionJson"
  }

  $unconfRoot = New-RuntimeProject -Name "unconf-app" -CodeTestCmd "echo 1 passed"
  Copy-Item (Join-Path $repoRoot "projects\_template\test\catalog.yaml") (Join-Path $unconfRoot "catalog.yaml") -Force
  $exit = Invoke-Runner -Slug "unconf-app" -SkipProduct
  if ($exit -eq 0) { throw "unconfigured catalog must fail runner preflight" }
  $unconfRun = Get-Content -Raw (Join-Path $unconfRoot "last-run.json") | ConvertFrom-Json
  Assert-Equal "FAIL" $unconfRun.overall "unconfigured catalog must write overall=FAIL"

  $missingDeps = Join-Path $tempRoot "missing-product"
  New-Item -ItemType Directory -Force -Path $missingDeps | Out-Null
  '{"name":"missing","private":true}' | Set-Content -Path (Join-Path $missingDeps "package.json") -Encoding utf8
  & $shell -NoProfile -File (Join-Path $repoRoot "scripts\install-project-test-deps.ps1") `
    -ProductDir $missingDeps -CheckOnly
  if ($LASTEXITCODE -eq 0) { throw "CheckOnly should fail when lockfile and node_modules are missing" }

  Write-Output "Regression smoke tests passed."
} finally {
  Remove-Item Env:SOP_SMOKE_CAPTURE -ErrorAction SilentlyContinue
  Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}
