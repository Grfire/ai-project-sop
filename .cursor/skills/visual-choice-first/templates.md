# Visual Choice HTML 片段模板

写入 `.cursor/skills/peers/brainstorming/visual-companion.md` 所定义
companion 的 `content/`（内容片段，勿包整页 html）。类名依赖 companion
框架。

## 开场 6 版风格卡

```html
<h2>视觉风格筛选（6 版）</h2>
<p class="subtitle">点选你倾向的方向；可先粗筛，再细调。</p>

<div class="cards">
  <div class="card" data-choice="r1" onclick="toggleSelect(this)">
    <div class="card-image">
      <!-- 迷你壳：顶栏 + 侧栏 + 一块内容，体现该方向 token -->
      <div style="font-family:…;background:…;border:1px solid …;height:180px;…">…</div>
    </div>
    <div class="card-body">
      <h3>R1 · 名称</h3>
      <p>一句话意图</p>
    </div>
  </div>
  <!-- R2–R6 同构，视觉必须可区分 -->
</div>
```

要求：每个 `card-image` 内是可辨认的界面缩略，不是纯色块 + 文字标签。

## visual-direction.md 持久化模板

保存到
`E:/workspace/ai-font-design/projects/<slug>/design/visual-direction.md`：

```markdown
# Visual Direction: <project-slug>

## Decision
- choice_id: R3
- name: <方向名称>
- status: selected | confirmed | superseded
- selected_at: <ISO-8601>
- confirmed_at: <ISO-8601 | pending>
- confirmed_in: <对话/会话标识或“current conversation”>
- user_confirmation: "<用户确认原话或忠实短摘录>"

## Evidence
- preview_url: <URL | N/A>
- preview_path: <相对或绝对路径 | N/A>
- screenshots:
  - <截图路径或链接>
- other_links:
  - <Figma/参考链接等>

## Direction
- surface: brand | product | mixed
- palette:
- typography:
- density:
- signature_element:
- motion:

## Alternatives considered
| Choice ID | Name | Outcome | Reason |
|-----------|------|---------|--------|
| R1 | | rejected | |

## Adjustments after selection
- <timestamp>: <调整及其确认依据>
```

`selected_at` 记录首次选择，`confirmed_at` 只在用户于对话中明确确认后填写。
重新选择时保留历史，把旧方向标为 `superseded`，不要覆盖证据。

## 二选一 / 三选一布局对照

```html
<h2>布局选择</h2>
<p class="subtitle">看层级与扫读，不只看文案。</p>
<div class="split">
  <div class="mockup" data-choice="a" onclick="toggleSelect(this)">
    <div class="mockup-header">A · …</div>
    <div class="mockup-body">…</div>
  </div>
  <div class="mockup" data-choice="b" onclick="toggleSelect(this)">
    <div class="mockup-header">B · …</div>
    <div class="mockup-body">…</div>
  </div>
</div>
```

## 设计节确认

```html
<h2>第 N 节 · …</h2>
<p class="subtitle">像不像目标气质？点选或在对话里说改哪。</p>
<div class="mockup">
  <div class="mockup-header">预览</div>
  <div class="mockup-body">…高保真示意…</div>
</div>
<div class="options">
  <div class="option" data-choice="ok" onclick="toggleSelect(this)">
    <div class="letter">✓</div>
    <div class="content"><h3>通过</h3><p>进入下一节</p></div>
  </div>
  <div class="option" data-choice="tweak" onclick="toggleSelect(this)">
    <div class="letter">↻</div>
    <div class="content"><h3>要调整</h3><p>我说明改点</p></div>
  </div>
</div>
```
