$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("sop-docs-smoke-" + [guid]::NewGuid())
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

try {
  Assert-PowerShellSyntax @(Join-Path $repoRoot "scripts\validate-docs-artifacts.ps1")
  New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot "style-memory\user-guide"), (Join-Path $tempRoot "output\user-guide") | Out-Null
  "card" | Set-Content -Path (Join-Path $tempRoot "style-memory\user-guide\style-card.md") -Encoding utf8
  "guide" | Set-Content -Path (Join-Path $tempRoot "output\user-guide\20260817-demo.md") -Encoding utf8
  @"
# Registry

| Type | Latest output | Style card | Sources | Source revision | Output revision | Stale |
|------|---------------|------------|---------|-----------------|-----------------|-------|
| user-guide | output/user-guide/20260817-demo.md | style-memory/user-guide/style-card.md | PRD.md | 2026-08-17T00:00:00Z | 2026-08-17T00:00:00Z | no |
"@ | Set-Content -Path (Join-Path $tempRoot "registry.md") -Encoding utf8

  & $shell -NoProfile -File (Join-Path $repoRoot "scripts\validate-docs-artifacts.ps1") -DocsPath $tempRoot
  if ($LASTEXITCODE -ne 0) { throw "valid registry should pass" }

  (Get-Content -Raw (Join-Path $tempRoot "registry.md")) -replace "no", "maybe" |
    Set-Content -Path (Join-Path $tempRoot "registry.md") -Encoding utf8
  & $shell -NoProfile -File (Join-Path $repoRoot "scripts\validate-docs-artifacts.ps1") -DocsPath $tempRoot
  if ($LASTEXITCODE -eq 0) { throw "invalid Stale value should fail" }

  Write-Output "Docs smoke tests passed."
} finally {
  Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}
