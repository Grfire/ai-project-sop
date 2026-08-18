---
name: prd-pack-ingest
description: >-
  Use when the user points to a PRD path or project folder, hands over 定稿需求 /
  sample-data, or asks to design, prototype, or implement UI from a requirements
  pack (especially under ai_req_analysis/projects/). Do not use for writing or
  revising the PRD itself—that is requirements-analysis.
  Only load when sop-orchestrator instructs.
disable-model-invocation: true
---

# PRD Pack Ingest（下游读需求）

## SOP adapter

Loaded only by `sop-orchestrator` as the UI suite entry worker. Read PRD packs
from resolved `state.paths.req`. Write the UI ingest brief to resolved
`state.paths.ui`. While this worker is active,
do not read or activate `visual-choice-first`, `frontend-design-studio`, or a
companion skill. Return an explicit ingest handoff to SOP first.

For historical projects, first read
`project://intake/handoffs/UI.md`. Use it to
inventory existing screens/routes/assets and gaps; the finalized PRD still wins
product acceptance.

**原则：** 用户后续会持续投喂**同类定稿需求包**（目录，不单是一篇聊天摘要）。先按包结构读全再设计；禁止只读标题或凭对话臆造范围。

上游写 PRD：本仓 `.cursor/skills/requirements-analysis/SKILL.md`，产物位于
`state.paths.req`。
本技能只管**读定稿包 → 抽出设计/原型工作简报 → 返回 SOP handoff**；不得
ambient-load 后续 UI worker。

## 何时启用

- 用户给出 `…/projects/<slug>/` 或 `…/PRD.md` 路径
- 「按这份 PRD 做前端 / 原型 / 全站页面」
- 附带 `sample-data/`、roadmap、参考工程路径

## 预期包结构（宽容匹配）

以目录为输入单元。常见布局（可有缺项，缺则标明）：

```text
<project>/
  README.md                 # 入口：状态、主交付、参考路径
  PRD.md                    # 定稿主文档（必读）
  roadmap.md                # 分期（若有）
  research-notes.md         # 仅补背景；冲突以 PRD 为准
  feature-mapping*.md       # 功能映射（若有）
  sample-data/              # 演示/验收样例（Mock 语义对齐）
    README.md
    ACCEPTANCE-CHECKLIST.md
    phaseN/ …
    accounts/ …
  projects/_template/       # 仅作结构对照，不是业务源
```

参考实现常写在 README/PRD「参考项目」：路径外置、**范式复用、不迁仓**。

## 读取顺序（必须按序）

在问范围/风格/写代码之前完成：

1. **盘点目录** — `Glob` 全包；记下有无 `sample-data`、roadmap、参考路径。
2. **读 README** — 状态是否「已定稿」、主交付路径、下游以谁为准。
3. **读 PRD 元信息** — 状态/版本/定稿日/下游读者；若仍是「草稿」，先对齐用户是否仍要当定稿用。
4. **扫 PRD 骨架** — 用标题/`^## ` 建目录，不要线性通读千行后再动手。
5. **按设计相关章节精读**（可并行多段 Read）：
   - §用户与场景、角色与权限
   - §范围（In/Out、分期）
   - §功能清单（F-xx）与关键功能细则
   - §页面与交互 / 信息架构（P-xx）
   - §验收（AC-xx）与成功标准
   - 品牌/底座/禁用文案等硬约束（全文检索关键词）
6. **读 sample-data/README + manifest/清单** — 弄清期别数据包与验收勾选；需要字段时再下钻 YAML/语料，勿一上来通读所有 md。
7. **读 roadmap（若有）** — 与 PRD 分期交叉校验。
8. **记下参考工程路径** — 业务模块对齐时再打开；默认不整仓复制。

`research-notes.md`：只在 PRD 含糊时查阅；**不得覆盖已定稿 PRD**。

If `REQ_SIGNOFF` is not approved, continue only with a recorded REQ draft
waiver. Prototype work in that mode is provisional: do not present
`UI_SIGNOFF` until `REQ_SIGNOFF` is approved and the 定稿 PRD is re-read.

## 读完后的工作简报（对用户短述）

用短段落或表交代（勿贴长文复述 PRD）：

| 项 | 内容 |
|----|------|
| 产品表面 | brand / product / mixed（门户后台多为 product） |
| 分期与页面规模 | 期别 + P-xx 数量级 |
| 角色与权限 | 影响导航显隐 |
| In / Out | 原型是否包含 API/真模型等 |
| 硬约束 | 如禁用某品牌名、必须自有 UI、双模只做门户等 |
| 样例数据 | 有哪些 phase；Mock 对齐策略 |
| 参考范式 | 外置 demo 路径（若有） |
| 开放问题 | PRD 仍标「待确认」且挡设计的项 |

