param(
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9-]*$")][string]$Slug,
  [string]$SopRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [ValidateSet("full", "code-only", "product-only")]
  [string]$Mode,
  [switch]$SkipProduct,
  [switch]$SkipCode
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\project-state.ps1")

$testRoot = Join-Path $SopRoot "projects\$Slug\test"
$projectRoot = Split-Path $testRoot -Parent
$runtime = Join-Path $testRoot "runtime.ps1"
$outFile = Join-Path $testRoot "last-run.json"
$stateFile = Join-Path $projectRoot "state.json"
$sopFile = Join-Path $projectRoot "SOP.md"
$installDeps = Join-Path $PSScriptRoot "install-project-test-deps.ps1"

if (-not (Test-Path $testRoot)) {
  throw "Test pack missing: $testRoot - run project-test skill first."
}
Assert-ProjectWritable -ProjectRoot $projectRoot -Intent delivery

if ($PSBoundParameters.ContainsKey("Mode")) {
  switch ($Mode) {
    "full" {
      if ($SkipProduct -or $SkipCode) {
        throw "Mode=full cannot be combined with -SkipProduct or -SkipCode"
      }
    }
    "code-only" { $SkipProduct = $true; $SkipCode = $false }
    "product-only" { $SkipCode = $true; $SkipProduct = $false }
  }
} else {
  if ($SkipCode -and $SkipProduct) {
    throw "SkipCode and SkipProduct are mutually exclusive. Dual skip is not a regression run and must not exit 0."
  } elseif ($SkipCode) {
    $Mode = "product-only"
  } elseif ($SkipProduct) {
    $Mode = "code-only"
  } else {
    $Mode = "full"
  }
}

$CodeRoot = $null
$AccessUrl = $null
$CodeTestCmd = $null
$CodeReportPath = $null
$ProductTestCmd = $null
$ProductDir = Join-Path $testRoot "product"
$StartCmd = $null
$StopCmd = $null
$HealthUrl = $null
$SkipHealthCheck = $false
$startupTimeoutSeconds = 60
if (Test-Path $runtime) { . $runtime }
if ([string]::IsNullOrWhiteSpace($HealthUrl)) { $HealthUrl = $AccessUrl }
if (-not $ProductDir) { $ProductDir = Join-Path $testRoot "product" }
if ([string]::IsNullOrWhiteSpace($ProductTestCmd)) {
  $ProductTestCmd = "npx playwright test --reporter=json"
}

function Invoke-CatalogPreflight {
  $catalogPath = Join-Path $testRoot "catalog.yaml"
  if (-not (Test-Path -LiteralPath $catalogPath)) {
    return @("catalog: catalog.yaml missing; TEST_PACK is not configured")
  }
  $toolRoot = Split-Path $PSScriptRoot -Parent
  $validator = Join-Path $toolRoot ".cursor\skills\project-test\scripts\validate-test-artifacts.py"
  if (-not (Test-Path -LiteralPath $validator)) {
    return @("catalog: validator missing at $validator")
  }
  $py = Get-PythonCommand
  $argList = @($validator, $catalogPath, "--slug", $Slug, "--test-root", $testRoot)
  if (-not [string]::IsNullOrWhiteSpace($CodeRoot)) {
    $argList += @("--code-root", $CodeRoot)
  }
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & $py @argList 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previous
  }
  if ($code -eq 0) { return @() }
  $messages = New-Object System.Collections.Generic.List[string]
  $messages.Add("catalog: schema/trace/file-mapping preflight failed")
  foreach ($line in @($output)) {
    $text = [string]$line
    if ($text -match 'ERROR') { $messages.Add($text.Trim()) }
  }
  if ($messages.Count -eq 1) { $messages.Add((@($output) -join " ").Trim()) }
  return @($messages)
}

