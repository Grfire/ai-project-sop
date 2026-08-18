# Copy a stage vendor template into the sibling artifact root.
# Does not approve gates. PPT has no sibling template.
[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9][a-z0-9-]*$')]
  [string]$Slug,
  [Parameter(Mandatory = $true)]
  [ValidateSet("REQ", "UI", "ARCH", "CODE")]
  [string]$Stage,
  [string]$SopRoot,
  [string]$TargetRoot,
  [switch]$Force
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "lib\project-state.ps1")

$root = if (-not [string]::IsNullOrWhiteSpace($SopRoot)) {
  (Resolve-Path -LiteralPath $SopRoot).Path
} else {
  Split-Path $PSScriptRoot -Parent
}

$defaults = @{
  REQ  = @{ Template = "vendor-templates\req-project";  DefaultRoot = "E:/workspace/ai_req_analysis/projects/$Slug" }
  UI   = @{ Template = "vendor-templates\ui-project";   DefaultRoot = "E:/workspace/ai-font-design/projects/$Slug" }
  ARCH = @{ Template = "vendor-templates\arch-project"; DefaultRoot = "E:/workspace/ai_architecture_design/projects/$Slug" }
  CODE = @{ Template = "vendor-templates\code-project"; DefaultRoot = "E:/workspace/ai_code/project/$Slug" }
}

$spec = $defaults[$Stage]
$templateRoot = Join-Path $root $spec.Template
if (-not (Test-Path -LiteralPath $templateRoot -PathType Container)) {
  throw "Stage template missing: $templateRoot"
}

$destination = if (-not [string]::IsNullOrWhiteSpace($TargetRoot)) {
  $TargetRoot
} else {
  $spec.DefaultRoot
}
$destination = [IO.Path]::GetFullPath($destination)

$projectRoot = Join-Path $root "projects\$Slug"
if (Test-Path -LiteralPath (Join-Path $projectRoot "state.json")) {
  Assert-ProjectWritable -ProjectRoot $projectRoot -Intent delivery
}

if ((Test-Path -LiteralPath $destination) -and -not $Force) {
  [pscustomobject]@{
    slug = $Slug
    stage = $Stage
    target = $destination
    created = $false
    skipped = $true
    note = "Target already exists; pass -Force to replace. Scaffolding is not a gate."
  } | ConvertTo-Json -Compress
  exit 0
}

if ($PSCmdlet.ShouldProcess($destination, "Scaffold $Stage sibling from $($spec.Template)")) {
  $parent = Split-Path -Parent $destination
  if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  if (Test-Path -LiteralPath $destination) {
    Remove-Item -LiteralPath $destination -Recurse -Force
  }
  Copy-Item -LiteralPath $templateRoot -Destination $destination -Recurse

  $projectNameToken = "{{" + ([char]0x9879) + ([char]0x76EE) + ([char]0x540D) + ([char]0x79F0) + "}}"
  Get-ChildItem -LiteralPath $destination -Recurse -File |
    Where-Object { $_.Extension -in @(".md", ".json", ".yaml", ".yml", ".csv", ".ps1") } |
    ForEach-Object {
      $utf8 = [Text.UTF8Encoding]::new($false)
      $content = [IO.File]::ReadAllText($_.FullName, $utf8)
      $updated = $content.
        Replace("{{project-slug}}", $Slug).
        Replace("{{slug}}", $Slug).
        Replace($projectNameToken, $Slug)
      if ($updated -ne $content) {
        [IO.File]::WriteAllText($_.FullName, $updated, $utf8)
      }
    }
}

[pscustomobject]@{
  slug = $Slug
  stage = $Stage
  target = $destination
  created = $true
  skipped = $false
  note = "Sibling template copied. Stage gates remain conversational."
} | ConvertTo-Json -Compress
exit 0
