# Shared atomic project-state helpers. Dot-source from other scripts.
# These functions never approve human gates.

$script:SopStableGates = @(
  "INTAKE_COMPLETE",
  "REQ_SIGNOFF",
  "UI_SIGNOFF",
  "ARCH_SIGNOFF",
  "TEST_PACK_READY",
  "CODE_READY",
  "REGRESSION_PASS",
  "DOCS_COMPLETE"
)

$script:SopGateMeta = @{
  INTAKE_COMPLETE  = @{ Stage = "INTAKE"; Owner = "项目接管分析师" }
  REQ_SIGNOFF      = @{ Stage = "REQ";    Owner = "需求分析师" }
  UI_SIGNOFF       = @{ Stage = "UI";     Owner = "原型设计师" }
  ARCH_SIGNOFF     = @{ Stage = "ARCH";   Owner = "架构师" }
  TEST_PACK_READY  = @{ Stage = "TEST";   Owner = "测试架构师" }
  CODE_READY       = @{ Stage = "CODE";   Owner = "研发工程师" }
  REGRESSION_PASS  = @{ Stage = "TEST";   Owner = "测试架构师" }
  DOCS_COMPLETE    = @{ Stage = "DOCS";   Owner = "文档专员" }
}

$script:SopResetMatrix = @{
  product        = @("REQ_SIGNOFF", "UI_SIGNOFF", "ARCH_SIGNOFF", "TEST_PACK_READY", "CODE_READY", "REGRESSION_PASS", "DOCS_COMPLETE")
  visual         = @("UI_SIGNOFF", "ARCH_SIGNOFF", "TEST_PACK_READY", "CODE_READY", "REGRESSION_PASS", "DOCS_COMPLETE")
  architecture   = @("ARCH_SIGNOFF", "TEST_PACK_READY", "CODE_READY", "REGRESSION_PASS", "DOCS_COMPLETE")
  test_pack      = @("TEST_PACK_READY", "CODE_READY", "REGRESSION_PASS", "DOCS_COMPLETE")
  runtime_code   = @("CODE_READY", "REGRESSION_PASS", "DOCS_COMPLETE")
  documentation  = @("DOCS_COMPLETE")
}

$script:SopGatePrerequisites = @{
  INTAKE_COMPLETE = @()
  REQ_SIGNOFF = @()
  UI_SIGNOFF = @("REQ_SIGNOFF")
  ARCH_SIGNOFF = @("REQ_SIGNOFF")
  TEST_PACK_READY = @("REQ_SIGNOFF", "ARCH_SIGNOFF")
  CODE_READY = @("REQ_SIGNOFF", "ARCH_SIGNOFF", "TEST_PACK_READY")
  REGRESSION_PASS = @("REQ_SIGNOFF", "ARCH_SIGNOFF", "TEST_PACK_READY", "CODE_READY")
  DOCS_COMPLETE = @("REQ_SIGNOFF", "ARCH_SIGNOFF", "TEST_PACK_READY", "CODE_READY", "REGRESSION_PASS")
}

function Get-GateAndDownstream {
  param([Parameter(Mandatory = $true)][string]$GateId)
  $index = [Array]::IndexOf($script:SopStableGates, $GateId)
  if ($index -lt 0) { throw "Unknown gate '$GateId'" }
  return @($script:SopStableGates[$index..($script:SopStableGates.Count - 1)])
}

function Assert-GatePrerequisites {
  param(
    [Parameter(Mandatory = $true)]$State,
    [Parameter(Mandatory = $true)][string]$GateId
  )
  foreach ($requiredGate in @($script:SopGatePrerequisites[$GateId])) {
    [void](Assert-GateApprovedCache -State $State -GateId $requiredGate)
  }
}

function Get-GateTimestampField {
  param([Parameter(Mandatory = $true)][string]$GateId)
  switch ($GateId) {
    "INTAKE_COMPLETE" { return "intake_completed_at" }
    "TEST_PACK_READY" { return "test_pack_at" }
    "DOCS_COMPLETE" { return "docs_completed_at" }
    default { return $null }
  }
}

function Convert-ToUtcDate {
  param([object]$Value, [string]$Field)
  if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
  $parsed = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParse(
      [string]$Value,
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::AssumeUniversal,
      [ref]$parsed)) {
    throw "Invalid $Field timestamp: $Value"
  }
  return $parsed.ToUniversalTime()
}