function Invoke-WrittenResultValidation {
  $catalogPath = Join-Path $testRoot "catalog.yaml"
  $toolRoot = Split-Path $PSScriptRoot -Parent
  $validator = Join-Path $toolRoot ".cursor\skills\project-test\scripts\validate-test-artifacts.py"
  $py = Get-PythonCommand
  $argList = @(
    $validator,
    $catalogPath,
    "--slug", $Slug,
    "--test-root", $testRoot,
    "--last-run", $outFile
  )
  if (-not [string]::IsNullOrWhiteSpace($CodeRoot)) {
    $argList += @("--code-root", $CodeRoot)
  }
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & $py @argList 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previous
  }
  if ($code -eq 0) { return @() }
  $messages = New-Object System.Collections.Generic.List[string]
  $messages.Add("last-run: post-write schema/validator self-check failed")
  foreach ($line in @($output)) {
    $text = [string]$line
    if ($text -match 'ERROR') { $messages.Add($text.Trim()) }
  }
  if ($messages.Count -eq 1) { $messages.Add((@($output) -join " ").Trim()) }
  return @($messages)
}

function Get-RegressionState {
  if (Test-Path $stateFile) {
    $state = Read-ProjectStateFile $stateFile
    $lastCodeChangeValue = if ($state.timestamps) {
      $state.timestamps.last_code_change_at
    } else {
      $state.last_code_change_at
    }
    return [pscustomobject]@{
      Source = "state.json"
      State = $state
      LastCodeChange = Convert-ToUtcDate $lastCodeChangeValue "last_code_change_at"
    }
  }
  if (-not (Test-Path $sopFile)) {
    return [pscustomobject]@{ Source = "none"; State = $null; LastCodeChange = $null }
  }
  $sop = Get-Content -Raw -Path $sopFile
  $match = [regex]::Match(
    $sop,
    "(?im)^\|\s*last_code_change_at\s*\|\s*([^|]*?)\s*\|\s*$"
  )
  $value = if ($match.Success) { $match.Groups[1].Value.Trim() } else { $null }
  return [pscustomobject]@{
    Source = "SOP.md"
    State = $null
    LastCodeChange = Convert-ToUtcDate $value "last_code_change_at"
  }
}

function Invoke-LoggedCommand {
  param([string]$Command, [string]$WorkingDirectory, [string]$LogPath)
  Push-Location $WorkingDirectory
  try {
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
      & cmd.exe /d /s /c $Command *> $LogPath
    } else {
      & /bin/sh -lc $Command *> $LogPath
    }
    return $LASTEXITCODE
  } finally {
    Pop-Location
  }
}

function Start-LoggedCommand {
  param([string]$Command, [string]$WorkingDirectory, [string]$Stdout, [string]$Stderr)
  if ($IsWindows -or $env:OS -eq "Windows_NT") {
    return Start-Process -FilePath "cmd.exe" -ArgumentList @("/d", "/s", "/c", $Command) `
      -WorkingDirectory $WorkingDirectory -RedirectStandardOutput $Stdout `
      -RedirectStandardError $Stderr -PassThru
  }
  return Start-Process -FilePath "/bin/sh" -ArgumentList @("-lc", $Command) `
    -WorkingDirectory $WorkingDirectory -RedirectStandardOutput $Stdout `
    -RedirectStandardError $Stderr -PassThru
}

function Wait-Health {
  param([string]$Url, [int]$TimeoutSeconds, [Diagnostics.Process]$Process)
  if ([string]::IsNullOrWhiteSpace($Url)) { return $true }
  $deadline = [DateTime]::UtcNow.AddSeconds([Math]::Max(1, $TimeoutSeconds))
  while ([DateTime]::UtcNow -lt $deadline) {
    if ($Process -and $Process.HasExited) { return $false }
    try {
      $response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec 5 -UseBasicParsing
      if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) { return $true }
    } catch {
      Start-Sleep -Milliseconds 500
    }
  }
  return $false
}

function Convert-StructuredCounts {
  param($Report)
  if ($null -eq $Report) { return $null }
  if ($Report.stats) {
    $skipped = [int]$Report.stats.skipped
    if ($null -ne $Report.stats.flaky) { $skipped += [int]$Report.stats.flaky }
    return @{
      passed = [int]$Report.stats.expected
      failed = [int]$Report.stats.unexpected
      skipped = $skipped
    }
  }
  if ($Report.summary) {
    return @{
      passed = [int]$Report.summary.passed
      failed = [int]$Report.summary.failed
      skipped = [int]$Report.summary.skipped
    }
  }
  if ($null -ne $Report.passed -or $null -ne $Report.failed) {
    return @{
      passed = [int]$Report.passed
      failed = [int]$Report.failed
      skipped = [int]$Report.skipped
    }
  }
  return $null
}

