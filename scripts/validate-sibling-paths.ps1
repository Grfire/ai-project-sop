[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')]
    [string]$Slug
)

$paths = [ordered]@{
    INTAKE = "E:/workspace/ai-project-sop/projects/$Slug/intake"
    REQ    = "E:/workspace/ai_req_analysis/projects/$Slug"
    UI     = "E:/workspace/ai-font-design/projects/$Slug"
    ARCH   = "E:/workspace/ai_architecture_design/projects/$Slug"
    CODE   = "E:/workspace/ai_code/project/$Slug"
    TEST   = "E:/workspace/ai-project-sop/projects/$Slug/test"
    DOCS   = "E:/workspace/ai-project-sop/projects/$Slug/docs"
}

$results = foreach ($entry in $paths.GetEnumerator()) {
    [pscustomobject]@{
        Stage  = $entry.Key
        Path   = $entry.Value
        Exists = Test-Path -LiteralPath $entry.Value
    }
}

$results

if ($results.Exists -contains $false) {
    Write-Warning "One or more sibling paths are missing. This is machine evidence only; it does not fail or approve a human gate."
}
