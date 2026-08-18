---
name: frontend-design-studio
description: >-
  本仓库前端页面与 UI 的合成设计技能：品牌站/落地页与产品 UI（SaaS、后台、表单）分流，
  含审美方向、组件惯例、工程 polish 与交付前 critique。栈无关。
  在用户要求构建、改版、打磨、评审 web UI，或明确提及 frontend-design-studio 时使用。
  纯 WebXR/Three.js 运行时任务改用 web-3d-vr-experience；DOM 壳层视觉仍用本技能。
  Only load when sop-orchestrator instructs.
disable-model-invocation: true
---

# Frontend Design Studio

## SOP adapter

Loaded only by `sop-orchestrator` as the final worker in the UI suite. Activate
only after ingest and visual handoffs exist and both prior workers have been
released. Deliver to
`E:/workspace/ai-font-design/projects/<slug>/{design,prototype}/`. Same slug as
the REQ pack. Do not reload prior worker skills; consume their persisted
handoffs/evidence.

本包是本仓库 UI 工作的**默认且优先**技能。同一任务不要并行加载全局 `frontend-design`、taste-skill 等另一套审美系统。

## 何时启用

- 构建/改版：落地页、营销页、仪表盘、设置、表单、导航、组件视觉
- 打磨/评审：polish、audit、critique、去 AI 味
- 用户点名 `frontend-design-studio`

## 与 web-3d-vr-experience 边界

| 任务 | 技能 |
|------|------|
| WebXR / Three.js 场景、立体、输入适配、world JSON | `web-3d-vr-experience` |
| DOM 壳、splash、营销/产品 UI（含画布旁 UI） | **本包** |

## 冲突裁决（必须遵守）

优先级从高到低：

1. 用户 brief 与仓库已有设计系统 / 品牌 token
2. 表面类型（见 `surfaces.md`）：brand 偏表现力；product 偏清晰与组件惯例
3. 分工：`direction.md` 管「像什么」；`craft.md` 管「干净与性能」
4. 动效：brief 未写时 → product 少动；brand 2–3 处有意动效
5. 本包激活时，压过并行的全局审美 skill
6. 任何「行业样式库 / 模板生成」结果必须再跑 direction + critique，不得直接交付

## 统一流程

0. **验证 ingest handoff** — 确认需求包盘点、工作简报、sample-data 与
   页面/验收摘录已持久化；缺失则返回 SOP，不在本 worker 内重载
   `prd-pack-ingest`。
1. **验证视觉 handoff（硬闸）** — 确认已完成：
   - 开场先出 **6 版可点选风格 mockup** 供筛选，禁止纯文字风格菜单
   - 凡要用户对观感做判断/选择，先出画面再问；未选定风格前不写实现
   - 将确认结果及证据持久化为 `design/visual-direction.md`
2. **判定表面**：`brand` | `product` | `mixed`
3. **读** [direction.md](direction.md) — 题材、受众、单一工作、token、签名元素、反默认脸
4. **读** [surfaces.md](surfaces.md) — 按表面执行规则
5. **按需**：
   - 表单/表格/浮层/导航等 → [components.md](components.md)
   - 间距/动效/焦点/密度/状态 → [craft.md](craft.md)
6. **构建 UI 原型** — 使用项目既有技术栈；本技能不指定框架。这里的
   “实现”仅指 UI 阶段 `prototype/`，不授权修改 CODE 工作区的生产应用
7. **交付前** 读 [critique.md](critique.md) 并修好问题
8. **产品可见流程** 须浏览器验收（仅单元测试不算产品验收）
9. **阶段交接** — 完成 `design/design-spec.md`，在对话中取得用户确认后返回
   `sop-orchestrator`。`UI_SIGNOFF` 不能在 `REQ_SIGNOFF` 之前完成。由 SOP
   进入 ARCH；不得直接调用 `writing-plans` 或 CODE

可选外部技能见 [usage-map.md](usage-map.md)。有 PRD 包时，SOP 串行执行
`prd-pack-ingest` → handoff → `visual-choice-first` → handoff → 本包；一次
只激活一个 worker。

## 项目交付目录

产品原型与设计文档写入 `E:/workspace/ai-font-design/projects/<project-slug>/`（`design/` + `prototype/`），与上游 PRD 包同名。详见 `prd-pack-ingest`「设计侧交付落点」。

UI 阶段至少交付 `design/visual-direction.md`、`design/design-spec.md` 和
`prototype/`。门禁由用户在对话中确认，不依赖 Markdown checkbox validator。

## 可选旋钮（1–10，非强制）

陈述设计意图时可写明：

| 旋钮 | Brand 默认 | Product 默认 |
|------|------------|--------------|
| DESIGN_VARIANCE | 6–8 | 3–5 |
| MOTION_INTENSITY | 5–7 | 2–4 |
| VISUAL_DENSITY | 3–5 | 5–8 |

## 实现前最小输出

写代码前，在思考中完成（对用户可简短确认）：

- 表面类型
- 题材 / 受众 / 页面单一工作
- 4–6 色 token（具名 + hex）
- 显示/正文字体角色（具名）
- 一个签名元素
- 三个旋钮取值（若有用）

若计划读起来像「任意同类页面的默认模板」，先改计划再写代码。

## 参考文件索引

| 文件 | 何时读 |
|------|--------|
| [direction.md](direction.md) | 每个 UI 任务 |
| [surfaces.md](surfaces.md) | 每个 UI 任务 |
| [components.md](components.md) | 交互组件、表单、表格、浮层 |
| [craft.md](craft.md) | 打磨、动效、焦点、响应式、状态 |
| [critique.md](critique.md) | 声称完成之前 |
| [usage-map.md](usage-map.md) | 考虑外部技能，或技能冲突时 |