function Get-CodeCounts {
  param([string]$LogPath, [string]$ReportPath)
  if (-not [string]::IsNullOrWhiteSpace($ReportPath) -and (Test-Path -LiteralPath $ReportPath)) {
    try {
      $parsed = Convert-StructuredCounts (Get-Content -Raw -Path $ReportPath | ConvertFrom-Json)
      if ($null -ne $parsed) { return $parsed }
    } catch {
      # Fall through to log parsing.
    }
  }
  $counts = @{ passed = 0; failed = 0; skipped = 0 }
  if (-not (Test-Path $LogPath)) { return $counts }
  $text = Get-Content -Raw -Path $LogPath -ErrorAction SilentlyContinue
  if ([string]::IsNullOrWhiteSpace($text)) { return $counts }
  foreach ($name in @("passed", "failed", "skipped")) {
    $matches = [regex]::Matches($text, "(?im)(\d+)\s+$name\b")
    if ($matches.Count -gt 0) {
      $counts[$name] = [int]$matches[$matches.Count - 1].Groups[1].Value
    }
  }
  return $counts
}

function Get-ProductCounts {
  param([string]$ReportPath)
  if (-not (Test-Path $ReportPath)) { return $null }
  try {
    return Convert-StructuredCounts (Get-Content -Raw -Path $ReportPath | ConvertFrom-Json)
  } catch {
    return $null
  }
}

function Get-ExecutedCount {
  param($Counts)
  if ($null -eq $Counts) { return 0 }
  return ([int]$Counts.passed + [int]$Counts.failed + [int]$Counts.skipped)
}

function Write-CodeReport {
  param([string]$Path, $Counts, [string]$Source)
  $payload = [ordered]@{
    passed = [int]$Counts.passed
    failed = [int]$Counts.failed
    skipped = [int]$Counts.skipped
    source = $Source
  }
  $payload | ConvertTo-Json | Set-Content -Path $Path -Encoding utf8
}

function Update-RegressionState {
  param(
    [string]$Timestamp,
    [object]$CurrentState,
    [ValidateSet("passed", "failed", "partial")]
    [string]$RegressionState,
    [string]$RunMode,
    [switch]$StampLastRegressionAt
  )
  if (Test-Path $stateFile) {
    $state = if ($CurrentState) { $CurrentState } else { [pscustomobject]@{} }
    $state = Ensure-StateTimestamps $state
    $state.timestamps | Add-Member -NotePropertyName updated_at -NotePropertyValue $Timestamp -Force
    if ($StampLastRegressionAt) {
      $state.timestamps | Add-Member -NotePropertyName last_regression_at -NotePropertyValue $Timestamp -Force
    }
    $state | Add-Member -NotePropertyName regression -NotePropertyValue ([ordered]@{
      state = $RegressionState
      mode = $RunMode
      last_run = "test/last-run.json"
      updated_at = $Timestamp
    }) -Force
    [void](Write-CanonicalState -Path $stateFile -Slug $Slug -State $state -RepoRoot $SopRoot)
    return
  }
  if ($StampLastRegressionAt -and (Test-Path $sopFile)) {
    [void](Update-SopTimestampRow -SopPath $sopFile -Field "last_regression_at" -Timestamp $Timestamp)
  }
}

$startedAt = [DateTimeOffset]::UtcNow
$started = $startedAt.ToString("o")
$initialState = Get-RegressionState
$failures = @()
$failures += Invoke-CatalogPreflight
$warnings = @()
$logs = Join-Path $testRoot "logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$codeLog = Join-Path $logs "code.txt"
$codeReport = Join-Path $logs "code-report.json"
$productLog = Join-Path $logs "product.txt"
$productReport = Join-Path $logs "product-report.json"
$startLog = Join-Path $logs "app-start.txt"
$startErrorLog = Join-Path $logs "app-start-error.txt"
$stopLog = Join-Path $logs "app-stop.txt"
$code = [ordered]@{ command = $null; exit_code = $null; passed = 0; failed = 0; skipped = 0; status = "skipped"; log = $codeLog; report = $codeReport }
$product = [ordered]@{ command = $null; exit_code = $null; passed = 0; failed = 0; skipped = 0; status = "skipped"; log = $productLog; report = $productReport }
$lifecycle = [ordered]@{
  start_command = $StartCmd
  stop_command = $StopCmd
  health_url = $HealthUrl
  startup_timeout_seconds = [int]$StartupTimeoutSeconds
  started = $false
  healthy = $null
  stop_exit_code = $null
}

