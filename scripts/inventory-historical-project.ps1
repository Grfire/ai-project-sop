param(
  [Parameter(Mandatory = $true)][string]$SourcePath,
  [Parameter(Mandatory = $true)][string]$Slug,
  [string]$SopRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [ValidateRange(1, [int]::MaxValue)][int]$MaxFiles = 100000,
  [ValidateRange(1, [long]::MaxValue)][long]$MaxBytes = 10GB,
  [ValidateRange(1, [long]::MaxValue)][long]$MaxFileBytes = 100MB
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\project-state.ps1")
function Get-SafeRelativePath([string]$BasePath, [string]$TargetPath) {
  $baseFull = [IO.Path]::GetFullPath($BasePath).TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
  $targetFull = [IO.Path]::GetFullPath($TargetPath)
  $baseUri = New-Object System.Uri($baseFull)
  $targetUri = New-Object System.Uri($targetFull)
  return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace("/", "\")
}

$source = (Resolve-Path $SourcePath).Path
$sourceItem = Get-Item -LiteralPath $source -Force
if (-not $sourceItem.PSIsContainer) {
  throw "SourcePath must be a directory: $source"
}
$projectRoot = Join-Path $SopRoot "projects\$Slug"
Assert-ProjectWritable -ProjectRoot $projectRoot -Intent delivery
$intake = Join-Path $projectRoot "intake"
$handoffs = Join-Path $intake "handoffs"
$extracted = Join-Path $intake "extracted"
New-Item -ItemType Directory -Force -Path $intake, $handoffs, $extracted | Out-Null

$excludedDirNames = @(
  ".git", ".svn", ".hg", "node_modules", "vendor", "dist", "build", "out",
  "target", "coverage", ".coverage", ".cache", ".pytest_cache", ".mypy_cache",
  ".ruff_cache", ".next", ".nuxt", ".turbo", ".idea", ".vscode", "__pycache__",
  ".venv", "venv", "env", "obj", "tmp", "temp", "logs"
)

$sensitiveNames = @(
  ".env", ".npmrc", ".pypirc", ".netrc", "_netrc", ".git-credentials",
  "credentials", "credentials.json", "secrets.json", "service-account.json",
  "service_account.json", "serviceaccount.json", "kubeconfig",
  "id_rsa", "id_dsa", "id_ecdsa", "id_ed25519"
)
$sensitivePathRegexes = @(
  '(?i)(^|/)\.env(\..+)?$',
  '(?i)(^|/)(credentials?|secrets?|tokens?|passwords?|auth-store|auth_store)(\.[^/]*)?$',
  '(?i)(^|/)[^/]*(service[-_]?account|gcp[-_]?credentials?)[^/]*\.json$',
  '(?i)(^|/)\.kube/(config|[^/]+\.conf)$|(^|/)(kubeconfig)(\.[^/]*)?$',
  '(?i)(^|/)\.(aws|azure|docker|config/gcloud)/.*(credentials?|tokens?|config\.json|application_default_credentials\.json)$',
  '(?i)(^|/)(auth\.json|login data|keyrings?|keychain|cookies(\.sqlite)?)$',
  '(?i)(^|/)[^/]*(dump|backup|database)[^/]*\.(sql|dump|db|sqlite|sqlite3)$',
  '(?i)(^|/)(id_rsa|id_dsa|id_ecdsa|id_ed25519)(\.pub)?$',
  '(?i)(^|/)[^/]*(private[-_]?key|keystore|truststore)[^/]*$',
  '(?i)\.(pem|p12|pfx|key|jks|keystore)$'
)

$textExtensions = @(
  ".md", ".txt", ".rst", ".adoc", ".csv", ".tsv", ".json", ".jsonc",
  ".yaml", ".yml", ".toml", ".ini", ".cfg", ".conf", ".xml", ".html",
  ".htm", ".css", ".scss", ".less", ".js", ".jsx", ".mjs", ".cjs", ".ts",
  ".tsx", ".vue", ".svelte", ".py", ".pyi", ".java", ".kt", ".kts", ".go",
  ".rs", ".cs", ".php", ".rb", ".swift", ".sql", ".graphql", ".proto",
  ".sh", ".bash", ".zsh", ".ps1", ".cmd", ".bat", ".dockerfile", ".gitignore",
  ".gitattributes", ".editorconfig", ".properties", ".gradle"
)
$binaryReviewExtensions = @(
  ".pdf", ".docx", ".pptx", ".xlsx", ".png", ".jpg", ".jpeg", ".gif",
  ".webp", ".svg", ".drawio", ".vsdx"
)
$extractableBinaryExtensions = @(
  ".pdf", ".docx", ".pptx", ".xlsx", ".drawio", ".vsdx"
)
$conversionRequiredExtensions = @(".ppt")
$indexedBinaryExtensions = @(
  ".exe", ".dll", ".so", ".dylib", ".class", ".jar", ".war", ".pyc",
  ".map", ".lock", ".ico", ".woff", ".woff2", ".ttf", ".otf", ".mp3",
  ".wav", ".mp4", ".mov", ".avi"
)
$generatedFileRegex = '(?i)(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|poetry\.lock|cargo\.lock|composer\.lock)$|(\.min\.(js|css)|\.map|\.pyc)$'

$rows = [System.Collections.Generic.List[object]]::new()
$excludedDirs = [System.Collections.Generic.List[object]]::new()
$stack = [System.Collections.Generic.Stack[string]]::new()
$stack.Push($source)
$inventoryAt = [DateTime]::UtcNow.ToString("o")
$inventoryBytes = [long]0
$truncated = $false
$truncationReason = ""

function Merge-IntakeLedgerRows {
  param(
    [System.Collections.Generic.List[object]]$Scanned,
    [string]$ExistingLedgerPath,
    [string]$SourceRoot,
    [bool]$ScanTruncated
  )
  if (-not (Test-Path -LiteralPath $ExistingLedgerPath)) {
    return $Scanned
  }
  $previous = @{}
  foreach ($old in @(Import-Csv -LiteralPath $ExistingLedgerPath -Encoding utf8)) {
    if ($old.path) { $previous[$old.path] = $old }
  }
  if ($previous.Count -eq 0) { return $Scanned }

  $merged = [System.Collections.Generic.List[object]]::new()
  $scannedPaths = @{}
  foreach ($row in $Scanned) {
    $scannedPaths[$row.path] = $true
    $old = $previous[$row.path]
    if ($null -eq $old) {
      $merged.Add($row)
      continue
    }
    $newSensitive = ($row.status -eq "skipped-sensitive")
    $sameHash = (-not $newSensitive) -and
      -not [string]::IsNullOrWhiteSpace([string]$row.sha256) -and
      -not [string]::IsNullOrWhiteSpace([string]$old.sha256) -and
      ([string]$row.sha256).ToLowerInvariant() -eq ([string]$old.sha256).ToLowerInvariant()
    if ($old.status -eq "removed-at-source") {
      $row.status = "pending"
      $row.evidence_ids = ""
      $row.read_at = ""
      $row.reason = "file reappeared after removal; reread required"
    } elseif ($sameHash) {
      $row.status = $old.status
      $row.evidence_ids = $old.evidence_ids
      $row.read_at = $old.read_at
      if ($old.status -ne "pending" -and -not [string]::IsNullOrWhiteSpace([string]$old.reason)) {
        $row.reason = $old.reason
      }
    } elseif (-not $newSensitive -and $old.status -in @("read", "extracted-read")) {
      $row.status = "pending"
      $row.evidence_ids = ""
      $row.read_at = ""
      $row.reason = "content changed since last inventory; reread required"
    }
    $merged.Add($row)
  }
  foreach ($old in $previous.Values) {
    if ($scannedPaths.ContainsKey($old.path)) { continue }
    $sourceCandidate = Join-Path $SourceRoot ([string]$old.path).Replace("/", "\")
    if (-not $ScanTruncated -and -not (Test-Path -LiteralPath $sourceCandidate)) {
      $old.status = "removed-at-source"
      $old.reason = "path was present in a previous inventory but is absent from the current source"
    }
    $merged.Add($old)
  }
  return $merged
}

function Set-IntakePlaceholders {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ProjectSlug,
    [Parameter(Mandatory = $true)][string]$SourceRoot
  )
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $content = [IO.File]::ReadAllText($Path)
  if (
    $content.Contains("{{slug}}") -or
    $content.Contains("{{source_path}}") -or
    $content.Contains("{{project-slug}}")
  ) {
    $updated = $content.
      Replace("{{slug}}", $ProjectSlug).
      Replace("{{source_path}}", $SourceRoot).
      Replace("{{project-slug}}", $ProjectSlug)
    [IO.File]::WriteAllText($Path, $updated, [Text.UTF8Encoding]::new($false))
  }
}

while (($stack.Count -gt 0) -and (-not $truncated)) {
  $dir = $stack.Pop()
  foreach ($entry in Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue) {
    if ($entry.PSIsContainer) {
      if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $excludedDirs.Add([pscustomobject]@{
          path = Get-SafeRelativePath $source $entry.FullName
          reason = "reparse-point"
        })
      } elseif ($excludedDirNames -contains $entry.Name.ToLowerInvariant()) {
        $excludedDirs.Add([pscustomobject]@{
          path = Get-SafeRelativePath $source $entry.FullName
          reason = "generated/dependency/cache directory"
        })
      } else {
        $stack.Push($entry.FullName)
      }
      continue
    }

    $relative = Get-SafeRelativePath $source $entry.FullName
    $relativeNormalized = $relative.Replace("\", "/")
    if ($rows.Count -ge $MaxFiles) {
      $truncated = $true
      $truncationReason = "MaxFiles limit reached before traversal completed"
      break
    }
    $lowerName = $entry.Name.ToLowerInvariant()
    $extension = $entry.Extension.ToLowerInvariant()
    $isSensitive = ($sensitiveNames -contains $lowerName)
    if (-not $isSensitive) {
      foreach ($pattern in $sensitivePathRegexes) {
        if ($relativeNormalized -match $pattern) {
          $isSensitive = $true
          break
        }
      }
    }
    $class = "unsupported"
    $status = "unsupported"
    $reason = "unknown or unsupported binary format"
    $sha256 = ""

    if ($isSensitive) {
      $class = "sensitive"
      $status = "skipped-sensitive"
      $reason = "potential secret/auth/private-key material; content was not read or hashed"
    } elseif ($entry.Length -gt $MaxFileBytes) {
      $class = "oversized"
      $status = "unsupported"
      $reason = "file exceeds MaxFileBytes=$MaxFileBytes; no content read or hash computed; raise the limit or provide a reviewed extract"
    } elseif (($inventoryBytes + $entry.Length) -gt $MaxBytes) {
      $class = "budget-excluded"
      $status = "unsupported"
      $reason = "aggregate MaxBytes=$MaxBytes exhausted; no content read or hash computed; resume with a higher limit"
    } elseif ($relativeNormalized -match $generatedFileRegex) {
      $class = "generated-file"
      $status = "skipped-generated"
      $reason = "individual generated/lock artifact; metadata retained without content review"
    } else {
      $inventoryBytes += $entry.Length
      if (
        ($textExtensions -contains $extension) -or
        ($entry.Name -in @("Dockerfile", "Makefile", "Procfile", "LICENSE", "README"))
      ) {
        $class = "text/source"
        $status = "pending"
        $reason = "eligible text/source file"
      } elseif ($conversionRequiredExtensions -contains $extension) {
        $class = "conversion-required"
        $status = "unsupported"
        $reason = "legacy $extension requires human conversion (ppt->pptx/PDF, visio->PNG/PDF); place extract in intake/extracted/ then mark extracted-read; do not enter PPT production"
      } elseif ($binaryReviewExtensions -contains $extension) {
        $class = "binary-review"
        $status = "pending"
        if ($extractableBinaryExtensions -contains $extension) {
          $reason = "extract with python scripts/extract-office-text.py into intake/extracted/, then mark extracted-read"
        } else {
          $reason = "requires visual review via ReadFile"
        }
      } elseif ($indexedBinaryExtensions -contains $extension) {
        $class = "generated/media-binary"
        $status = "indexed"
        $reason = "metadata retained; content not decision-bearing by default"
      }
      try {
        $sha256 = (Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
      } catch {
        $reason = "$reason; hash unavailable"
      }
    }

    $rows.Add([pscustomobject]@{
      path = $relativeNormalized
      bytes = $entry.Length
      modified_utc = $entry.LastWriteTimeUtc.ToString("o")
      extension = $extension
      sha256 = $sha256
      class = $class
      status = $status
      reason = $reason
      evidence_ids = ""
      read_at = if ($status -eq "pending") { "" } else { $inventoryAt }
    })
  }
}

$ledgerPath = Join-Path $intake "reading-ledger.csv"
$manifestPath = Join-Path $intake "manifest.json"
$rows = Merge-IntakeLedgerRows `
  -Scanned $rows `
  -ExistingLedgerPath $ledgerPath `
  -SourceRoot $source `
  -ScanTruncated $truncated

$manifest = [ordered]@{
  version = 2
  slug = $Slug
  source_path = $source
  generated_at = $inventoryAt
  limits = [ordered]@{
    max_files = $MaxFiles
    max_bytes = $MaxBytes
    max_file_bytes = $MaxFileBytes
  }
  scan = [ordered]@{
    is_truncated = $truncated
    truncation_reason = $truncationReason
    inventory_bytes = $inventoryBytes
  }
  eligible_pending = @($rows | Where-Object status -eq "pending").Count
  removed_at_source = @($rows | Where-Object status -eq "removed-at-source").Count
  total_ledger_files = $rows.Count
  statuses = @{}
  excluded_directories = $excludedDirs
}
foreach ($group in $rows | Group-Object status) {
  $manifest.statuses[$group.Name] = $group.Count
}

$ledgerTemp = "$ledgerPath.tmp"
$manifestTemp = "$manifestPath.tmp"
try {
  $rows |
    Sort-Object path |
    Export-Csv -LiteralPath $ledgerTemp -NoTypeInformation -Encoding utf8
  $manifest |
    ConvertTo-Json -Depth 8 |
    Set-Content -LiteralPath $manifestTemp -Encoding utf8
  Move-Item -LiteralPath $ledgerTemp -Destination $ledgerPath -Force
  Move-Item -LiteralPath $manifestTemp -Destination $manifestPath -Force
} finally {
  Remove-Item -LiteralPath $ledgerTemp, $manifestTemp -Force -ErrorAction SilentlyContinue
}

$sourceDoc = @"
# Historical project source

| Field | Value |
|-------|-------|
| Slug | $Slug |
| Source path | ``$source`` |
| Inventory time (UTC) | $($manifest.generated_at) |
| Eligible files pending read | $($manifest.eligible_pending) |
| Ledgered files | $($manifest.total_ledger_files) |
| Excluded generated directories | $($excludedDirs.Count) |
| Scan truncated | $truncated |
| Truncation reason | $truncationReason |
| Inventory byte budget used | $inventoryBytes / $MaxBytes |
| Per-file byte limit | $MaxFileBytes |

The source remains in place. Intake must not execute unknown scripts or read
`skipped-sensitive` content. Sensitive and over-budget files are not hashed.
A truncated scan is partial intake and cannot pass `INTAKE_COMPLETE`; resume by
rerunning with larger limits. See `manifest.json` and `reading-ledger.csv`.

This file is the authoritative historical source record. `SOP.md` Historical
source is a central index that must point here; it is not a second source of
truth.
"@
$sourceDoc | Set-Content -LiteralPath (Join-Path $intake "SOURCE.md") -Encoding utf8

$sopFile = Join-Path $projectRoot "SOP.md"
$sourceIndex = "$source (see intake/SOURCE.md)"
[void](Update-SopFieldRow -SopPath $sopFile -Field "Historical source" -Value $sourceIndex)

$conversionRows = @($rows | Where-Object { $_.class -eq "conversion-required" -or $_.extension -eq ".ppt" })
$queuePath = Join-Path $intake "conversion-queue.md"
$queueLines = @(
  "# Conversion queue — $Slug",
  "",
  "Human conversion only. Do not load ``ppt-deck`` / ``ppt-studio`` because a ``.ppt`` exists.",
  "After converting, re-run inventory and extract the new file into ``intake/extracted/``.",
  "",
  "| path | extension | required output | status | notes |",
  "|------|-----------|-----------------|--------|-------|"
)
if ($conversionRows.Count -eq 0) {
  $queueLines += "| _none_ |  |  |  | no conversion-required files in this scan |"
} else {
  foreach ($row in $conversionRows) {
    $target = if ($row.extension -eq ".ppt") { ".pptx or PDF" } else { "PNG, PDF, or draw.io" }
    $queueLines += "| $($row.path) | $($row.extension) | $target | queued | $($row.reason) |"
  }
}
$queueLines | Set-Content -LiteralPath $queuePath -Encoding utf8

$templateRoot = Join-Path $SopRoot "projects\_template\intake"
foreach ($name in @("actual-state.md", "evidence-map.md", "stage-gap-matrix.md", "supplement-plan.md")) {
  $path = Join-Path $intake $name
  if (-not (Test-Path $path)) {
    $template = Get-Content -LiteralPath (Join-Path $templateRoot $name) -Raw -Encoding utf8
    $template.Replace("{{slug}}", $Slug).Replace("{{source_path}}", $source) |
      Set-Content -LiteralPath $path -Encoding utf8
  } else {
    Set-IntakePlaceholders -Path $path -ProjectSlug $Slug -SourceRoot $source
  }
}

$handoffTemplatePath = Join-Path $SopRoot ".cursor\skills\historical-project-onboarding\templates\handoff.md"
$handoffTemplate = Get-Content -LiteralPath $handoffTemplatePath -Raw -Encoding utf8
foreach ($stage in @("REQ", "UI", "ARCH", "TEST", "CODE", "DOCS")) {
  $path = Join-Path $handoffs "$stage.md"
  if (-not (Test-Path $path)) {
    $content = $handoffTemplate.Replace("{{STAGE}}", $stage).Replace("{{slug}}", $Slug).Replace("{{source_path}}", $source)
    $content | Set-Content -LiteralPath $path -Encoding utf8
  } else {
    Set-IntakePlaceholders -Path $path -ProjectSlug $Slug -SourceRoot $source
  }
}

Write-Output "Historical project inventory written: $intake"
Write-Output "Ledger files: $($rows.Count); eligible pending: $($manifest.eligible_pending); excluded dirs: $($excludedDirs.Count)"
if ($truncated) {
  Write-Warning "Inventory is partial: $truncationReason. INTAKE_COMPLETE validation will fail until rerun without truncation."
}