function Assert-FreshFullRegressionEvidence {
  param(
    [Parameter(Mandatory = $true)]$State,
    [Parameter(Mandatory = $true)][string]$Slug,
    [Parameter(Mandatory = $true)][string]$LastRunPath,
    [string]$GateId = "REGRESSION_PASS"
  )
  if (-not (Test-Path -LiteralPath $LastRunPath)) {
    throw "$GateId requires test/last-run.json"
  }
  try {
    $lastRun = Read-ProjectStateFile $LastRunPath
  } catch {
    throw "$GateId requires valid JSON in test/last-run.json"
  }
  if ($null -eq $lastRun) {
    throw "$GateId requires valid JSON in test/last-run.json"
  }
  if ((Get-JsonProperty $lastRun "slug") -ne $Slug -or
      (Get-JsonProperty $lastRun "mode") -ne "full" -or
      (Get-JsonProperty $lastRun "overall") -ne "PASS") {
    throw "$GateId requires matching slug, mode=full, and overall=PASS in test/last-run.json"
  }
  $freshness = Get-JsonProperty $lastRun "freshness"
  if ((Get-JsonProperty $freshness "regression_started_after_code_change") -ne $true) {
    throw "$GateId requires freshness.regression_started_after_code_change=true"
  }
  $finishedAt = Convert-ToUtcDate (Get-JsonProperty $lastRun "finished_at") "last-run.finished_at"
  $lastCodeAt = Convert-ToUtcDate `
    (Get-JsonProperty (Get-JsonProperty $State "timestamps") "last_code_change_at") `
    "state.timestamps.last_code_change_at"
  $evidenceCodeAt = Convert-ToUtcDate `
    (Get-JsonProperty $freshness "last_code_change_at") `
    "last-run.freshness.last_code_change_at"
  if (-not $finishedAt -or -not $lastCodeAt -or -not $evidenceCodeAt -or
      $evidenceCodeAt -ne $lastCodeAt -or $finishedAt -lt $lastCodeAt) {
    throw "$GateId freshness timestamps must match state and finish after the last code change"
  }
  return $lastRun
}

function ConvertTo-CanonicalJsonString {
  param([string]$Value)
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append('"')
  foreach ($ch in $Value.ToCharArray()) {
    $code = [int]$ch
    switch ($ch) {
      '"' { [void]$sb.Append('\"') }
      '\' { [void]$sb.Append('\\') }
      "`b" { [void]$sb.Append('\b') }
      "`f" { [void]$sb.Append('\f') }
      "`n" { [void]$sb.Append('\n') }
      "`r" { [void]$sb.Append('\r') }
      "`t" { [void]$sb.Append('\t') }
      default {
        if ($code -lt 0x20 -or $code -gt 0x7e) {
          [void]$sb.Append(('\u{0:x4}' -f $code))
        } else {
          [void]$sb.Append($ch)
        }
      }
    }
  }
  [void]$sb.Append('"')
  return $sb.ToString()
}

function ConvertTo-CanonicalJson {
  param($Value, [int]$Depth = 24)
  if ($Depth -lt 0) { throw "JSON depth exceeded" }
  if ($null -eq $Value) { return "null" }

  if ($Value -is [bool]) {
    if ($Value) { return "true" } else { return "false" }
  }
  if ($Value -is [byte] -or $Value -is [int16] -or $Value -is [uint16] -or
      $Value -is [int] -or $Value -is [uint32] -or $Value -is [long] -or
      $Value -is [uint64] -or $Value -is [decimal] -or $Value -is [double] -or
      $Value -is [float] -or $Value -is [int64]) {
    return $Value.ToString([cultureinfo]::InvariantCulture)
  }
  if ($Value -is [datetimeoffset]) {
    return ConvertTo-CanonicalJson $Value.ToUniversalTime().ToString("o") ($Depth - 1)
  }
  if ($Value -is [datetime]) {
    return ConvertTo-CanonicalJson ([DateTimeOffset]$Value).ToUniversalTime().ToString("o") ($Depth - 1)
  }
  if ($Value -is [string] -or $Value -is [char] -or $Value -is [guid]) {
    return ConvertTo-CanonicalJsonString ([string]$Value)
  }
  if ($Value -is [System.Collections.IDictionary]) {
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($key in @($Value.Keys)) {
      $name = [string]$key | ConvertTo-Json -Compress
      $parts.Add("$name`:$(ConvertTo-CanonicalJson $Value[$key] ($Depth - 1))")
    }
    return "{$($parts -join ',')}"
  }
  if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($item in @($Value)) {
      $items.Add((ConvertTo-CanonicalJson $item ($Depth - 1)))
    }
    return "[$($items -join ',')]"
  }
  $parts = New-Object System.Collections.Generic.List[string]
  foreach ($prop in $Value.PSObject.Properties) {
    if ($null -eq $prop.Name -or $prop.MemberType -eq "ScriptProperty") { continue }
    $name = [string]$prop.Name | ConvertTo-Json -Compress
    $parts.Add("$name`:$(ConvertTo-CanonicalJson $prop.Value ($Depth - 1))")
  }
  return "{$($parts -join ',')}"
}

