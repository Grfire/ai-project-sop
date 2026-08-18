# Pipeline state machine

Human authority is the approval/decision trail in `APPROVALS.md`,
`DECISIONS.md`, and `SOP.md`. `state.json` is a machine-readable cache only.
Canonical gate behavior is in [governance.md](governance.md).

## Stages

```text
New:        IDLE → REQ → UI → ARCH → TEST → CODE ⇄ TEST/REGRESSION → DOCS
                         └── PPT (only explicit user request; optional/parallel)

Historical: IDLE → INTAKE → owner backfill (REQ/UI/ARCH/TEST/CODE/DOCS)
                            → requested iteration stage
```

PPT is optional and may run in parallel after REQ 定稿, but only after an
explicit user request to make/edit/review a presentation. Artifact discovery
never triggers it.

`TEST` is the stage. `TEST_PACK` is its prepared artifact set.
`REGRESSION` is a TEST sub-mode (`mode=packaging|regression`), not a stage.
Delivery ends at DOCS. RELEASE, OPS, and maintenance are deferred.

## Status values

Stage status:

`not_started` | `in_progress` | `blocked` | `approved` | `na`

Project lifecycle:

`active` | `paused` | `cancelled` | `archived`

`blocked` must cite a gate id and owner role.

`state.json` conforms to `schemas/state.schema.json`. Producers write it through
`Write-CanonicalState` (record-gate, apply-gate-reset, set-lifecycle,
write-governance, new-project, regression, touch-code-change). The schema is
evidence, not approval.

Delivery writers call the centralized project-state guard and fail closed when
the parameter/path slug, existing `state.slug`, and a non-placeholder
`projects/CURRENT.md` slug disagree.

## Provisional UI

UI may start before `REQ_SIGNOFF` only with a recorded REQ draft waiver.
`UI_SIGNOFF` cannot become `approved` until `REQ_SIGNOFF` is approved.
Reconciliation against the 定稿 PRD is required before `UI_SIGNOFF`.

## Transitions

| From | To | Trigger |
|------|----|---------|
| IDLE | REQ | New project or resume without 定稿 PRD |
| IDLE/* | INTAKE | User brings an existing/historical project root for SOP takeover |
| INTAKE | owner stage(s) | user approves `INTAKE_COMPLETE`; supplement plan identifies owners |
| INTAKE | requested iteration | related SUP items `applied`/`waived` with existing canonical targets (validator evidence); then that stage's own conversational gate |
| REQ | UI | user approves `REQ_SIGNOFF` after conversational evidence |
| * | PPT | Current user message explicitly asks to create/edit/review a deck (draft PRD OK if recorded) |
| UI | ARCH | `REQ_SIGNOFF`; `UI_SIGNOFF` or recorded partial/none UI waiver |
| ARCH | TEST packaging | user approves `ARCH_SIGNOFF`; do not enter TEST/CODE from handoff publication alone |
| TEST packaging | CODE | user approves `TEST_PACK_READY` |
| CODE | TEST regression | user approves `CODE_READY`, or runtime-affecting code update requires rerun |
| TEST regression | CODE | failed evidence routes to 研发工程师 (or UI/ARCH per impact) |
| TEST regression | DOCS | user approves `REGRESSION_PASS` |
| DOCS | END | user approves `DOCS_COMPLETE` |
| * | REQ/UI/ARCH | Impact says upstream rewrite |

Never mark CODE `approved` or `DOCS_COMPLETE` while regression evidence is
stale (`last_regression_at` < `last_code_change_at`).

## Stage exits

| Stage | Exit |
|-------|------|
| UI | `UI_SIGNOFF`, or ARCH proceeds under a recorded partial/none UI waiver |
| CODE | `CODE_READY` explicit confirmation; any later runtime change resets it |
| DOCS | `DOCS_COMPLETE` explicit confirmation; this is the current lifecycle end |

## Gate reset

Apply the change-control matrix in `governance.md`. Reset affected stages,
supersede prior approvals, preserve history, and require fresh conversational
confirmation. A machine check can change evidence/status but never approve.
Resetting `REGRESSION_PASS` clears `last_regression_at`, the `regression`
summary, and regression mode. Resetting `TEST_PACK_READY` clears packaging
mode.
For a runtime-affecting CODE change, `touch-code-change.ps1` is the single
entry point: it requires the conversational decision identity/quote/reason,
resets `CODE_READY`, `REGRESSION_PASS`, and `DOCS_COMPLETE` first, then updates
`last_code_change_at`. If timestamp stamping fails after reset, the stale
approval caches remain invalidated.

## Per-turn SOP footer (编排官 or any role)

Keep it short:

```text
【SOP】slug={slug} 生命周期={active|paused|cancelled|archived} 当前={STAGE} mode={mode|none} 阻塞={无|gate+role}
```

When in REQ, the requirements skill's 【PRD 定稿自检】 still applies in addition.