if (-not $SkipCode) {
  if ([string]::IsNullOrWhiteSpace($CodeTestCmd)) {
    $failures += "code: CodeTestCmd empty in runtime.ps1"
    $code.exit_code = 2
    $code.status = "failed"
  } else {
    $code.command = $CodeTestCmd
    $resolvedCodeReport = if (-not [string]::IsNullOrWhiteSpace($CodeReportPath)) { $CodeReportPath } else { $null }
    $code.exit_code = Invoke-LoggedCommand $CodeTestCmd $(if ($CodeRoot) { $CodeRoot } else { $testRoot }) $codeLog
    $countSource = "log-parse"
    $counts = Get-CodeCounts $codeLog $resolvedCodeReport
    if (-not [string]::IsNullOrWhiteSpace($resolvedCodeReport) -and (Test-Path -LiteralPath $resolvedCodeReport)) {
      $countSource = "structured-report"
    }
    $code.passed = [int]$counts.passed
    $code.failed = [int]$counts.failed
    $code.skipped = [int]$counts.skipped
    Write-CodeReport $codeReport $counts $countSource
    if ($code.exit_code -ne 0) {
      $code.status = "failed"
      $failures += "code: exit $($code.exit_code)"
    } elseif ((Get-ExecutedCount $counts) -eq 0) {
      $code.status = "failed"
      $code.exit_code = 2
      $failures += "code: zero tests executed"
    } else {
      $code.status = "passed"
    }
  }
}

$appProcess = $null
try {
  if (-not $SkipProduct) {
    if ([string]::IsNullOrWhiteSpace($AccessUrl)) {
      $failures += "product: AccessUrl empty (need CODE handoff)"
      $product.exit_code = 2
      $product.status = "failed"
    } elseif (-not (Test-Path (Join-Path $ProductDir "tests"))) {
      $failures += "product: no Playwright tests under $ProductDir\tests"
      $product.exit_code = 2
      $product.status = "failed"
    } else {
      if (Test-Path -LiteralPath (Join-Path $ProductDir "package.json")) {
        & $installDeps -ProductDir $ProductDir
        if ($LASTEXITCODE -ne 0) {
          $failures += "product: dependency preflight failed for $ProductDir"
          $product.exit_code = 2
          $product.status = "failed"
        }
      }
      if ($product.status -ne "failed") {
        if (-not [string]::IsNullOrWhiteSpace($StartCmd)) {
          $appProcess = Start-LoggedCommand $StartCmd $(if ($CodeRoot) { $CodeRoot } else { $testRoot }) $startLog $startErrorLog
          $lifecycle.started = $true
        }
        if ($SkipHealthCheck) {
          $lifecycle.healthy = $true
        } else {
          $lifecycle.healthy = Wait-Health $HealthUrl ([int]$StartupTimeoutSeconds) $appProcess
        }
        if (-not $lifecycle.healthy) {
          $failures += "product: app health check timed out at $HealthUrl"
          $product.exit_code = 2
          $product.status = "failed"
        } else {
          $product.command = $ProductTestCmd
          $oldAccessUrl = $env:ACCESS_URL
          $oldJsonOutput = $env:PLAYWRIGHT_JSON_OUTPUT_NAME
          try {
            $env:ACCESS_URL = $AccessUrl
            $env:PLAYWRIGHT_JSON_OUTPUT_NAME = $productReport
            $product.exit_code = Invoke-LoggedCommand $product.command $ProductDir $productLog
          } finally {
            $env:ACCESS_URL = $oldAccessUrl
            $env:PLAYWRIGHT_JSON_OUTPUT_NAME = $oldJsonOutput
          }
          $counts = Get-ProductCounts $productReport
          if ($null -eq $counts) {
            $product.status = "failed"
            if ($product.exit_code -eq 0) { $product.exit_code = 2 }
            $failures += "product: missing or invalid structured JSON report"
          } else {
            $product.passed = [int]$counts.passed
            $product.failed = [int]$counts.failed
            $product.skipped = [int]$counts.skipped
            if ($product.exit_code -ne 0) {
              $product.status = "failed"
              $failures += "product: exit $($product.exit_code)"
            } elseif ((Get-ExecutedCount $counts) -eq 0) {
              $product.status = "failed"
              $product.exit_code = 2
              $failures += "product: zero tests executed"
            } else {
              $product.status = "passed"
            }
          }
        }
      }
    }
  }
} finally {
  if (-not [string]::IsNullOrWhiteSpace($StopCmd)) {
    $lifecycle.stop_exit_code = Invoke-LoggedCommand $StopCmd $(if ($CodeRoot) { $CodeRoot } else { $testRoot }) $stopLog
    if ($lifecycle.stop_exit_code -ne 0) { $failures += "lifecycle: StopCmd exit $($lifecycle.stop_exit_code)" }
  }
}