function Write-JsonAtomic {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)]$Value
  )
  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent)) {
    throw "Parent directory missing for $Path"
  }
  $temp = Join-Path $parent (".{0}.{1}.tmp" -f [IO.Path]::GetFileName($Path), [Guid]::NewGuid().ToString("N"))
  $backup = "$temp.bak"
  try {
    [IO.File]::WriteAllText(
      $temp,
      (ConvertTo-CanonicalJson $Value),
      [Text.UTF8Encoding]::new($false)
    )
    if (Test-Path -LiteralPath $Path) {
      [IO.File]::Replace($temp, $Path, $backup)
    } else {
      [IO.File]::Move($temp, $Path)
    }
  } finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
    if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
  }
}

function Get-JsonProperty {
  param($Object, [string]$Name, $Default = $null)
  if ($null -eq $Object) { return $Default }
  if ($Object -is [System.Collections.IDictionary]) {
    foreach ($key in @($Object.Keys)) {
      if ([string]$key -eq $Name) { return $Object[$key] }
    }
    return $Default
  }
  $prop = $Object.PSObject.Properties[$Name]
  if ($null -eq $prop) { return $Default }
  return $prop.Value
}

function ConvertTo-NullIfEmpty {
  param($Value)
  if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
  return $Value
}

function Update-SopFieldRow {
  param(
    [Parameter(Mandatory = $true)][string]$SopPath,
    [Parameter(Mandatory = $true)][string]$Field,
    [AllowEmptyString()]
    [Parameter(Mandatory = $true)][string]$Value
  )
  if (-not (Test-Path -LiteralPath $SopPath)) { return $false }
  $lines = [IO.File]::ReadAllLines($SopPath)
  $pattern = "^\|[ \t]*$([regex]::Escape($Field))[ \t]*\|"
  $updated = $false
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if (-not $updated -and [regex]::IsMatch($lines[$i], $pattern)) {
      $lines[$i] = "| $Field | $Value |"
      $updated = $true
    }
  }
  if (-not $updated) { return $false }
  $utf8 = [Text.UTF8Encoding]::new($false)
  $temp = "$SopPath.$([Guid]::NewGuid().ToString("N")).tmp"
  try {
    [IO.File]::WriteAllLines($temp, $lines, $utf8)
    [IO.File]::Copy($temp, $SopPath, $true)
  } finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
  }
  return $true
}

function Update-SopTimestampRow {
  param(
    [Parameter(Mandatory = $true)][string]$SopPath,
    [Parameter(Mandatory = $true)][string]$Field,
    [AllowEmptyString()]
    [Parameter(Mandatory = $true)][string]$Timestamp
  )
  return Update-SopFieldRow -SopPath $SopPath -Field $Field -Value $Timestamp
}

