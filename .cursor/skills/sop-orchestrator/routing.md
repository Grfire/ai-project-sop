# Intent routing

Read this after identifying the user utterance. Pick **one** primary STAGE
suite. Load its entry/root `SKILL.md` via Read. Do not ambient-load another
stage or suite worker; internal workers are read only when the active suite
contract explicitly advances to them.

## Signal → STAGE

| User signals (examples) | STAGE | Role | Load |
|-------------------------|-------|------|------|
| 历史项目、老项目、已有项目接管/迁入/继续迭代、把这个目录纳入 SOP | INTAKE | 项目接管分析师 | `historical-project-onboarding` |
| 新项目、需求、调研、PRD、功能/页面设计、验收、定稿、范围 | REQ | 需求分析师 | `requirements-analysis` |
| **明确动作**：制作/生成/修改/重做/导出 PPT、幻灯片、路演 deck、汇报稿 | PPT | PPT策划 | `ppt-deck` |
| 原型、UI、视觉、风格、页面实现、按 PRD 做前端 | UI | 原型设计师 | UI suite entry `prd-pack-ingest`; then SOP serially activates visual → studio |
| 技术方案、架构、详细设计、coding handoff、grill 方案 | ARCH | 架构师 | `prd-to-arch-design` |
| 封装测试、用例、Playwright、回归脚本、产品测试 | TEST | 测试架构师 | `project-test` |
| 开发、实现、改代码、修 bug、Docker、access_url、联调 | CODE | 研发工程师 | `dev-agent` |
| 文档、手册、说明书、部署文档、测试报告、统一风格 | DOCS | 文档专员 | `docs-output` |
| 门禁、能否定稿、卡在哪、谁来解决、目标有没有对齐 | SOP | 编排官 | this file + `impact.md` + `governance.md` |
| 修改、变更、回退、和需求不一致、要不要改方案 | SOP then owner | 编排官 → owner | `impact.md` first |

Ambiguous → 编排官 asks **one** clarifying question (stage choices), then route.

## PPT explicit-intent gate

PPT is **never inferred from artifacts or context**. Enter PPT only when the
current user message explicitly asks to create, edit, regenerate, beautify,
convert, export, or review a presentation/deck.

These do **not** trigger PPT:

- an imported historical project contains `.ppt` / `.pptx`
- a PRD/README mentions a presentation
- intake needs to extract text from existing slides
- a slide deck is cited as evidence for requirements or architecture

Those cases stay in the current stage. Existing slides may be read as evidence
without loading `ppt-deck` or `ppt-studio`.

## Default happy path

```text
New project: REQ 定稿
  → PPT（仅用户明确提出制作/修改/评审时；可与 UI 并行）
  → UI suite（prd-pack-ingest → handoff → visual-choice-first → handoff → frontend-design-studio；一次一个 worker）
  → ARCH（A ingest → A2 fusion → B draft → G grill → C package）
  → TEST/package（产出 TEST_PACK：用例+脚本）
  → CODE（dev-agent：ingest → implement ⇄ verify → review → handoff）
  → 每次代码更新：TEST/regression 全量（脚本提供证据；聊天确认门禁）
  → DOCS 随过程文档刷新

Historical project:
INTAKE（全量台账 + 证据 + 分阶段补充包）
  → owner-controlled REQ/UI/ARCH/TEST/CODE/DOCS backfill
  → requested iteration stage
```

Skip a stage only through an explicit conversational waiver recorded in
`DECISIONS.md` and `APPROVALS.md`. `state.json` may mirror `na`; it is not the
authority.

## Stage entry gates

| Enter | Required |
|-------|----------|
| INTAKE | User provides/identifies a historical source root + slug |
| Exit INTAKE | explicit user approval of `INTAKE_COMPLETE` after evidence is shown; unlocks owner backfill |
| Named iteration after INTAKE | related SUP items `applied`/`waived` (`validate-supplement.ps1 -TargetStage`) as evidence, then that stage's own gate |
| PPT | Current user message has explicit PPT production/edit/review intent |
| UI | `REQ_SIGNOFF` approved, or an explicit bounded REQ draft waiver recorded in conversation. `UI_SIGNOFF` still requires `REQ_SIGNOFF`. |
| ARCH | `REQ_SIGNOFF`; `ui_input_mode=complete|partial|none`; partial/none requires waiver before `ARCH_SIGNOFF` |
| TEST packaging | `ARCH_SIGNOFF` approved; produces TEST_PACK |
| CODE | `TEST_PACK_READY` approved |
| TEST regression | `CODE_READY`, runtime-affecting CODE change, or user asks 回归 |
| DOCS | At least one upstream process doc exists |

Gate completion always uses the conversational protocol in `governance.md`.
File existence and test output are evidence only. Never infer approval from
Markdown checkboxes or machine state.

## Load budget

| Layer | Budget |
|-------|--------|
| SOP | this skill always |
| Stage | **one primary STAGE suite**; read its entry/root skill |
| CODE internals | `dev-agent` rule: ≤1 phase + ≤2 stacks |
| UI internals | ingest → visual gate → studio; exactly one active worker, no ambient/global taste load |
| ARCH internals | root router phase allowlist; normally ≤2 peers per phase, grill pair counts as 2 |
| PPT | `ppt-studio` then **one** render engine |

## Direct-to-CODE requests

If the user talks to 研发工程师 while skipping triage:

1. 编排官 分诊 (`impact.md`)
2. If impact hits REQ/ARCH/UI → **do not code yet**; switch to that owner, or ask to confirm skip
3. If impact is code-local → switch to 研发工程师, then after the change run REGRESSION
