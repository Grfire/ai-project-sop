# Register or print a Windows scheduled task that runs SOP unified validation.
# Machine evidence only; never approves human gates.
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$SopRoot,
  [string]$TaskName = "SOP-Unified-Validation",
  [ValidateSet("Hourly", "Daily", "Logon")]
  [string]$Trigger = "Daily",
  [switch]$Unregister,
  [switch]$PrintDefinition
)

$ErrorActionPreference = "Stop"

$root = if (-not [string]::IsNullOrWhiteSpace($SopRoot)) {
  (Resolve-Path -LiteralPath $SopRoot).Path
} else {
  Split-Path $PSScriptRoot -Parent
}

$validation = Join-Path $root "scripts\tests\run-sop-validation.ps1"
if (-not (Test-Path -LiteralPath $validation)) {
  throw "Unified validation script missing: $validation"
}

$shell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path -LiteralPath $shell)) {
  $shell = (Get-Process -Id $PID).Path
}
$action = "`"$shell`" -NoProfile -ExecutionPolicy Bypass -File `"$validation`""

$schedule = switch ($Trigger) {
  "Hourly" { @("/SC", "HOURLY", "/MO", "1") }
  "Logon" { @("/SC", "ONLOGON") }
  default { @("/SC", "DAILY", "/ST", "09:00") }
}

$definition = [ordered]@{
  task_name = $TaskName
  trigger = $Trigger
  action = $action
  validation_script = $validation
  schtasks_create = (@("/Create", "/TN", $TaskName, "/TR", $action, "/F") + $schedule)
  note = "Scheduled validation is evidence only; human gates stay conversational."
}

if ($PrintDefinition) {
  $definition | ConvertTo-Json -Compress
  exit 0
}

$schtasks = Join-Path $env:SystemRoot "System32\schtasks.exe"
if (-not (Test-Path -LiteralPath $schtasks)) {
  throw "schtasks.exe not found; cannot register a Windows scheduled task"
}

if ($Unregister) {
  if ($PSCmdlet.ShouldProcess($TaskName, "Unregister SOP validation task")) {
    & $schtasks /Delete /TN $TaskName /F | Out-Null
  }
  [pscustomobject]@{
    task_name = $TaskName
    unregistered = $true
    note = "Task removed. Human gates unchanged."
  } | ConvertTo-Json -Compress
  exit 0
}

if ($PSCmdlet.ShouldProcess($TaskName, "Register SOP validation task")) {
  $createArgs = @("/Create", "/TN", $TaskName, "/TR", $action, "/F") + $schedule
  $output = & $schtasks @createArgs 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "schtasks create failed: $output"
  }
}

[pscustomobject]@{
  task_name = $TaskName
  trigger = $Trigger
  action = $action
  registered = $true
  human_gate_approved = $false
  note = "Windows task registered. Output is evidence only and does not approve gates."
} | ConvertTo-Json -Compress
exit 0