function Update-SopStageRow {
  param(
    [Parameter(Mandatory = $true)][string]$SopPath,
    [Parameter(Mandatory = $true)][string]$Stage,
    [Parameter(Mandatory = $true)][string]$Status,
    [string]$Note = ""
  )
  if (-not (Test-Path -LiteralPath $SopPath)) { return $false }
  $lines = [IO.File]::ReadAllLines($SopPath)
  $pattern = "^\|[ \t]*$([regex]::Escape($Stage))[ \t]*\|"
  $updated = $false
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if (-not $updated -and [regex]::IsMatch($lines[$i], $pattern)) {
      $lines[$i] = "| $Stage | $Status | $Note |"
      $updated = $true
    }
  }
  if (-not $updated) { return $false }
  $utf8 = [Text.UTF8Encoding]::new($false)
  $temp = "$SopPath.$([Guid]::NewGuid().ToString("N")).tmp"
  try {
    [IO.File]::WriteAllLines($temp, $lines, $utf8)
    [IO.File]::Copy($temp, $SopPath, $true)
  } finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
  }
  return $true
}

function Add-MarkdownRecord {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Text
  )
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Markdown record file missing: $Path"
  }
  $existing = [IO.File]::ReadAllText($Path)
  if (-not $existing.EndsWith("`n")) { $existing += "`r`n" }
  $utf8 = [Text.UTF8Encoding]::new($false)
  $temp = "$Path.$([Guid]::NewGuid().ToString("N")).tmp"
  try {
    [IO.File]::WriteAllText($temp, ($existing.TrimEnd() + "`r`n`r`n" + $Text.Trim() + "`r`n"), $utf8)
    [IO.File]::Copy($temp, $Path, $true)
  } finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
  }
}

function Add-SopLogRow {
  param(
    [Parameter(Mandatory = $true)][string]$SopPath,
    [Parameter(Mandatory = $true)][string]$When,
    [Parameter(Mandatory = $true)][string]$Stage,
    [Parameter(Mandatory = $true)][string]$Role,
    [Parameter(Mandatory = $true)][string]$Event,
    [string]$Reference = ""
  )
  if (-not (Test-Path -LiteralPath $SopPath)) { return $false }
  $row = "| $When | $Stage | $Role | $Event | $Reference |"
  $sop = [IO.File]::ReadAllText($SopPath).TrimEnd() + "`r`n" + $row + "`r`n"
  $utf8 = [Text.UTF8Encoding]::new($false)
  $temp = "$SopPath.$([Guid]::NewGuid().ToString("N")).tmp"
  try {
    [IO.File]::WriteAllText($temp, $sop, $utf8)
    [IO.File]::Copy($temp, $SopPath, $true)
  } finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
  }
  return $true
}

function Read-ProjectStateFile {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return (Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json)
}

function Ensure-StateTimestamps {
  param([Parameter(Mandatory = $true)]$State)
  if (-not (Get-JsonProperty $State "timestamps")) {
    $State | Add-Member -NotePropertyName timestamps -NotePropertyValue ([pscustomobject]@{}) -Force
  }
  return $State
}

function Get-PythonCommand {
  foreach ($name in @("python", "py", "python3")) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
  }
  throw "Python is required for JSON Schema validation"
}

function Invoke-JsonSchemaValidation {
  param(
    [Parameter(Mandatory = $true)][string]$SchemaPath,
    [Parameter(Mandatory = $true)][string]$InstancePath,
    [string]$RepoRoot
  )
  $root = Resolve-RepoRootFromLib $RepoRoot
  $validator = Join-Path $root "scripts\validate-json-schema.py"
  if (-not (Test-Path -LiteralPath $validator)) {
    throw "Missing schema validator: $validator"
  }
  $py = Get-PythonCommand
  $output = & $py $validator $SchemaPath $InstancePath 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Schema validation failed for $InstancePath : $output"
  }
  return $output
}

