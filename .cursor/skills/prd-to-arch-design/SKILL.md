---
name: prd-to-arch-design
description: >-
  Orchestrates PRD (+ UI/prototype assets when present) into architecture /
  detailed design and an agent-ready package. Use when the user provides a PRD
  pack or asks for system architecture, detailed design, or coding-agent handoff.
  Sole router — peer skills run only under its phase gates. Always grill-me
  before publishing any design proposal; fuse UI with requirements when UI input exists.
  Only load when sop-orchestrator instructs.
disable-model-invocation: true
---

# PRD → Architecture Design (Orchestrator)

## SOP adapter

Loaded only by `sop-orchestrator`. Artifact root: `E:/workspace/ai_architecture_design/projects/<slug>/`. PRD from `ai_req_analysis`, UI from `ai-font-design`, same slug. Still the sole router **inside ARCH**; SOP owns cross-stage routing.

If historical intake exists, read
`E:/workspace/ai-project-sop/projects/<slug>/intake/handoffs/ARCH.md` before
Phase A. Preserve as-is evidence separately from to-be decisions; any proposed
change still passes the normal grill gate.

**Announce:** 「正在使用 `prd-to-arch-design`：PRD/UI → 融合验证 → 方案（grill 后落盘）→ coding handoff。」

## Hard rules (non-negotiable)

### R1 — Grill before every 方案 output

Anytime this pipeline is about to **publish a proposal** (options recommendation, architecture/详细设计落盘, or agent-package specs that encode the solution), you MUST:

1. Draft the proposal (do not treat it as final yet)
2. Invoke **`grill-me`** → **`grilling`** on that draft
3. Reach shared understanding (or batch-adapted confirmation — see Modes)
4. Amend the draft from grill outcomes
5. Only then write/update SSOT deliverables

**方案 outputs that require a grill gate:**

| Output | Grill focus |
|--------|-------------|
| Architecture options + recommendation | Trade-offs, failures, operability |
| Detailed design pack (`02`–`06`) | Seams, data, authz, edge cases vs PRD |
| `07-agent-spec.md` / plan that freezes the solution | Test seams, scope creep, missing stories |

Do **not** skip grill because the draft “looks simple.” Multiple gates in one run are expected (e.g. grill options → grill detailed design → then package).

### R2 — Fuse UI + requirements when upstream includes UI

If ingest finds **any UI input** (prototype links, images, HTML/Figma/sketch, screen PDFs, interaction notes tied to screens), you MUST run **UI×Req fusion validation** before architecture freeze:

1. Map screens/flows ↔ F-xx / P-xx / acceptance (`01-prototype-map.md`)
2. Write fusion result (`01a-ui-req-validation.md`): covered / gaps / contradictions / unresolved
3. **PRD wins** on product acceptance; UI wins on interaction affordance **only when PRD is silent** — record that in ASSUMPTIONS
4. If fusion leaves a blocking “does this interaction/state feel right?” question → `prototype` (UI or LOGIC branch) under `_probe/`, then fold verdict back into fusion + design
5. Phase B design MUST cite fusion outcomes; do not design from PRD alone or UI alone

If there is **no UI input**, skip fusion (mark N/A in `PIPELINE.md`).

## Capability map

Read peers from `.cursor/skills/peers/<name>/SKILL.md` (see `sop-orchestrator/tools.md`). Do not rely on global auto-trigger.

| Skill | Role |
|-------|------|
| ARCH-local ingest (this root skill) | **Entry** — read PRD and available UI evidence; write `design/00-brief.md` and `design/PIPELINE.md` |
| `brainstorming` | **Design spine** — options + design sections |
| `grill-me` / `grilling` | **Gate** — before every 方案 publish (R1) |
| `domain-modeling` / `codebase-design` / `design-an-interface` | Inside design when triggers match |
| `design-documentation` | Section checklist for design-pack |
| `prototype` | Fusion aid or single open logic/UI question (`_probe/`) |
| `writing-plans` / `session-handoff` | Agent package after this root drafts and grills `07-agent-spec.md` |

`prd-pack-ingest`, `visual-choice-first`, and `frontend-design-studio` are UI
suite workers, not ARCH workers. Phase A must not load them. If production UI
work is requested, return to `sop-orchestrator` for a STAGE switch.

