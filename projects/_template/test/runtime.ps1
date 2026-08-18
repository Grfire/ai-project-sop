# Runtime for test wrappers — filled by project-test.
# Leave unused optional overrides unset/empty; the runner treats empty AccessUrl
# and CodeTestCmd as unconfigured and fails the corresponding suite.
$CodeRoot = ""
$AccessUrl = ""
$CodeTestCmd = ""
$ProductDir = Join-Path $PSScriptRoot "product"

# Optional app lifecycle for product tests.
$StartCmd = ""
$StopCmd = ""
$HealthUrl = ""
$StartupTimeoutSeconds = 60

# Optional overrides. ProductTestCmd defaults to Playwright JSON reporter.
# SkipHealthCheck is for already-running apps or isolated runner tests only.
$ProductTestCmd = ""
$SkipHealthCheck = $false
$CodeReportPath = ""