function ConvertTo-CanonicalState {
  param(
    [Parameter(Mandatory = $true)][string]$Slug,
    $State
  )
  $pathsIn = Get-JsonProperty $State "paths"
  $tsIn = Get-JsonProperty $State "timestamps"
  $statusIn = Get-JsonProperty $State "stage_status"
  $govIn = Get-JsonProperty $State "governance"
  $refsIn = Get-JsonProperty $State "approval_refs"
  $blockedIn = Get-JsonProperty $State "blocked"
  $regressionIn = Get-JsonProperty $State "regression"

  $mode = Get-JsonProperty $State "mode"
  if ([string]::IsNullOrWhiteSpace([string]$mode)) { $mode = $null }

  $uiMode = Get-JsonProperty $State "ui_input_mode"
  if ([string]::IsNullOrWhiteSpace([string]$uiMode)) { $uiMode = $null }

  $blocked = $null
  if ($null -ne $blockedIn -and [string]$blockedIn -ne "") {
    $blocked = [ordered]@{
      gate_id    = [string](Get-JsonProperty $blockedIn "gate_id")
      owner_role = [string](Get-JsonProperty $blockedIn "owner_role")
      reason     = [string](Get-JsonProperty $blockedIn "reason")
      since      = [string](Get-JsonProperty $blockedIn "since")
    }
  }

  $approvalRefs = [ordered]@{}
  if ($null -ne $refsIn) {
    foreach ($gate in $script:SopStableGates) {
      $value = Get-JsonProperty $refsIn $gate
      if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
        $approvalRefs[$gate] = [string]$value
      }
    }
  }

  $waiverIds = New-Object System.Collections.Generic.List[string]
  $rawWaivers = Get-JsonProperty $govIn "active_waiver_ids"
  if ($null -ne $rawWaivers) {
    foreach ($item in @($rawWaivers)) {
      if (-not [string]::IsNullOrWhiteSpace([string]$item)) { $waiverIds.Add([string]$item) }
    }
  }
  $regulated = New-Object System.Collections.Generic.List[string]
  $rawRegulated = Get-JsonProperty $govIn "regulated_data"
  if ($null -ne $rawRegulated) {
    foreach ($item in @($rawRegulated)) {
      if (-not [string]::IsNullOrWhiteSpace([string]$item)) { $regulated.Add([string]$item) }
    }
  }

  $canonical = [ordered]@{
    schema_version = 1
    slug           = $Slug
    lifecycle      = $(if (Get-JsonProperty $State "lifecycle") { [string](Get-JsonProperty $State "lifecycle") } else { "active" })
    origin         = $(if (Get-JsonProperty $State "origin") { [string](Get-JsonProperty $State "origin") } else { "new" })
    current_stage  = $(if (Get-JsonProperty $State "current_stage") { [string](Get-JsonProperty $State "current_stage") } else { "REQ" })
    mode           = $mode
    stage_status   = [ordered]@{
      INTAKE = $(if (Get-JsonProperty $statusIn "INTAKE") { [string](Get-JsonProperty $statusIn "INTAKE") } else { "na" })
      REQ    = $(if (Get-JsonProperty $statusIn "REQ") { [string](Get-JsonProperty $statusIn "REQ") } else { "not_started" })
      PPT    = $(if (Get-JsonProperty $statusIn "PPT") { [string](Get-JsonProperty $statusIn "PPT") } else { "na" })
      UI     = $(if (Get-JsonProperty $statusIn "UI") { [string](Get-JsonProperty $statusIn "UI") } else { "not_started" })
      ARCH   = $(if (Get-JsonProperty $statusIn "ARCH") { [string](Get-JsonProperty $statusIn "ARCH") } else { "not_started" })
      TEST   = $(if (Get-JsonProperty $statusIn "TEST") { [string](Get-JsonProperty $statusIn "TEST") } else { "not_started" })
      CODE   = $(if (Get-JsonProperty $statusIn "CODE") { [string](Get-JsonProperty $statusIn "CODE") } else { "not_started" })
      DOCS   = $(if (Get-JsonProperty $statusIn "DOCS") { [string](Get-JsonProperty $statusIn "DOCS") } else { "not_started" })
    }
    ui_input_mode  = $uiMode
    blocked        = $blocked
    paths          = [ordered]@{
      intake   = $(if (Get-JsonProperty $pathsIn "intake") { [string](Get-JsonProperty $pathsIn "intake") } else { "project://intake" })
      req      = $(if (Get-JsonProperty $pathsIn "req") { [string](Get-JsonProperty $pathsIn "req") } else { "bundle://workspaces/req/projects/$Slug" })
      ppt_path = ConvertTo-NullIfEmpty (Get-JsonProperty $pathsIn "ppt_path")
      ui       = $(if (Get-JsonProperty $pathsIn "ui") { [string](Get-JsonProperty $pathsIn "ui") } else { "bundle://workspaces/ui/projects/$Slug" })
      arch     = $(if (Get-JsonProperty $pathsIn "arch") { [string](Get-JsonProperty $pathsIn "arch") } else { "bundle://workspaces/arch/projects/$Slug" })
      code     = $(if (Get-JsonProperty $pathsIn "code") { [string](Get-JsonProperty $pathsIn "code") } else { "bundle://workspaces/code/project/$Slug" })
      test     = $(if (Get-JsonProperty $pathsIn "test") { [string](Get-JsonProperty $pathsIn "test") } else { "project://test" })
      docs     = $(if (Get-JsonProperty $pathsIn "docs") { [string](Get-JsonProperty $pathsIn "docs") } else { "project://docs" })
    }
    timestamps     = [ordered]@{
      updated_at            = ConvertTo-NullIfEmpty (Get-JsonProperty $tsIn "updated_at")
      last_code_change_at   = ConvertTo-NullIfEmpty (Get-JsonProperty $tsIn "last_code_change_at")
      last_regression_at    = ConvertTo-NullIfEmpty (Get-JsonProperty $tsIn "last_regression_at")
      intake_completed_at   = ConvertTo-NullIfEmpty (Get-JsonProperty $tsIn "intake_completed_at")
      test_pack_at          = ConvertTo-NullIfEmpty (Get-JsonProperty $tsIn "test_pack_at")
      docs_completed_at     = ConvertTo-NullIfEmpty (Get-JsonProperty $tsIn "docs_completed_at")
      lifecycle_changed_at  = ConvertTo-NullIfEmpty (Get-JsonProperty $tsIn "lifecycle_changed_at")
    }
    approval_refs  = $approvalRefs
    governance     = [ordered]@{
      data_classification   = ConvertTo-NullIfEmpty (Get-JsonProperty $govIn "data_classification")
      regulated_data        = @($regulated)
      residency             = ConvertTo-NullIfEmpty (Get-JsonProperty $govIn "residency")
      retention             = ConvertTo-NullIfEmpty (Get-JsonProperty $govIn "retention")
      access_audit          = ConvertTo-NullIfEmpty (Get-JsonProperty $govIn "access_audit")
      third_party_transfer  = ConvertTo-NullIfEmpty (Get-JsonProperty $govIn "third_party_transfer")
      compliance_owner      = ConvertTo-NullIfEmpty (Get-JsonProperty $govIn "compliance_owner")
      active_waiver_ids     = @($waiverIds)
    }
    _authority_note = $(
      $note = Get-JsonProperty $State "_authority_note"
      if ([string]::IsNullOrWhiteSpace([string]$note)) {
        "Machine state only. Human gates require conversational confirmation recorded in APPROVALS.md."
      } else {
        [string]$note
      }
    )
  }

  if ($null -ne $regressionIn) {
    $regState = ConvertTo-NullIfEmpty (Get-JsonProperty $regressionIn "state")
    $regMode = ConvertTo-NullIfEmpty (Get-JsonProperty $regressionIn "mode")
    $regUpdated = ConvertTo-NullIfEmpty (Get-JsonProperty $regressionIn "updated_at")
    if ($regState -and $regMode -and $regUpdated) {
      $canonical["regression"] = [ordered]@{
        state      = [string]$regState
        mode       = [string]$regMode
        last_run   = $(if (Get-JsonProperty $regressionIn "last_run") { [string](Get-JsonProperty $regressionIn "last_run") } else { "test/last-run.json" })
        updated_at = [string]$regUpdated
      }
    }
  }

  return $canonical
}

