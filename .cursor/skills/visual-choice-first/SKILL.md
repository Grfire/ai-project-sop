---
name: visual-choice-first
description: >-
  Use when starting UI/design work, picking visual style or layout, or asking the
  user to choose among look-and-feel options. Also use whenever a clarifying
  question is about appearance, skin, composition, or brand feel rather than
  pure scope/tech tradeoffs.
  Only load when sop-orchestrator instructs.
disable-model-invocation: true
---

# Visual Choice First

## SOP adapter

Loaded only by `sop-orchestrator` as the second worker in the UI suite. Start
only after the `prd-pack-ingest` handoff is complete and that worker has been
released. Read the handoff/output, not the ingest skill again. While active, do
not load `frontend-design-studio` or keep another UI worker ambient.

**硬规则：** 凡是要用户对「看起来像什么」做筛选或拍板，必须先给出可点击的视觉稿，禁止只用文字描述选项。

本技能使用 `.cursor/skills/peers/brainstorming/visual-companion.md` 的本地
Companion 契约出画面；它只管视觉选择。完成选择证据后返回 SOP，释放本
worker，再由 SOP 激活 `frontend-design-studio`。若输入是定稿 PRD 包，必须
已有 ingest handoff。

在 SOP 的 UI 上下文中，本技能对视觉时序拥有最高优先级：开场风格筛选必须
**主动、前置**，覆盖 `brainstorming` 的 Visual Companion “just-in-time”
默认。该覆盖只针对外观选择；范围、权限、技术取舍仍按一次一问处理。

## 何时启用

- 新页面 / 新门户 / 新落地 / 大改版的**开场风格筛选**
- 用户要在多种视觉方向、布局、皮肤、组件气质之间做选择
- 设计节确认时问题本质是「好不好看 / 像不像 / 选哪一版」

## 何时仍可用纯文字

- 范围、期别、技术栈、工程路径、权限模型等非外观决策
- 纯架构 / API / 数据模型取舍（可用表格，不必出 mockup）

## 开场：强制 6 版风格

在任何 UI 实现或写死视觉 token **之前**：

1. 启动 Visual Companion（或等价可点选 HTML 预览）。用 **`cursor-ide-browser`** 打开预览页并截图给用户点选；没有 Browser MCP 时改用本地 HTML + `open_resource`。
2. 一次产出 **6 个彼此可区分的风格方向**（编号 R1–R6 或 A–F）。
3. 每个方向必须是**可看见的 mockup**（至少：顶栏/壳、主色、字体气质、一块代表性内容），不是色板名词列表。
4. 简短标注每版意图（一句话）+ 推荐一版及理由；**正文里不要用长文代替画面**。
5. 等用户筛选（可点选）后，再进入细化；未选定风格前不写实现代码。
6. 把选择证据写入
   `E:/workspace/ai-font-design/projects/<slug>/design/visual-direction.md`，使用
   [templates.md](templates.md#visual-directionmd-持久化模板) 中的模板。

六版要拉开差异：色温、对比、密度、衬线/无衬线、机关/企业/编辑/工具感等至少有可感知差别。避免六版都是「同类紫白 / 同类灰底蓝钮」。

## 决策时：先出画面再问选

每当要用户判断或选择时：

| 问题类型 | 交付物 |
|----------|--------|
| 选风格 / 皮肤 | ≥2 张可点选 mockup（开场阶段用 6 版） |
| 选布局 / 信息架构外观 | 并排或分页 mockup，标出差异 |
| 确认某一设计节「像不像」 | 该节的高保真示意 HTML，可点「通过 / 调整」 |
| 迭代微调 | 新旧对照（split 或前后两卡），勿只改文字说明 |

流程：

1. 写出 HTML 画面（Companion `cards` / `mockup` / `split`）。
2. 对话里只给：URL + 一句「屏幕上是什么」+ 请选择。
3. 读用户回复与 companion `events`，再进入下一问。
4. 每次重新选择或最终确认后更新 `visual-direction.md`；聊天确认是门禁事实，
   Markdown checkbox 只作记录，不是 validator。
5. **禁止**：先甩一长段 A/B/C 文字选项，让用户脑补视觉效果。

## 与 Visual Companion 的关系

- 仍遵守「一次一问」。
- 覆盖默认：本仓库 / 用户偏好下，**外观类问题默认走视觉稿**，不要等用户催「做个预览」。
- SOP UI 开场不等待 just-in-time 提议：**主动开 Companion 并推 6 版**。
- 后续非开场视觉问题可按需使用 Companion；非视觉问题保持文字沟通。

## 持久化契约

`design/visual-direction.md` 至少记录：

- 稳定的 choice ID（例如 `R3`）与方向名称
- preview URL、本地预览路径、截图路径或其他可复核链接
- `selected_at`、`confirmed_at`（ISO 8601；未确认时为 `pending`）
- 用户确认的原话或忠实短摘录，以及确认所在对话
- 被淘汰方向和后续调整，确保 ARCH 能追溯视觉决策

选择与确认必须发生在对话中。文件持久化证据，不通过勾选框自行放行。

## 常见踩坑

| 错误 | 改正 |
|------|------|
| 「方案 A 偏红、方案 B 偏蓝」纯文字 | 做成两块带红/蓝顶栏的真实壳 mockup |
| 六版只有标题不同 | 拉开色板、字体、密度、签名元素 |
| 未选风格就开始写页面 | 硬闸：先筛选再实现 |
| 用 GenerateImage 代替可点选对比 | 优先 HTML Companion（可点选、可迭代）；图仅作补充 |

## 落地检查

交付或进入下一设计节前自问：

- [ ] 开场是否已出过 6 版可视风格并完成筛选？
- [ ] `design/visual-direction.md` 是否包含 choice ID、证据链接和时间？
- [ ] 用户是否已在对话中明确确认？
- [ ] 本次选择问题是否附带可看见的稿，而非纯文字？
- [ ] 对话正文是否短，画面是否在 Companion / 预览里？

## 参考

- Companion 写法：`.cursor/skills/peers/brainstorming/visual-companion.md`
- 后续风格质量与禁默认脸：`.cursor/skills/frontend-design-studio/direction.md`
- 片段模板：[templates.md](templates.md)
