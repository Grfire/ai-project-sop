# 使用地图

## 默认

本仓库的前端 UI 任务属于一个 UI suite。由 SOP 按
`prd-pack-ingest` → `visual-choice-first` → `frontend-design-studio`
串行激活，一次一个 worker；不要并行或 ambient-load 多套审美 skill。

## 本包 vs 外部

| 场景 | 行动 |
|------|------|
| 用户丢来 PRD 目录 / 定稿需求包 | SOP **必须先**激活 `prd-pack-ingest`，完成 handoff 并释放后再进入视觉 |
| 开场选风格、布局观感、设计节「像不像」 | SOP 单独激活 `visual-choice-first`（6 版开场 / 决策出画面）；完成 handoff 后释放，再进入 studio |
| 日常构建/改版/打磨 UI | 本包 + 需要选择时走视觉稿 |
| ARCH 方案讨论需要选项/剖面 | SOP 加载 `.cursor/skills/peers/brainstorming`（禁止当 CODE 开工闸） |
| 需要确定性 CSS/DOM lint 或浏览器 live 设计循环 | 可选 [Impeccable](https://github.com/pbakaus/impeccable)；先跑本包 `critique.md` |
| 需要完整 60+ 组件百科 | 可选 [ui-design-brain](https://github.com/carmahhawwari/ui-design-brain)；多数情况本包 `components.md` 足够 |
| 要按行业快速脚手架落地页 | 可选 [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) → **必须**再跑 `direction.md` + `critique.md` 去模板味 |
| 全局已装 frontend-design / taste-skill | 本仓库任务以本包为准；同一任务不要双开 |
| 用户研究、旅程图、设计领导力 | 超出范围；仅当用户明确要求时考虑 designer-skills |
| Claude Code 模板市场 | 与设计质量无关；忽略 |

## 冲突速查

| 冲突 | 裁决 |
|------|------|
| 本包 vs 全局 frontend-design / taste | **本包** |
| direction（更大胆）vs craft（更克制） | 先满足 brief 与表面类型；其次 direction 定调，craft 约束性能与可访问性 |
| 模板生成器输出 vs 独特方向 | 模板只作草稿；direction + critique 为终态 |
| 本包 vs web-3d-vr-experience | 运行时 3D/XR → VR skill；DOM/视觉 UI → 本包 |

## 不推荐整包装入本仓库的原因

- **taste-skill**：与本包 direction 重叠，易双规
- **ui-ux-pro-max**：样式库匹配与「为 brief 做独特选择」冲突；仅脚手架出口
- **designer-skills / claude-code-templates**：目标域不同