function Write-CanonicalState {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Slug,
    $State,
    [string]$RepoRoot,
    [switch]$SkipSchema
  )
  $canonical = ConvertTo-CanonicalState -Slug $Slug -State $State
  Write-JsonAtomic -Path $Path -Value $canonical
  if (-not $SkipSchema) {
    $root = Resolve-RepoRootFromLib $RepoRoot
    $schema = Join-Path $root "schemas\state.schema.json"
    Invoke-JsonSchemaValidation -SchemaPath $schema -InstancePath $Path -RepoRoot $root | Out-Null
  }
  return $canonical
}

function Get-ProjectLifecycle {
  param($State)
  $value = Get-JsonProperty $State "lifecycle"
  if ([string]::IsNullOrWhiteSpace([string]$value)) { return "active" }
  return [string]$value
}

function Assert-ProjectWritable {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [ValidateSet("delivery", "lifecycle", "cancellation")]
    [string]$Intent = "delivery"
  )
  $resolvedProjectRoot = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
  )
  $directorySlug = Split-Path -Leaf $resolvedProjectRoot
  $statePath = Join-Path $ProjectRoot "state.json"
  if (-not (Test-Path -LiteralPath $statePath)) { return }
  $state = Read-ProjectStateFile $statePath
  $stateSlug = [string](Get-JsonProperty $state "slug")
  if ([string]::IsNullOrWhiteSpace($stateSlug)) {
    throw "Project identity mismatch: state.slug is missing for directory '$directorySlug'."
  }
  if ($stateSlug -ne $directorySlug) {
    throw "Project identity mismatch: directory slug '$directorySlug' differs from state.slug '$stateSlug'."
  }

  $projectsRoot = Split-Path -Parent $resolvedProjectRoot
  $currentPath = Join-Path $projectsRoot "CURRENT.md"
  if (Test-Path -LiteralPath $currentPath) {
    $currentText = [IO.File]::ReadAllText($currentPath)
    $currentMatch = [regex]::Match($currentText, '(?im)^\s*slug\s*:\s*([a-z0-9][a-z0-9-]*)\s*$')
    if ($currentMatch.Success) {
      $currentSlug = $currentMatch.Groups[1].Value
      if ($currentSlug -notin @("unset", "none") -and $currentSlug -ne $directorySlug) {
        throw "Project identity mismatch: directory/state slug '$directorySlug' differs from CURRENT '$currentSlug'."
      }
    }
  }

  $lifecycle = Get-ProjectLifecycle $state
  switch ($lifecycle) {
    "active" { return }
    "paused" {
      if ($Intent -eq "delivery") {
        throw "Project is paused; delivery writes are blocked until set-lifecycle -Lifecycle active after conversational confirmation."
      }
      return
    }
    "cancelled" {
      if ($Intent -ne "cancellation") {
        throw "Project is cancelled; no writes except cancellation records."
      }
      return
    }
    "archived" {
      if ($Intent -ne "lifecycle") {
        throw "Project is archived/read-only until conversational reactivation via set-lifecycle."
      }
      return
    }
    default { throw "Unknown lifecycle '$lifecycle'" }
  }
}

