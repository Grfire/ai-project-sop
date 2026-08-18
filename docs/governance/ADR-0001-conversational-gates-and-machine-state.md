# ADR-0001: Conversational gates and non-authoritative machine state

- Status: Accepted
- Date: 2026-08-17

## Context

File-status heuristics and undefined gate labels can silently turn evidence into
approval. Portfolio work also needs a fast machine-readable state without
making JSON the source of human authorization.

## Decision

Use eight stable gate IDs: `INTAKE_COMPLETE`, `REQ_SIGNOFF`, `UI_SIGNOFF`,
`ARCH_SIGNOFF`, `TEST_PACK_READY`, `CODE_READY`, `REGRESSION_PASS`, and
`DOCS_COMPLETE`.

For each gate, the orchestrator presents the evidence checklist in chat, asks
for explicit confirmation, and appends the result to `APPROVALS.md`,
`DECISIONS.md` when rationale/waiver is involved, and the `SOP.md` log.

`state.json` mirrors indexable status, modes, timestamps, blocks, paths, and
approval references. It cannot approve a gate. Validators must not parse
Markdown checkboxes or infer approval from machine evidence.

TEST is the delivery stage. TEST_PACK is an artifact produced in packaging mode;
REGRESSION is TEST's regression mode. Delivery ends at DOCS. RELEASE, OPS, and
maintenance stages/roles remain deferred.

## Consequences

- Gate approval requires a user interaction and produces an auditable record.
- Scripts can cheaply gather evidence without replaying large artifacts.
- Material changes supersede approvals and reset downstream state.
- Partial/missing UI input to ARCH requires a bounded recorded waiver.
- Session startup can warn about stale regression and malformed state without
  blocking Cursor or fabricating approval.
