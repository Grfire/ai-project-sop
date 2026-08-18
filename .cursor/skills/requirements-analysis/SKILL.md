---
name: requirements-analysis
description: >-
  Collaborates on product requirements analysis and research, iteratively drafts
  a complete PRD (background, users, features, page/interaction design, data,
  non-functionals, acceptance), and proposes skill method updates after PRD
  finalization. Use when discussing project requirements,需求调研,需求分析, PRD,
  功能设计, 页面设计, or when the user starts a new project in this workspace.
  Only load when sop-orchestrator instructs.
disable-model-invocation: true
---

# Requirements Analysis

## SOP adapter

Loaded only by `sop-orchestrator`. Artifact root: `E:/workspace/ai_req_analysis/projects/<slug>/` (from `scripts/scaffold-sibling-stage.ps1 -Stage REQ`). Do not write PRDs into `ai-project-sop/projects/`. All write paths below use that absolute sibling root, never `projects/<slug>/` inside the SOP repo.

If `E:/workspace/ai-project-sop/projects/<slug>/intake/handoffs/REQ.md`
exists, read it before research. Treat it as sourced historical evidence and
open questions—not as an automatic override of PRD intent. Cite evidence when
proposing supplements.

Project-level workflow for this workspace. Prefer Chinese unless the user writes in another language.

## When active

This section applies **only after** `sop-orchestrator` has routed the current
turn to STAGE REQ and explicitly loaded this skill. The listed signals
(需求、调研、PRD、功能/页面设计、验收标准) inform SOP routing; they do not
auto-activate this skill or compete with the workspace's unique auto-entry.

## Workspace layout

```text
E:/workspace/ai_req_analysis/projects/<project-slug>/
  README.md
  PRD.md                 # main deliverable for tech + UI
  research-notes.md      # living research draft
```

- Create that directory with `scripts/scaffold-sibling-stage.ps1 -Slug <slug> -Stage REQ` when REQ starts.
- `<project-slug>`: short kebab-case Latin or pinyin (e.g. `order-portal`, `huiyuan-zhongxin`).
- Skill files live under `.cursor/skills/requirements-analysis/`.

## Workflow

### 1. Start / resume project

1. Identify or ask for project name → create/open `E:/workspace/ai_req_analysis/projects/<project-slug>/`.
2. Read existing `PRD.md` and `research-notes.md` if present.
3. State current stage: 调研澄清 / 草稿沉淀 / 定稿检查 / 方法沉淀.

### 2. Research (ask, don't assume)

- Prefer **one clarifying question at a time**; multiple-choice when helpful.
- Cover at least: goal & success metrics, users & scenarios, scope in/out, constraints (time/tech/compliance), existing systems, must-have vs later.
- Append findings to `research-notes.md` (dated bullets). Unresolved items go under「待澄清」.

### 3. Draft as you go (边聊边沉淀)

Whenever a chunk of info is stable enough:

1. Update `E:/workspace/ai_req_analysis/projects/<project-slug>/PRD.md` using [prd-template.md](prd-template.md). Keep unknown fields as `待确认：...` (never invent facts).
2. Keep sections filled enough for downstream tech/UI to act; mark gaps explicitly.
3. Tell the user briefly what was updated in PRD (section names only).

Do **not** wait for a full interview before writing the first draft.

### 4. Dimensions to always organize

Map discussion into these PRD dimensions (skip only if truly N/A, and say why):

| Dimension | PRD section |
|-----------|-------------|
| 背景与目标 | 1–2 |
| 用户与场景 | 3 |
| 范围 | 4 |
| 功能设计 | 5 |
| 页面与交互 | 6 |
| 信息架构 / 导航 | 6.1 |
| 数据与规则 | 7 |
| 接口与系统边界 | 8 |
| 非功能 | 9 |
| 验收标准 | 10 |
| 里程碑与开放问题 | 11–12 |