### Phase peer budget

The root skill remains the sole ARCH router. Read only the active phase's
allowlist; never ambient-load peers or carry them into the next phase.

| Phase | Allowed peers | Budget |
|-------|---------------|--------|
| A | none (ARCH-local ingest) | 0 |
| A2 | `prototype` only when one named question blocks fusion | ≤1 |
| B | `brainstorming` + at most one of `domain-modeling`, `codebase-design`, `design-an-interface`, `design-documentation` | ≤2 |
| G | `grill-me` + `grilling` | exactly 2 |
| C | `writing-plans` + `session-handoff` | ≤2; use serially |

## Authority

| Conflict | Winner |
|----------|--------|
| Phase order / R1–R2 | **This skill** |
| Product acceptance / F-xx | **PRD** |
| Interaction detail when PRD silent | **UI** + ASSUMPTIONS note |
| UI vs PRD contradiction | Stop; resolve with user (do not silently pick) |
| Domain / seams / interfaces | domain-modeling / codebase-design / design-an-interface |
| Agent spec | this ARCH root, then G grill |
| Implementation plan | writing-plans |
| ARCH→CODE package | session-handoff writes canonical `CODING_HANDOFF.md` |

**Hard bans:** no production app code and no direct CODE execution. Probe code
only under `_probe/`; execution begins only after SOP routes to `dev-agent`.

## Modes

| Mode | Grill (R1) | Fusion (R2) |
|------|------------|-------------|
| `interactive` | Full `grilling`: one question at a time until shared understanding | Full map + user on contradictions |
| `batch` | Still **must** run grill: walk decision branches with **recommended answers**; user may confirm “按推荐” in one shot; **stop** if any blocker lacks a safe default | Auto-fill fusion; contradictions → ASSUMPTIONS or stop if core flow breaks |

## Deliverable tree

```text
E:/workspace/ai_architecture_design/projects/<project-slug>/
├── README.md                            # 项目引用入口
├── CONTEXT.md
├── adr/                                 # 本项目 ADR
└── design/
    ├── PIPELINE.md
    ├── ASSUMPTIONS.md
    ├── 00-brief.md
    ├── 01-prototype-map.md              # UI present
    ├── 01a-ui-req-validation.md         # UI present — fusion result
    ├── 02-architecture.md
    ├── 03-domain.md
    ├── 04-module-design.md
    ├── 05-api-data.md
    ├── 06-nfr-ops.md
    ├── 07-agent-spec.md
    ├── 08-implementation-plan.md
    ├── 09-grill.md                      # append each grill gate
    ├── tasks/                           # optional root-derived task slices
    ├── _probe/                          # optional prototype
    └── CODING_HANDOFF.md
```

## Pipeline

### Phase A — Ingest (required)

**Worker:** ARCH-local ingest in this root skill; **do not load UI
`prd-pack-ingest`**  
**Read:** finalized PRD from
`E:/workspace/ai_req_analysis/projects/<slug>/` and any named UI evidence from
`E:/workspace/ai-font-design/projects/<slug>/` (including design spec,
prototype map/routes, visual decision evidence, and `UI_SIGNOFF` state)  
**Write:** `design/00-brief.md`, `design/PIPELINE.md` in the ARCH artifact root.
The brief records source paths/versions, scope, F/P/AC indexes, hard constraints,
sample-data pointers, UI evidence inventory, and open architecture questions.
The pipeline records the same input pointers plus `UI_INPUT`,
`ui_input_mode`, current phase, and active peer set.  
**Detect:** `UI_INPUT=yes|no`  
**Set `ui_input_mode`:** `complete` if `UI_SIGNOFF` is approved; `partial` if named UI artifacts exist without `UI_SIGNOFF`; `none` if no UI input. Write the cache:

```powershell
.\scripts\write-governance.ps1 -Slug <slug> -UiInputMode complete|partial|none
```

`partial` or `none` requires a recorded waiver (`record-gate` / `DECISIONS.md`) before presenting `ARCH_SIGNOFF`. Do not claim full UI compatibility in those modes.
**If UI_INPUT=yes:** draft `01-prototype-map.md` skeleton from assets
**Override:** do not chain into or reuse any UI suite worker  
**Exit:** brief ready; UI flag and `ui_input_mode` set

