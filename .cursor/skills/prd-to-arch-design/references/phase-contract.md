# Phase Contract

## Phase A — Ingest

- [ ] PRD 定稿 known
- [ ] ARCH-local ingest read PRD plus available UI evidence
- [ ] `design/00-brief.md` records source paths/versions, F/P/AC scope,
      constraints, sample data, UI evidence, and open architecture questions
- [ ] `UI_INPUT=yes|no`, `ui_input_mode`, input pointers, phase, and active peer
      set recorded in `design/PIPELINE.md`
- [ ] No UI-suite worker loaded; Phase A peer count = 0
- [ ] No production-UI skill chain

## Phase A2 — UI×Req fusion (if UI_INPUT=yes)

- [ ] `01-prototype-map.md`: screen/flow ↔ F-xx/P-xx/acceptance
- [ ] `01a-ui-req-validation.md`: covered / gaps / contradictions / deferred
- [ ] Core-flow contradictions resolved with user (or stopped)
- [ ] Optional `_probe/` only for a named interaction/state question
- [ ] Active peer set is empty or only `prototype`
- [ ] Or mark A2 = N/A when no UI

## Phase B — Design draft

- [ ] `brainstorming` options + design sections drafted
- [ ] At most one triggered specialist accompanies `brainstorming` (≤2 peers)
- [ ] If UI: draft cites `01a-ui-req-validation.md`
- [ ] Draft ready — **not published**

## Phase G — Grill → publish

- [ ] Exactly `grill-me` + `grilling` on the draft to publish (2 peers)
- [ ] `09-grill.md` appended
- [ ] Amendments folded
- [ ] SSOT `02`–`06` (etc.) published only after gate

## Phase C — Package

- [ ] Root drafts `07` → G grill → publish `07`
- [ ] `writing-plans` writes `08-implementation-plan.md`; G if new solution choices appear
- [ ] Optional `tasks/` derived by the root without another peer
- [ ] Release plan peer; `session-handoff` writes `CODING_HANDOFF.md`
- [ ] C allowlist remains `writing-plans` + `session-handoff` (≤2, serial)
- [ ] DONE

## Done when

Fresh agent can start plan/ticket 1; every published 方案 has a grill record in `09-grill.md`.
