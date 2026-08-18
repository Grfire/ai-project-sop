# Governance protocol

This file is canonical for human gates, lifecycle control, waivers, and machine
state. Delivery currently ends at **DOCS**. RELEASE, OPS, maintenance, and their
roles are deferred scope and must not be invented.

## Conversational gate protocol

A gate passes only through this conversation:

1. The orchestrator names the stable gate ID and presents every evidence item
   as a compact numbered list.
2. Machine checks may provide evidence such as file existence, test results, or
   timestamp freshness. They never approve a gate.
3. The user explicitly confirms the named gate after seeing the evidence.
   Silence, an inferred intent, a file status, or a Markdown checkbox is not
   confirmation.
4. Record the decision in `APPROVALS.md`, rationale/waiver in `DECISIONS.md`,
   and a short event in the `SOP.md` log. Mirror only non-authoritative status,
   timestamps, and approval references into `state.json`.

Never implement a validator that parses Markdown checkboxes or automatically
passes a human gate. Use `scripts/record-gate.ps1` and
`scripts/apply-gate-reset.ps1` only to record a decision that already happened
in chat. Those commands require an explicit confirmation quote and still set
`human_gate_approved=false`.

## Lifecycle write-stop

`active | paused | cancelled | archived` is portfolio handling, not a delivery
stage. Change it only with `scripts/set-lifecycle.ps1` after conversational
confirmation.

| Lifecycle | Delivery writes | Notes |
|-----------|-----------------|-------|
| `active` | allowed | default |
| `paused` | blocked | gate records retained; only lifecycle changes are written |
| `cancelled` | blocked except cancellation records | cannot move to another lifecycle |
| `archived` | read-only | reactivation is `set-lifecycle -Lifecycle active` after chat confirmation |

`session-start.ps1` warns on non-active lifecycle. `set-active-slug.ps1` does
not change lifecycle. Machine state never unpauses or reactivates a project.
After cancellation, only `scripts/record-cancellation.ps1` may append a
cancellation follow-up to `DECISIONS.md` and the SOP log. It cannot change
lifecycle or gates; all delivery writers remain blocked.

## Gate transaction tools

After the user explicitly confirms a named gate:

1. Present evidence in chat (this protocol).
2. Record with `scripts/record-gate.ps1` (`approved` / `rejected` / `waived`).
3. For governed change/rollback, record with `scripts/apply-gate-reset.ps1`.

`state.json` fields `stage_status`, `blocked`, `approval_refs`, and
`governance.active_waiver_ids` are caches. `schemas/state.schema.json` and
`scripts/validate-json-schema.py` validate the cache; they do not approve.

Rejected gates set `stage_status=<stage>:blocked` and
`blocked={gate_id,owner_role,reason,since}`. They remove the rejected gate and
all downstream `approval_refs`, clear downstream timestamps/regression cache,
and mark downstream stages `in_progress`. Approval attempts also recheck the
complete prerequisite chain, so stale refs from an older state cannot bypass an
upstream rejection. An unrelated approval never clears the active block.
Reset supersedes prior `APR-*` ids, sets affected stages to `in_progress` or
`blocked`, and requires a new conversational confirmation.

Before recording an `approved` decision, `record-gate.ps1` fail-closes on these
machine-evidence prerequisites:

- `ARCH_SIGNOFF`: `REQ_SIGNOFF`; `ui_input_mode=complete` also requires
  `UI_SIGNOFF`, while `partial|none` requires an active, scoped
  `ARCH_SIGNOFF` waiver.
- `TEST_PACK_READY`: `ARCH_SIGNOFF`.
- `CODE_READY`: `TEST_PACK_READY`.
- `REGRESSION_PASS`: `CODE_READY` plus matching `test/last-run.json` with
  `mode=full`, `overall=PASS`, and timestamps proving freshness against
  `last_code_change_at`.
- `DOCS_COMPLETE`: `REGRESSION_PASS`, an independent revalidation of the same
  full-PASS `last-run.json` freshness against the current
  `state.timestamps.last_code_change_at`, plus a successful
  `validate-docs-artifacts.ps1` run. A cached `REGRESSION_PASS` ref alone is
  insufficient.
- Historical `INTAKE_COMPLETE`: a successful
  `validate-intake-artifacts.ps1` run.

These checks can reject a recording attempt; they still output no human
approval and never replace the conversational protocol.

## Provisional UI draft waiver

Routing may allow UI work before `REQ_SIGNOFF` only with an explicit bounded
draft waiver recorded as `record-gate.ps1 -GateId REQ_SIGNOFF -Decision waived`.

The waiver must name missing PRD evidence, risk owner, bounded UI scope,
expiry/review trigger, and the required reconciliation (re-read 定稿 PRD).
It does **not** complete `UI_SIGNOFF`. `record-gate` rejects `UI_SIGNOFF`
approved while REQ is not approved, and rejects waiving `UI_SIGNOFF` itself.

Exit the waiver by either:

- user approves `REQ_SIGNOFF`, then UI is re-checked against the 定稿 PRD before `UI_SIGNOFF`; or
- abandon the provisional UI work and record that decision.

## Stable gates and evidence