function Assert-GateApprovedCache {
  param(
    [Parameter(Mandatory = $true)]$State,
    [Parameter(Mandatory = $true)][string]$GateId
  )
  if ($GateId -notin $script:SopStableGates) { throw "Unknown gate '$GateId'" }
  $stage = $script:SopGateMeta[$GateId].Stage
  $status = Get-JsonProperty (Get-JsonProperty $State "stage_status") $stage
  $approvalRef = Get-JsonProperty (Get-JsonProperty $State "approval_refs") $GateId
  # TEST_PACK_READY and REGRESSION_PASS share stage_status.TEST. A rejection of
  # one must not erase the other gate's still-current ref; the exact ref is the
  # discriminating cache for these two gates.
  $statusInvalid = if ($stage -eq "TEST") {
    $status -in @("not_started", "na")
  } else {
    $status -ne "approved"
  }
  if ($statusInvalid -or [string]::IsNullOrWhiteSpace([string]$approvalRef)) {
    throw "$GateId lacks a current approved cache (stage_status.$stage plus approval_ref)."
  }
  return [string]$approvalRef
}

function Resolve-RepoRootFromLib {
  param([string]$Hint)
  if ($Hint -and (Test-Path -LiteralPath (Join-Path $Hint "schemas\state.schema.json"))) {
    return $Hint
  }
  $fromLib = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
  if (Test-Path -LiteralPath (Join-Path $fromLib "schemas\state.schema.json")) {
    return $fromLib
  }
  $candidate = Split-Path $PSScriptRoot -Parent
  if (Test-Path -LiteralPath (Join-Path $candidate "schemas\state.schema.json")) {
    return $candidate
  }
  return $fromLib
}

function Get-NextRecordId {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Prefix
  )
  $n = 0
  if (Test-Path -LiteralPath $Path) {
    foreach ($match in [regex]::Matches([IO.File]::ReadAllText($Path), "(?m)^###\s+$Prefix-(\d+)")) {
      $value = [int]$match.Groups[1].Value
      if ($value -gt $n) { $n = $value }
    }
  }
  return "{0}-{1:D3}" -f $Prefix, ($n + 1)
}
