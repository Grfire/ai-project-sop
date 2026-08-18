# Session start — inject resilient SOP context (JSON on stdout).
param(
    [string]$SopRoot
)
$ErrorActionPreference = "Stop"

try {
    $root = if (-not [string]::IsNullOrWhiteSpace($SopRoot)) {
        $SopRoot
    } else {
        Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    }
    if (-not $root) { $root = (Get-Location).Path }

    $slug = "unset"
    $stage = "unknown"
    $mode = "none"
    $lifecycle = "unknown"
    $blocked = "none"
    $warnings = [Collections.Generic.List[string]]::new()
    $current = Join-Path $root "projects\CURRENT.md"

    if (Test-Path -LiteralPath $current) {
        $match = Select-String -LiteralPath $current -Pattern '^\s*slug:\s*(\S+)\s*$' |
            Select-Object -First 1
        if ($match) { $slug = $match.Matches[0].Groups[1].Value }
        else { $warnings.Add("CURRENT.md has no readable slug") }
    }
    else {
        $warnings.Add("projects/CURRENT.md is missing")
    }

    if ($slug -ne "unset") {
        $statePath = Join-Path $root "projects\$slug\state.json"
        if (Test-Path -LiteralPath $statePath) {
            try {
                $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
                if ($state.slug -and $state.slug -ne $slug) {
                    $warnings.Add("slug mismatch: CURRENT=$slug state=$($state.slug); stop writes until resolved")
                }
                if ($state.current_stage) { $stage = $state.current_stage }
                if ($state.mode) { $mode = $state.mode }
                if ($state.lifecycle) { $lifecycle = $state.lifecycle }
                if ($lifecycle -in @("paused", "cancelled", "archived")) {
                    $warnings.Add("lifecycle=$lifecycle; paused blocks delivery writes, cancelled allows cancellation records only, archived is read-only until set-lifecycle reactivation")
                }
                if ($state.blocked) { $blocked = $state.blocked | ConvertTo-Json -Compress }

                $codeAt = $state.timestamps.last_code_change_at
                $regressionAt = $state.timestamps.last_regression_at
                if ($codeAt) {
                    $codeTime = [DateTimeOffset]::Parse($codeAt)
                    if (-not $regressionAt -or [DateTimeOffset]::Parse($regressionAt) -lt $codeTime) {
                        $warnings.Add("regression evidence is stale or missing after the last code change")
                    }
                }

                $lastRunPath = Join-Path $root "projects\$slug\test\last-run.json"
                if (Test-Path -LiteralPath $lastRunPath) {
                    try {
                        $lastRun = Get-Content -LiteralPath $lastRunPath -Raw | ConvertFrom-Json
                        if ($lastRun.overall -eq "FAIL") {
                            $warnings.Add("last-run.json overall=FAIL; do not treat regression as passed")
                        }
                        if ($lastRun.mode -and $lastRun.mode -ne "full" -and $lastRun.overall -eq "PASS") {
                            $warnings.Add("last-run.json mode=$($lastRun.mode) is not full regression evidence")
                        }
                        if ($state.regression -and $state.regression.state -eq "passed" -and $lastRun.overall -eq "FAIL") {
                            $warnings.Add("state.json regression.state=passed disagrees with last-run overall=FAIL")
                        }
                    }
                    catch {
                        $warnings.Add("last-run.json unreadable: $($_.Exception.Message)")
                    }
                }
                if ($state.regression -and $state.regression.state -eq "failed") {
                    $warnings.Add("machine regression state is failed")
                }
            }
            catch {
                $warnings.Add("state.json unreadable: $($_.Exception.Message)")
            }
        }
        else {
            $warnings.Add("state.json is missing for active slug")
        }
    }

    $warningText = if ($warnings.Count) { $warnings -join "; " } else { "none" }
    $ctx = @"
SOP workspace. Active slug: $slug. Lifecycle: $lifecycle. Stage: $stage. Mode: $mode. Blocked: $blocked.
Warnings: $warningText.
Read .cursor/skills/sop-orchestrator/SKILL.md; load exactly one routed stage skill. Use governance.md for gates and recovery.md for mismatches.
Human gates are conversational: present evidence, require explicit user confirmation, then record it. state.json and machine checks are evidence only; never parse Markdown checkboxes.
PPT requires explicit current-user create/edit/export/review intent. Delivery ends at DOCS; RELEASE/OPS/maintenance are deferred.
"@
}
catch {
    $ctx = "SOP workspace startup degraded: $($_.Exception.Message). Read .cursor/skills/sop-orchestrator/SKILL.md and recover without guessing project state or approvals."
}

[ordered]@{ additional_context = $ctx.Trim() } | ConvertTo-Json -Compress