### Phase A2 — UI×Req fusion (required if UI_INPUT=yes)

**Workers:** orchestrator mapping; `prototype` only if a concrete interaction/state question blocks fusion  
**Write:** `01-prototype-map.md`, `01a-ui-req-validation.md`  
**Exit:** no unresolved **core-flow** contradiction; gaps listed (in/out/deferred)

### Phase B — Design draft (required)

**Peers:** `brainstorming` plus at most one triggered specialist from the Phase
B allowlist  
**Write drafts** of `02`–`06` (and domain/ADR) — **not final until grill**  
If UI_INPUT=yes, design must reference `01a-ui-req-validation.md`  
**Exit:** draft proposal ready for grill

### Phase G — Grill gate (required before publish)

**Worker:** `grill-me` → `grilling`  
**Input:** the draft about to be published  
**Write:** append session to `09-grill.md`; fold amendments into draft  
**Exit:** shared understanding (or batch “按推荐” with no open blockers)  
**Then** publish amended content to SSOT (`02`–`06`, etc.)

Re-enter **B → G** if design materially changes after fusion/probe.

### Phase C — Agent package (required)

1. This ARCH root drafts `07-agent-spec.md` from the published design → **G
   grill** on that draft → publish `07`  
2. `writing-plans` → `08-implementation-plan.md` (plan implements grilled solution; if plan introduces new solution choices, **G** again on those choices)  
3. Optional `tasks/` may be written by this root from the accepted plan; do not
   load another peer merely to expand the package  
4. Release `writing-plans`, then `session-handoff` writes
   `design/CODING_HANDOFF.md` from the canonical
   [template](templates/CODING_HANDOFF.md); do not create a temporary generic summary
5. Return to `sop-orchestrator`. Present `ARCH_SIGNOFF` evidence. TEST packaging
   starts only after the user confirms `ARCH_SIGNOFF`. CODE starts only after
   `TEST_PACK_READY`. Handoff publication is not a gate.

## PIPELINE.md

```markdown
# Pipeline: <project-slug>
- Mode: interactive | batch
- UI_INPUT: yes | no
- Phase: A|A2|B|G|C|DONE
- Active peers: [] # phase allowlist only
- [ ] A Ingest
- [ ] A2 UI×Req fusion (N/A | done)
- [ ] B Design draft
- [ ] G Grill → publish design
- [ ] C Package (root spec[+G] + plan + [tasks] + handoff)
```

## Coding-agent contract

1. `CODING_HANDOFF.md` → `08` → `07` → design / fusion / ADRs as needed  
2. Tickets if present; else plan tasks  
3. PRD = product SSOT; design-pack = tech SSOT; fusion records UI alignment  
4. Return to `sop-orchestrator`, which presents `ARCH_SIGNOFF` then routes
   TEST packaging. Execution begins only after `TEST_PACK_READY` and a switch
   to `dev-agent` → `.cursor/skills/phases/implement/SKILL.md`; CODE may load
   its TDD discipline peer

## Progressive disclosure

- [references/phase-contract.md](references/phase-contract.md)
- [references/conflict-matrix.md](references/conflict-matrix.md)
- [templates/](templates/)

## Historical supplement closeout

When applying an intake SUP item to a canonical artifact:

1. Edit the canonical file at this stage's sibling root (never the SOP intake copy).
2. Add a `BACKFILL-<STAGE>-<nnn>` row to `E:/workspace/ai-project-sop/projects/<slug>/intake/evidence-map.md` citing intake evidence and the canonical path.
3. Run:

```powershell
.\scripts\apply-supplement.ps1 -Slug <slug> -SupplementId SUP-... `
  -CanonicalTarget <absolute-or-relative-path> -BackfillId BACKFILL-... `
  -AppliedBy "<identity from chat>" -TargetStage <STAGE>
```

4. Keep the `validate-supplement.ps1` report as provenance evidence.
5. Do not treat applied/waived as a human gate. Stage sign-off remains conversational.

## Stop conditions

PRD missing/unfinalized; UI×PRD core-flow contradiction unresolved; grill blockers unresolved; security/deploy baseline missing when the domain requires it.