然后把范围歧义写入 handoff；需要继续时返回 `sop-orchestrator`。SOP 释放
本 worker 后，才可显式读取 `visual-choice-first` 处理外观问题。

## Mock 与验收对齐

- 原型/演示数据语义对齐 `sample-data/`（实体名、期别、题库口径、账号），不编造与包冲突的领域词。
- 验收话术对齐 AC / ACCEPTANCE-CHECKLIST；原型阶段可标注「演示闭环 / 非真模型」。
- 字段级细节：用到哪页再读对应 yaml/html，避免一次性吞全包。

## 硬约束提取

全文检索并写入规格（示例关键词，按项目增减）：

- 品牌/底座名、禁用展示名
- 「不以第三方原生 UI 为主路径」
- 角色档位、推送可关闭、导出格式等

UI 文案遵守 PRD 硬约束；内部实现名可与展示名分离。

## 与后续技能的衔接

```text
prd-pack-ingest（本技能）
  → 返回 SOP（释放 ingest，记录 handoff）
  → visual-choice-first（唯一 active worker；开场 6 版风格）
  → 返回 SOP（释放 visual，记录选择证据）
  → frontend-design-studio（唯一 active worker；原型与 design-spec）
  → 返回 sop-orchestrator，由 SOP 分诊并进入 ARCH
```

这是一个 UI STAGE suite，不是三个并行 stage。任一时刻只能激活一个 worker；
不得提前读取后续 worker，也不得把 `brainstorming` 当成常驻 worker。

UI 阶段的终点是已确认的 `design/design-spec.md` 与 `prototype/`。本技能不得
调用 `writing-plans`、实现型 CODE 技能，或把视觉确认直接解释为生产实现授权。
用户在对话中确认 UI 结果后，返回 SOP；由 SOP 检查 ARCH 入口门禁并切换角色。

## 设计侧交付落点（本仓硬约定）

在 `ai-font-design`（或同类设计仓）产出时，**项目文档与设计结果一律进**：

```text
state.paths.ui/
  README.md                 # 引用入口（上游 PRD 路径、如何启动）
  design/                   # visual-direction.md、design-spec.md、说明稿
  prototype/                # 可运行前端（勿再默认写到 apps/）
```

- `<project-slug>`：**与上游需求包目录同名**（如 `military-training-ai-ecosystem`），便于成对引用/迁移。
- 视觉选择与规格写进 `design/`，不要默认写入 `docs/superpowers/specs/`。
- 迁移：整夹复制 `projects/<project-slug>/`；README 写清上游 PRD / sample-data 路径。

**禁止：** 未完成包盘点与工作简报就开始写页面代码。  
**禁止：** 用聊天里的口头范围覆盖定稿 PRD（除非用户明示改需求）。

## 常见踩坑

| 错误 | 改正 |
|------|------|
| 只打开 PRD.md 前两章就开做 | 先扫全目录 + 页面/功能/验收章节 |
| 忽略 sample-data | Mock 与演示口径从包来 |
| 把参考仓整棵拷进原型 | 只对齐流程/信息架构范式 |
| 把 research-notes 当真理 | 定稿后以 PRD 为准 |
| 长文复述 PRD 给用户 | 只给工作简报 + 一个澄清问题 |

## 落地检查

- [ ] 已 Glob 包结构并知道缺什么
- [ ] 已确认定稿状态与 In/Out、分期、角色
- [ ] 已列出 P-xx / 关键 F-xx 与硬约束
- [ ] 已知道 sample-data 如何支撑 Mock/验收
- [ ] 已输出短工作简报并进入一次一问 / 视觉筛选

## 参考

- 包内模板：`ai_req_analysis/projects/_template/`
- 上游写法：`.cursor/skills/requirements-analysis/SKILL.md`
- 章节速查：[section-map.md](section-map.md)

## Historical supplement closeout

When applying an intake SUP item to a canonical artifact:

1. Edit the canonical file at this stage's sibling root (never the SOP intake copy).
2. Add a `BACKFILL-<STAGE>-<nnn>` row to `project://intake/evidence-map.md` citing intake evidence and the canonical path.
3. Run:

```powershell
.\scripts\apply-supplement.ps1 -Slug <slug> -SupplementId SUP-... `
  -CanonicalTarget <absolute-or-relative-path> -BackfillId BACKFILL-... `
  -AppliedBy "<identity from chat>" -TargetStage <STAGE>
```

4. Keep the `validate-supplement.ps1` report as provenance evidence.
5. Do not treat applied/waived as a human gate. Stage sign-off remains conversational.