$finishedAt = [DateTimeOffset]::UtcNow
$finalState = Get-RegressionState
if ($finalState.LastCodeChange -and $startedAt -lt $finalState.LastCodeChange) {
  $failures += "stale: code changed at $($finalState.LastCodeChange.ToString("o")) after regression started"
}
if (-not $finalState.LastCodeChange) {
  $failures += "freshness: last_code_change_at unavailable in state.json or SOP.md"
}

$overall = if ($failures.Count -gt 0) { "FAIL" } else { "PASS" }
if ($Mode -ne "full" -and $overall -eq "PASS") {
  $warnings += "mode=$Mode PASS is not full REGRESSION evidence; last_regression_at was not refreshed"
}

$finished = $finishedAt.ToString("o")
$payload = [ordered]@{
  schema_version = 1
  slug = $Slug
  mode = $Mode
  started_at = $started
  finished_at = $finished
  access_url = $AccessUrl
  freshness = [ordered]@{
    source = $finalState.Source
    last_code_change_at = if ($finalState.LastCodeChange) { $finalState.LastCodeChange.ToString("o") } else { $null }
    regression_started_after_code_change = if ($finalState.LastCodeChange) { $startedAt -ge $finalState.LastCodeChange } else { $null }
  }
  commands = @(
    @($code.command, $product.command, $StartCmd, $StopCmd) |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  )
  code = $code
  product = $product
  lifecycle = $lifecycle
  failures = @($failures)
  warnings = @($warnings)
  overall = $overall
  logs = [ordered]@{
    directory = $logs
    code = $codeLog
    product = $productLog
    product_report = $productReport
    app_start = $startLog
    app_start_error = $startErrorLog
    app_stop = $stopLog
  }
}

Write-JsonAtomic -Path $outFile -Value $payload
$postWriteFailures = @(Invoke-WrittenResultValidation)
if ($postWriteFailures.Count -gt 0) {
  $failures += $postWriteFailures
  $overall = "FAIL"
  $payload.failures = @($failures)
  $payload.overall = $overall
  Write-JsonAtomic -Path $outFile -Value $payload
}

$fullPass = ($Mode -eq "full" -and $overall -eq "PASS" -and $code.status -eq "passed" -and $product.status -eq "passed")
$machineRegression = if ($overall -eq "FAIL") {
  "failed"
} elseif ($fullPass) {
  "passed"
} else {
  "partial"
}
Update-RegressionState `
  -Timestamp $finished `
  -CurrentState $finalState.State `
  -RegressionState $machineRegression `
  -RunMode $Mode `
  -StampLastRegressionAt:$fullPass
if ($fullPass) {
  [void](Update-SopTimestampRow -SopPath $sopFile -Field "last_regression_at" -Timestamp $finished)
}
Write-Output "Wrote $outFile overall=$overall mode=$Mode regression.state=$machineRegression"
if ($failures.Count -gt 0) {
  $failures | ForEach-Object { Write-Output " - $_" }
  exit 1
}
exit 0
