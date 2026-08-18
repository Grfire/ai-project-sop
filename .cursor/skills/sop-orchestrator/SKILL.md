---
name: sop-orchestrator
description: >-
  Unique auto-entry for the AI project delivery SOP. Identifies user intent,
  switches role identity, routes to stage skills (historical intake,
  requirements, explicit-only PPT, prototype, architecture, code, test, docs),
  triages which stage and role own a change or gate, and enforces cross-stage
  impact plus post-code full regression. Use when discussing 历史项目接管,
  落地项目, SOP, 需求, PRD, 原型, 技术方案, 架构, 开发, 改代码, 门禁, 目标,
  回归, 测试, 文档产出, or an explicit request to make/edit a PPT.
---

# SOP Orchestrator

Unique auto-entry for this workspace. **Never** rely on transplanted stage skills auto-triggering.

Announce on session start (or first routed turn):

「正在使用 `sop-orchestrator`：意图分诊 → 角色切换 → 阶段技能 → 影响回归。」

## Startup (every session)

1. Read [workspace-map.md](workspace-map.md)
2. Resolve slug from the user's explicit slug, target path, `projects/CURRENT.md`,
   and project `state.json`. Before any write, warn and stop if they disagree.
3. Read `projects/<slug>/SOP.md` and `state.json` if present
4. Route with [routing.md](routing.md) + [identity.md](identity.md)
5. If the utterance is 修改 / 门禁 / 目标 / 失败 / 直接改代码 → also Read [impact.md](impact.md) **before** any stage work
6. For a gate or approval, follow [governance.md](governance.md): present the
   checklist in chat and obtain explicit user confirmation. Machine state is
   evidence only.
7. Read [tools.md](tools.md) when the stage needs MCP/browser/CLI (UI visual, TEST, PPT preview, CODE smoke)
8. If the user brings an existing/historical project → route to INTAKE before
   assuming REQ/ARCH/CODE completeness

Copy and track:

Track operational progress without treating it as gate approval: active slug,
role banner, impact triage, one primary STAGE suite, its single active worker,
correct artifact root, post-CODE regression, and explicit-only PPT routing.

## Hard rules

1. **One primary STAGE suite per turn-budget.** Read that suite's entry/root
   skill with the Read tool. A suite may activate only the internal worker
   allowed by its contract, one at a time; release it before reading the next.
   Never ambient-load workers or another STAGE.
2. **Identity banner** before acting as a role ([identity.md](identity.md)).
3. **分诊 before CODE.** Direct “让 code 改” still runs [impact.md](impact.md). If REQ/ARCH/UI must move, say so and switch; do not silently patch product meaning in code.
4. **TEST_PACK after `ARCH_SIGNOFF`.** Do not enter CODE until the user
   explicitly confirms `TEST_PACK_READY` after seeing its evidence.
5. **Full regression after every runtime-affecting CODE update.** Run `project-test` scripts; read `last-run.json`; do not re-list cases in chat.
6. **PRD is product SSOT. ARCH design-pack is tech SSOT.** Chat does not override them unless the user explicitly changes requirements/design.
7. **Artifact roots** follow [workspace-map.md](workspace-map.md). SOP repo
   `projects/<slug>/` stores orchestration state (`SOP.md`, `IMPACT.md`,
   `APPROVALS.md`, `DECISIONS.md`, `state.json`), `intake/`, `test/`, and `docs/`.
8. **Tools** follow [tools.md](tools.md). UI/TEST/PPT preview use
   `cursor-ide-browser`; full product regression uses scripts + MCP
   `playwright`. UI serializes ingest → visual → studio. ARCH peers live under
   `.cursor/skills/peers/` and are phase-allowlisted (normally ≤2; grill pair
   counts as 2). CODE/PPT retain their own budgets.
9. **Historical intake before iteration.** Build a complete reading ledger,
   evidence map, gaps, and stage handoffs; do not execute unknown scripts or
   read secrets.
10. **PPT explicit-only.** Existing `.ppt/.pptx`, references to slides, or intake
    extraction never trigger PPT. Load `ppt-deck` only for an explicit current
    request to create/edit/regenerate/beautify/convert/export/review a deck.
11. **Human gates are conversational.** Use only stable IDs in
    [governance.md](governance.md). Present evidence, obtain explicit user
    confirmation, and record it. Never parse checkboxes or auto-pass a gate.
12. **Lifecycle ends at DOCS.** RELEASE, OPS, and maintenance stages/roles are
    deferred and are not part of the current state machine.

## Stage skill paths (Read these)

| STAGE | Path |
|-------|------|
| INTAKE | `.cursor/skills/historical-project-onboarding/SKILL.md` |
| REQ | `.cursor/skills/requirements-analysis/SKILL.md` |
| PPT | `.cursor/skills/ppt-deck/SKILL.md` |
| UI suite entry | `.cursor/skills/prd-pack-ingest/SKILL.md` |
| UI worker 2 | `.cursor/skills/visual-choice-first/SKILL.md` |
| UI worker 3 | `.cursor/skills/frontend-design-studio/SKILL.md` |
| ARCH | `.cursor/skills/prd-to-arch-design/SKILL.md` |
| TEST | `.cursor/skills/project-test/SKILL.md` |
| CODE | `.cursor/skills/dev-agent/SKILL.md` |
| DOCS | `.cursor/skills/docs-output/SKILL.md` |

UI is one STAGE suite: activate the three listed workers in order, **one at a
time**, with an explicit handoff between them. `prd-pack-ingest` does not
ambient-load the later workers. ARCH peer, CODE phase/stack, and PPT engine
loading stay inside their root contracts after the role switch.

## New project

1. Agree `<slug>`
2. Run `scripts/new-project.ps1 -Slug <slug>` to copy the template, replace
   project placeholders, exclude installed dependencies, initialize machine
   timestamps, and atomically select the active project. Do not raw-copy the
   template or hand-edit `projects/CURRENT.md`.
3. When a stage first starts, scaffold its sibling root:
   `scripts/scaffold-sibling-stage.ps1 -Slug <slug> -Stage REQ` (then UI/ARCH/CODE).
   Do not hand-copy `vendor-templates/` or write those artifacts into this SOP repo.
4. Enter REQ unless the user named another stage and upstream gates already pass

## Resume

Trust recorded approvals and decisions over chat memory; `state.json` is a
machine-readable cache, not gate authority. If records are missing or conflict,
follow [recovery.md](recovery.md), reconstruct evidence, and reconfirm gates in
conversation.

## Historical project takeover

1. Agree `source_path` + `<slug>` and run
   `scripts/new-project.ps1 -Slug <slug> -Origin historical` (do not copy the
   historical source by default).
2. Load `historical-project-onboarding`.
3. Inventory and read until `INTAKE_COMPLETE`.
4. Use `intake/supplement-plan.md` to switch to owner roles and update canonical
   artifacts with provenance.
5. Enter the user-requested iteration stage only after required backfills/gates.

## More

- [routing.md](routing.md) — intent table and entry gates
- [identity.md](identity.md) — roles and banners
- [impact.md](impact.md) — change / gate / CODE upstream regression
- [pipeline.md](pipeline.md) — state machine
- [tools.md](tools.md) — MCP / CLI / peer skills
- [examples.md](examples.md) — worked utterances
- [governance.md](governance.md) — gates, waivers, lifecycle, change control
- [recovery.md](recovery.md) — mismatch recovery and escalation