Page design must be concrete enough for UI: page list, key layouts, states (empty/loading/error), main interactions, copy tone notes if given. Feature design must be concrete enough for tech: actors, preconditions, main/alt flows, business rules, permissions.

### 5. Finalize

When the user says 定稿 / 导出 / 可以给下游了:

1. Run the completeness checklist below; fix or flag gaps.
2. Collect compliance fields (classification, regulated data, residency/retention, access/audit, third-party transfer, compliance owner) into the PRD and:

   ```powershell
   .\scripts\write-governance.ps1 -Slug <slug> `
     -DataClassification public|internal|confidential|restricted `
     -RegulatedData <none or categories> `
     -Residency <value> -Retention <value> `
     -AccessAudit <value> -ThirdPartyTransfer <value> `
     -ComplianceOwner <name>
   ```

   Unknown fields block `REQ_SIGNOFF` unless the user explicitly waives a legally permissible item.
3. Set PRD status to `已定稿` and date.
4. Confirm path: `E:/workspace/ai_req_analysis/projects/<project-slug>/PRD.md`.
5. Tell the user downstream UI/原型应把**整个项目目录**交给设计侧；读取方式见设计仓技能 `prd-pack-ingest`（先 README + PRD 骨架 + 页面/功能/验收 + `sample-data/`，再开风格筛选）。设计产物应落在设计仓 `E:/workspace/ai-font-design/projects/<project-slug>/`（与本需求包同名），便于成对引用与迁移。
6. Propose skill method updates (next step)—do not silently edit the skill.
7. After historical supplement edits, run `.\scripts\apply-supplement.ps1` and `validate-supplement.ps1 -TargetStage REQ`. That is provenance evidence, not `REQ_SIGNOFF`.

### 6. Method harvest (after finalization only)

1. Summarize 1–5 reusable improvements (question patterns, section tweaks, anti-patterns).
2. Propose a concrete patch to `SKILL.md` / `prd-template.md` and a changelog entry for [method-changelog.md](method-changelog.md).
3. Apply **only after user confirms**.

## Completeness checklist (定稿前)

- [ ] Goals and success metrics are measurable or explicitly qualitative
- [ ] In-scope / out-of-scope listed
- [ ] Each in-scope feature has actor + flow + rules
- [ ] Each key page has purpose, entry, layout notes, states
- [ ] Permissions and roles covered if multi-role
- [ ] Data entities / key fields listed or marked N/A
- [ ] Acceptance criteria are testable
- [ ] Open questions listed (none silently assumed)
- [ ] Data classification recorded (`public | internal | confidential | restricted`)
- [ ] Regulated-data categories, residency/retention, access/audit, third-party transfer, and named compliance owner recorded or explicitly waived where legally permissible

## Output quality rules

- Write for **downstream tech + UI** as primary readers; avoid vague adjectives without behavior.
- Prefer tables and numbered flows over long prose.
- Distinguish **已确认** vs **待确认** vs **假设** (assumptions need user OK).
- Do not implement product code in this workspace unless the user explicitly asks.

## Mandatory self-check (every assistant turn)

After any requirements discussion turn (including clarifications, PRD patches, or questions), **ask yourself before finishing the reply**:

1. **能否交给研发定稿？** — Yes only if blocking gates are cleared and completeness checklist would pass for the agreed phase.
2. **是否仍存在未消除门禁？** — List remaining blockers that would stop R&D (scope, auth, data source, NFR, acceptance, integration baseline, etc.).

Then **include in the user-facing reply** a short block:

```text
【PRD 定稿自检】
- 能否交研发定稿：否 / 是
- 未消除门禁：（列 1～5 条最关键的，或「无」）
```

Do not claim 定稿 readiness while phase-blocking items remain. Prefer honest「否」over optimistic「是」。

## Additional resources

- PRD template: [prd-template.md](prd-template.md)
- Method changelog: [method-changelog.md](method-changelog.md)

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