| Gate ID | Owner | Evidence presented in chat | Unlocks |
|---------|-------|----------------------------|---------|
| `INTAKE_COMPLETE` | 项目接管分析师 | ledger has no eligible pending row; actual/evidence/gaps exist; six handoffs and supplement plan exist | owner backfill |
| `REQ_SIGNOFF` | 需求分析师 | PRD identity/status; scope and exclusions; F/AC coverage; unresolved items; compliance classification | UI and ARCH entry |
| `UI_SIGNOFF` | 原型设计师 | chosen visual direction; design-spec/prototype path; required states and acceptance mapping; accessibility notes | full-UI ARCH input |
| `ARCH_SIGNOFF` | 架构师 | architecture pack and `CODING_HANDOFF.md`; closed grill findings; security/compliance/cost decisions; UI input mode | TEST pack creation |
| `TEST_PACK_READY` | 测试架构师 | catalog maps requirements/interfaces to code and product cases; runnable commands/skeletons; environment gaps | CODE entry |
| `CODE_READY` | 研发工程师 | accepted slice implemented; code tests/build pass; run card/handoff; access URL smoke or recorded N/A | regression |
| `REGRESSION_PASS` | 测试架构师 | `last-run.json`; required suites pass; result is newer than last runtime code change; known limitations | DOCS completion |
| `DOCS_COMPLETE` | 文档专员 | registry; required document set; style-card use; source traceability; unresolved documentation gaps | lifecycle delivery end |

`INTAKE_COMPLETE` unlocks owner-controlled backfill. Entering a named
iteration stage additionally requires `validate-supplement.ps1 -TargetStage
<STAGE>` evidence: related SUP items are `applied` or `waived`, applied
canonical targets exist, and BACKFILL IDs are present. That report is
evidence only; the stage's own conversational gate still applies.

There are no `G1`–`G7` gates.

## Approval record

Every approval record includes: approval ID, gate ID, project slug, evidence
snapshot or links, decision (`approved`, `rejected`, `waived`), approver
identity as stated in chat, confirmation quote, UTC timestamp, scope/version,
and superseded approval ID when applicable.

## Partial-UI ARCH rule

ARCH may start after `REQ_SIGNOFF` with `ui_input_mode`:

- `complete`: `UI_SIGNOFF` is approved.
- `partial`: named UI artifacts are available but `UI_SIGNOFF` is not approved.
  ARCH must mark UI-dependent decisions provisional and cannot claim full UI
  compatibility.
- `none`: no UI input; ARCH records assumptions and UI integration risk.

`partial` or `none` requires a recorded waiver before `ARCH_SIGNOFF`. The
waiver names missing evidence, risk owner, bounded scope, expiry/review trigger,
and required reconciliation. It cannot waive legal/compliance obligations.

## Change-control and rollback matrix

| Change after approval | Reset gates | Required action / rollback |
|-----------------------|-------------|----------------------------|
| Product scope, role, acceptance, classification | `REQ_SIGNOFF` and all downstream approvals | restore last approved PRD or revise/reconfirm; refresh UI/ARCH/TEST |
| Visual flow/state affecting acceptance | `UI_SIGNOFF`, `ARCH_SIGNOFF`, `TEST_PACK_READY`, `CODE_READY`, `REGRESSION_PASS`, `DOCS_COMPLETE` | restore approved prototype or revise/reconfirm |
| API, data, authz, topology, module seam | `ARCH_SIGNOFF` and downstream approvals | restore approved design/implementation or republish/grill |
| Test coverage, command, required environment | `TEST_PACK_READY`, `CODE_READY`, `REGRESSION_PASS`, `DOCS_COMPLETE` | restore prior pack or reapprove and rerun |
| Runtime-affecting code | `CODE_READY`, `REGRESSION_PASS`, `DOCS_COMPLETE` | revert code or re-establish readiness and full regression |
| Documentation-only factual/style change | `DOCS_COMPLETE` | restore approved docs or reapprove docs |
| Evidence correction with no governed outcome change | affected gate only if material | record decision explaining materiality |

Reset means `state.json` status becomes `in_progress` or `blocked`, the old
approval is marked superseded in `APPROVALS.md`, and the reason is logged.
Never delete prior decisions.

Every runtime-affecting CODE change is recorded through
`touch-code-change.ps1` with mandatory `DecisionMaker`, `ConfirmationQuote`,
and `Reason`. That command performs the `runtime_code` reset before advancing
`last_code_change_at`; machine evidence is invalidated fail-closed and
`human_gate_approved` remains `false`.

## Waivers

Waivers are exceptional, explicit user decisions. Present the missing checklist
items and consequences in chat. Record scope, rationale, risk owner, compensating
controls, expiry/review trigger, and affected gates in `DECISIONS.md`; record a
`waived` approval. Waivers do not fabricate evidence, do not silently flow to
unrelated gates, and reset when their scope changes or expiry is reached.

## Project lifecycle

`active | paused | cancelled | archived` describes portfolio handling, not a
delivery stage. Paused projects retain gate state. Cancelled projects accept no
writes except cancellation records. Archived projects are read-only until an
explicit conversational reactivation decision.

## Data, compliance, and cost governance

Before `REQ_SIGNOFF`, record data classification (`public | internal |
confidential | restricted`), regulated-data categories, residency/retention,
access/audit requirements, third-party transfer, and compliance owner. Unknown
fields block approval unless explicitly waived where legally permissible.

Do not place secrets or sensitive samples in governance records. Store
references and redacted evidence.

For repeatable inventory, test, extraction, and comparison work, use scripts
first and summarize outputs in chat. Avoid replaying large artifacts or test
catalogs to save cost/tokens. Human gate evidence and confirmation must still
be conversational.
