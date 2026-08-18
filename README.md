# AI 项目落地 SOP 智能体

在**一个 Cursor 工作区**里串起：历史项目接管 / 需求 → 原型 → 技术方案 → 测试封装 → 代码 → 全量回归 → 文档。PPT 是显式请求才进入的可选支线。

过程产物统一落在 Bundle 内 `workspaces/`（同名 `<slug>`）。路径由
`sop.yaml` 与项目 `state.json` 的 portable URI 决定。

## 怎么用

1. clone 后在 Windows 运行 `.\scripts\bootstrap-tools.ps1`，macOS 运行
   `./bootstrap.command`
2. 用 Cursor 打开仓库根目录
3. 直接说目标即可；Agent 会：**识别意图 → 切换角色 → 调用对应 Skill → 该回归就回归**

首次请给出或确认 `slug`（kebab-case）。新项目用
`.\scripts\new-project.ps1 -Slug <slug>` 初始化；历史项目加
`-Origin historical`。已有项目用
`.\scripts\set-active-slug.ps1 -Slug <slug>` 原子切换，用
`.\scripts\list-projects.ps1` 查看组合。写入前会核对用户、路径、
`CURRENT.md` 和 `state.json` 的 slug；冲突时停止写入并请用户确认。

## 角色与阶段

| 角色 | 阶段 | 技能 | 产物位置 |
|------|------|------|----------|
| 项目接管分析师 | INTAKE | `historical-project-onboarding` | `project://intake` |
| 需求分析师 | REQ | `requirements-analysis` | `state.paths.req` |
| PPT策划 | PPT | `ppt-deck` → `ppt-studio`（明确意图才触发） | `state.paths.ppt_path` |
| 原型设计师 | UI | ingest → visual-choice-first → frontend-design-studio | `state.paths.ui` |
| 架构师 | ARCH | `prd-to-arch-design` | `state.paths.arch` |
| 测试架构师 | TEST | `project-test` | `project://test` |
| 研发工程师 | CODE | `dev-agent` | `state.paths.code` |
| 文档专员 | DOCS | `docs-output` | `project://docs` |

## 你要的五条能力

1. **意图 + 身份**：always-on 规则 + `sop-orchestrator`；阶段技能禁止抢触发。
2. **修改 / 门禁 / 目标**：先 `【分诊】`，再交给主责角色（见 `impact.md`）。
3. **CODE 改完要回写**：行为/验收变了 → REQ；接口/缝变了 → ARCH；然后 TEST 全量回归。
4. **ARCH 定稿后封装测试**：代码测试 + Playwright 产品测试；之后回归只跑脚本、读 `last-run.json`，省 Token。
5. **文档**：按类型沉淀 `style-card`，同类风格对齐，正文跟过程文档刷新。

## 默认顺序

```text
新项目：REQ 定稿 → UI → ARCH（grill 后落盘）
  → TEST（产出 TEST_PACK）→ CODE ⇄ TEST/REGRESSION → DOCS（结束）

历史项目：INTAKE（完整阅读台账 + 证据 + 分阶段补充包）
  → REQ/UI/ARCH/TEST/CODE/DOCS 按缺口补齐 → 后续迭代

PPT：仅在用户明确要求制作/修改/导出/评审 PPT 时进入，可并行；
项目中已有 PPT 文件或文档提到 PPT 不会触发。
```

当前交付生命周期明确结束于 **DOCS**。RELEASE、OPS、maintenance 及其角色
属于延后范围，当前不会加入流程。

## 人工门禁

门禁必须在聊天中完成：编排官展示编号证据项，用户明确确认对应门禁 ID，
再写入 `APPROVALS.md`、`DECISIONS.md`（如有决策/waiver）与 `SOP.md` 日志。
文件存在、测试通过、时间戳新鲜度和 `state.json` 只提供证据，不会自动过闸；
系统不会解析 Markdown checkbox。

固定门禁为：

`INTAKE_COMPLETE` → `REQ_SIGNOFF` → `UI_SIGNOFF` →
`ARCH_SIGNOFF` → `TEST_PACK_READY` → `CODE_READY` →
`REGRESSION_PASS` → `DOCS_COMPLETE`

UI 不完整时 ARCH 可使用 `ui_input_mode=partial|none`，但必须展示缺失证据、
风险和补偿措施，并在 `ARCH_SIGNOFF` 前记录用户明确批准的 waiver。

项目治理文件：

- `SOP.md`：可读阶段摘要与日志
- `APPROVALS.md`：追加式显式确认记录
- `DECISIONS.md`：变更、回滚、waiver、生命周期与合规决策
- `state.json`：机器索引/会话状态；不是人工门禁权威

## 历史项目接管

直接提供历史项目路径和期望的 `slug`。系统会：

1. 全量盘点（生成物/依赖目录按理由排除，敏感文件不读取）
2. 为每个有效文件记录 `read / extracted-read / indexed / skipped / unsupported`
3. 产出现状、证据映射、环节缺口和补充计划
4. 生成 REQ / UI / ARCH / TEST / CODE / DOCS 六类 handoff
5. 由各主责智能体将确认后的补充写入自己的标准产物

`reading-ledger.csv` 中无有效文件 `pending` 是 `INTAKE_COMPLETE` 的机器
证据之一；编排官仍需在聊天中展示全部证据并取得用户明确确认。

盘点命令：

```powershell
.\scripts\new-project.ps1 -Slug "project-slug" -Origin historical
.\scripts\inventory-historical-project.ps1 `
  -SourcePath "E:\path\to\historical-project" `
  -Slug "project-slug"
```

## 工具（全环节）

首次：

```powershell
.\scripts\bootstrap-tools.ps1
```

默认使用 PyPI、npm 与 Playwright 官方源；国内网络可设置
`SOP_PIP_INDEX` / `SOP_NPM_REGISTRY` / `SOP_PLAYWRIGHT_DOWNLOAD_HOST`
环境变量覆盖。Python >=3.10、Node/npm/npx 为必需；Playwright 会检测，
Docker 与全局 PPT skill 为可选。

| 环节 | 工具 |
|------|------|
| UI 视觉 / 原型验收 | Cursor 内置 Browser MCP：`cursor-ide-browser` |
| 产品测试 | 项目 MCP `playwright`（`.cursor/mcp.json`）+ 回归脚本 |
| 技术方案 grill / 方案包 | `.cursor/skills/peers/`（grilling、brainstorming、to-spec…） |
| PPT | `ppt-deck` → `~\.agents\skills\ppt-studio`（唯一渲染引擎 + 其 Python 脚本） |
| 代码 | Docker CLI + TDD peer；冒烟可用 Browser |
| 文档 DOCX | `python scripts/md-to-docx.py`（`python-docx`） |

若聊天里看不到 Browser / Playwright 工具：在 Cursor **Customize → MCP** 打开对应开关（Browser 是内置，不要写进 mcp.json）。

地图：`.cursor/skills/sop-orchestrator/tools.md`。

## 回归命令

```powershell
.\scripts\run-full-regression.ps1 -Slug <slug>
```

前提：`projects/<slug>/test/runtime.ps1` 已填 `CodeRoot` / `AccessUrl` / `CodeTestCmd`。

REGRESSION 是 TEST 的运行模式，不是独立阶段。脚本结果会在聊天中作为
`REGRESSION_PASS` 证据展示，仍需用户明确确认。

## 治理与路径工具

```powershell
.\scripts\new-project.ps1 -Slug <slug>
.\scripts\list-projects.ps1
.\scripts\set-active-slug.ps1 -Slug <slug>
.\scripts\validate-sibling-paths.ps1 -Slug <slug>
.\scripts\scaffold-sibling-stage.ps1 -Slug <slug> -Stage REQ
.\scripts\tests\run-sop-validation.ps1
.\scripts\register-sop-validation-task.ps1 -PrintDefinition
```

统一验证会运行 docs、governance、intake、regression、scaffold 与
static-contract 六套 smoke。static-contract 额外检查所有 `SKILL.md`
frontmatter、唯一 auto-entry、`disable-model-invocation`、本地 Markdown
链接和项目 hook 目标；CI 使用同一入口。

项目 lifecycle 为 `active | paused | cancelled | archived`，仅用于组合管理，
不是新的交付阶段。数据分类、受监管数据、驻留/保留、访问审计、第三方传输
和合规负责人必须在需求签署前记录。重复盘点、提取、比较和测试采用
“脚本优先、聊天摘要”以控制成本/Token，但人工门禁仍在对话中确认。

## 移植说明

Skills 从下列仓库拷入 `.cursor/skills/`，并加上 SOP adapter：

- `ai_req_analysis` → `requirements-analysis`
- `ai-font-design` → `prd-pack-ingest`, `visual-choice-first`, `frontend-design-studio`, `web-3d-vr-experience`
- `ai_architecture_design` → `prd-to-arch-design`
- `ai_code` → `dev-agent` + `phases/` + `stacks/`
- PPT 无仓内技能，用薄封装 `ppt-deck` 调用全局 `ppt-studio`

TEST 与 DOCS 是本仓库新建阶段。

## 从旧 sibling 工作区迁移

迁移默认不写入。先审查计划，再显式执行：

```text
python -m sop --root . migrate plan <slug>
python -m sop --root . migrate apply <slug>
python -m sop --root . migrate apply <slug> --execute
```

旧位置映射仅保存在 `sop.yaml migration.legacy_sources`。迁移排除 VCS、
依赖、缓存与潜在 secret，先在各目标同卷 staging，校验 portable state
和关键引用后再原子改名；已有目标不会被覆盖。非标准旧根可加
`--legacy-root <path>`。

macOS 的 Cursor PATH、MCP 和完整验证说明见
[docs/mac-cursor.md](docs/mac-cursor.md)；架构取舍见
[ADR-0004](docs/adr/0004-portable-bundle-and-python-core.md)。

---

## 完整运行原理

本项目不是把多个 Skills 同时放进上下文，而是一个**受治理、分层加载的多智能体编排系统**：

```text
Cursor sessionStart
  → 注入 Bundle / active slug / lifecycle / stage
  → sop-orchestrator 识别意图
  → 核对 user / path / CURRENT / state 四路 slug
  → 影响分诊
  → 切换一个主角色与一个主 STAGE suite
  → 阶段 root Skill 按 allowlist 激活少量内部能力
  → 写入 canonical artifact
  → 脚本生成机器证据
  → 用户在会话中明确确认门禁
  → 记录 APPROVALS / DECISIONS / SOP，并镜像 state
```

每条用户消息按以下顺序运行：

1. `.cursor/hooks/session-start.mjs` 寻找 Bundle Python，调用
   `python -m sop --root . session context`，向 Cursor 注入当前项目上下文。
   Python 不可用时也会返回合法的 warning JSON，不会伪造项目状态。
2. `.cursor/rules/sop-orchestrator.mdc` 与
   `.cursor/skills/sop-orchestrator/SKILL.md` 识别当前意图。
3. 历史项目先进入 INTAKE；PPT 只有当前消息明确要求制作、修改、导出或评审时才进入。
4. 写入前比较用户 slug、目标路径 slug、`projects/CURRENT.md` 和
   `state.json.slug`；非空值不一致时 fail closed。
5. 修改、门禁、目标、失败或直接改代码先读 `impact.md`，确定主责阶段、
   上游回写范围和下游门禁 reset。
6. 根据 `identity.md` 切换角色并打印 banner；每轮只选择一个主 STAGE suite。
7. 读取该阶段 root `SKILL.md`。内部 worker、peer、phase 和 stack 只有在
   root Skill 明确允许时才继续加载。
8. 重复性盘点、提取、校验和测试交给脚本；聊天只展示关键证据，减少 Token。
9. 人工门禁必须由用户在对话中明确确认。脚本、文件、测试和 schema 不会自动批准。
10. 运行时代码变更先失效 `CODE_READY`、`REGRESSION_PASS` 和
    `DOCS_COMPLETE`，再更新时间戳并执行 full regression。

### 权威层级

- **产品 SSOT**：REQ 的 `PRD.md`
- **技术 SSOT**：ARCH 的 design-pack 与 `design/CODING_HANDOFF.md`
- **交互 SSOT**：UI 的 `design/design-spec.md` 与 `prototype/`
- **测试证据**：`test/catalog.yaml`、`test/last-run.json`
- **人工授权轨迹**：`APPROVALS.md`、`DECISIONS.md`、`SOP.md`
- **机器缓存**：`state.json`

聊天不能静默覆盖 PRD 或 ARCH design-pack；`state.json` 也不能替代人工授权轨迹。

## 使用范围与边界

### 适合

- 新 AI/软件项目从需求分析到文档交付的完整流程
- 历史项目接管、全量阅读、证据盘点和分阶段补档
- 已有项目需求、UI、架构、测试、代码和文档迭代
- 直接代码修改后的上游影响分析、门禁失效和全量回归
- Playwright 产品测试、代码测试、Docker 运行验证
- 按文档类型学习并复用 style-card
- 用户明确要求时制作、修改、导出或评审 PPT

### 当前不包含

- Cursor 之外的 agent harness 适配
- RELEASE、OPS、maintenance 阶段及角色
- 自动通过人工门禁
- 通过 Markdown checkbox、文件存在或测试成功推断用户批准
- 从历史项目中的 `.ppt/.pptx` 文件自动触发 PPT 制作

## Bundle 与文件地图

### 仓库控制面

| 路径 | 作用 |
|------|------|
| `AGENTS.md` | Workspace always-on 总规则：入口、阶段预算、门禁、路径和生命周期 |
| `.cursor/rules/sop-orchestrator.mdc` | Cursor 每轮自动加载的精简编排规则 |
| `.cursor/skills/` | 39 个阶段、phase、stack 和 peer Skills |
| `.cursor/hooks.json` | 注册 Cursor `sessionStart` |
| `.cursor/hooks/session-start.mjs` | 跨平台启动 Python session context |
| `.cursor/mcp.json` | 项目级 Playwright MCP；内置 Browser 不写入此处 |
| `sop.yaml` | Bundle 路径 SSOT、portable URI 和旧 sibling 映射 |
| `pyproject.toml` | Python 包、`sop` 命令、依赖和 pytest 配置 |
| `requirements.txt` | Office、文档与 Schema 工具依赖 |
| `.github/workflows/sop-validation.yml` | Windows/macOS portable CI 与 Windows unified smoke |
| `projects/CURRENT.md` | 当前 active slug 指针，不是审批 |
| `projects/_template/` | 每个项目的治理、INTAKE、TEST、DOCS 模板 |
| `workspaces/` | REQ/UI/ARCH/CODE/PPT 实际阶段产物 |
| `vendor-templates/` | REQ/UI/ARCH/CODE 阶段目录脚手架 |
| `schemas/` | state、配置、intake、测试和回归 Schema |
| `docs/adr/` | 架构决策记录 |
| `docs/governance/` | 会话门禁和机器状态治理说明 |
| `docs/_global-style/` | 文档类型的全局 style-card seed |
| `tests/` | Python portable 路径、治理、迁移、Hook 和 schema 测试 |

### Portable URI

`state.json` 不保存依赖某台机器的活动绝对路径，而使用：

- `bundle://...`：相对仓库根
- `project://...`：相对 `projects/<slug>/`
- 外部历史源路径：允许保留真实绝对路径作为 provenance

默认阶段布局：

```text
projects/<slug>/                  # SOP / INTAKE / TEST / DOCS
workspaces/req/projects/<slug>/   # REQ
workspaces/ui/projects/<slug>/    # UI
workspaces/arch/projects/<slug>/  # ARCH
workspaces/code/project/<slug>/   # CODE（project 为单数）
workspaces/ppt/projects/          # PPT
```

### Python 核心模块

| 模块 | 职责 |
|------|------|
| `src/sop/cli.py` | `python -m sop` / `sop` 参数树和命令分发 |
| `src/sop/config.py` | 加载 `sop.yaml`，解析 portable URI，阻止路径逃逸 |
| `src/sop/io.py` | 跨平台原子文本/JSON 写入 |
| `src/sop/state.py` | canonical state、项目创建/激活/枚举、slug/lifecycle guard |
| `src/sop/governance.py` | 门禁前置关系、reset、touch-code、生命周期和 regression freshness |
| `src/sop/operations.py` | scaffold、校验、inventory、session context 和 portable regression |
| `src/sop/migration.py` | 旧 sibling plan/apply、过滤、staging、原地治理更新和失败回滚 |
| `src/sop/__main__.py` | `python -m sop` 入口 |
| `src/sop/__init__.py` | Python 包边界和版本 |

### Schema

| 文件 | 约束对象 |
|------|----------|
| `schemas/sop-config.schema.json` | Bundle workspaces、project paths 和 migration source |
| `schemas/state.schema.json` | 项目状态、阶段、门禁引用、治理、时间戳和回归摘要 |
| `schemas/intake-manifest.schema.json` | 历史扫描边界、统计、截断和排除证据 |
| `schemas/intake-ledger-row.schema.json` | 逐文件阅读、提取、索引和跳过状态 |
| `schemas/test-catalog.schema.json` | 测试来源、需求追踪、用例和映射 |
| `schemas/last-run.schema.json` | 回归结果、suite 统计、应用生命周期和 freshness |

### 每个项目的治理与证据文件

| 路径 | 作用 |
|------|------|
| `SOP.md` | 人类可读阶段表、时间戳镜像、阻塞和事件日志 |
| `state.json` | 机器索引；不是人工门禁权威 |
| `APPROVALS.md` | 追加式对话批准、拒绝和 superseded 记录 |
| `DECISIONS.md` | waiver、变更、reset、合规和 lifecycle 决策 |
| `IMPACT.md` | 跨阶段影响分诊 |
| `intake/actual-state.md` | 历史项目 as-is 现状 |
| `intake/evidence-map.md` | 证据 ID、来源和 BACKFILL 对应 |
| `intake/stage-gap-matrix.md` | 六阶段现状、缺口和风险 |
| `intake/supplement-plan.md` | SUP 项、owner、canonical target 和状态 |
| `test/catalog.yaml` | 测试用例及 PRD/ARCH/UI 追踪 |
| `test/runtime.yaml` | 跨平台 code/product 命令、根路径和健康地址 |
| `test/runtime.ps1` | Windows 兼容测试运行配置 |
| `test/coverage.md` | 覆盖范围和缺口 |
| `test/code/mapping.yaml` | 代码测试与需求/模块映射 |
| `test/product/` | Playwright package、lock、config 和 specs |
| `test/scripts/run-all.ps1` | 项目内 full regression 包装 |
| `test/scripts/run-code.ps1` | 仅代码测试，不是 full regression evidence |
| `test/scripts/run-product.ps1` | 仅产品测试，不是 full regression evidence |
| `docs/registry.md` | 文档类型、最新输出、style-card、来源版本和 stale |
| `docs/README.md` | 项目文档产出规则 |

## 脚本地图

脚本用于承接可重复、可验证、耗 Token 的工作。Python 是跨平台行为核心；
PowerShell 保留 Windows 兼容和既有 smoke。所有脚本只能生成或记录证据，
不能自行通过人工门禁。

### 环境与启动

- `scripts/bootstrap.py`：跨平台 bootstrap；创建 `.venv`，安装 Python、
  Node 测试依赖和 Playwright Chromium，检查 Docker 与 PPT skill。
- `scripts/bootstrap-tools.ps1`：Windows 薄入口，转调 `bootstrap.py`。
- `bootstrap.command`：macOS 入口，转调 `bootstrap.py`。

### 项目组合与路径

- `scripts/new-project.ps1`：从 `_template` 原子创建项目并替换 slug；
  `new` 删除 intake，`historical` 进入 INTAKE。
- `scripts/list-projects.ps1`：列出 slug、生命周期、阶段、mode 和 active 状态。
- `scripts/set-active-slug.ps1`：原子更新 `projects/CURRENT.md`。
- `scripts/validate-sibling-paths.ps1`：检查各阶段路径；结果只作为证据。
- `scripts/scaffold-sibling-stage.ps1`：为 REQ/UI/ARCH/CODE 建立阶段骨架。

### 治理、门禁与变更

- `scripts/lib/project-state.ps1`：Windows 共享治理库；包含稳定门禁、前置关系、
  reset 矩阵、slug/lifecycle guard、canonical state、原子 I/O 和 SOP 行更新。
- `scripts/record-gate.ps1`：记录会话中的批准、拒绝或 waiver，并镜像 state。
- `scripts/apply-gate-reset.ps1`：按变更级别失效下游门禁缓存，保留历史。
- `scripts/touch-code-change.ps1`：运行时代码变更入口；先 reset，再更新时间戳。
- `scripts/write-governance.ps1`：记录数据分类、合规、驻留、保留、审计和
  `ui_input_mode`。
- `scripts/set-lifecycle.ps1`：切换 `active/paused/cancelled/archived`。
- `scripts/record-cancellation.ps1`：项目取消后允许的追加式跟进记录。

### 历史项目 INTAKE

- `scripts/inventory-historical-project.ps1`：有界扫描、排除依赖/缓存/敏感项，
  生成 manifest、ledger、SOURCE 和 handoff 骨架。
- `scripts/extract-office-text.py`：提取 docx/pptx/xlsx/pdf/drawio/vsdx；
  旧 `.ppt` 只进入人工转换队列。
- `scripts/validate-intake-schema.py`：校验 intake manifest、ledger 和 SOURCE。
- `scripts/validate-intake-artifacts.ps1`：校验完整阅读、无 eligible pending、
  现状/证据/缺口和六类 handoff。
- `scripts/update-intake-ledger.ps1`：原子更新 ledger 条目与 manifest 统计。
- `scripts/validate-supplement.ps1`：校验 SUP 证据、owner、canonical target 和阶段条件。
- `scripts/apply-supplement.ps1`：事务式应用补充并登记 BACKFILL provenance。

### 测试、回归与文档

- `scripts/run-full-regression.ps1`：catalog 预检、code/product 测试、应用健康、
  `last-run.json`、freshness 和 state 镜像。
- `scripts/install-project-test-deps.ps1`：按 lockfile 安装产品测试依赖并检查浏览器。
- `scripts/validate-docs-artifacts.ps1`：校验 registry、输出、style-card 和 stale。
- `scripts/md-to-docx.py`：把最终 Markdown 导出为 DOCX。

### Schema、静态契约和自动验证

- `scripts/validate-json-schema.py`：通用 JSON/YAML Schema 校验。
- `scripts/validate-static-contracts.py`：校验 39 个 Skills、唯一 auto-entry、
  `disable-model-invocation`、Markdown 链接、Hook、portable config 和旧绝对路径。
- `scripts/register-sop-validation-task.ps1`：Windows 可选定时验证任务。
- `scripts/tests/run-sop-validation.ps1`：统一运行全部 PowerShell smoke。
- `scripts/tests/docs-smoke.ps1`：DOCS registry 正反例。
- `scripts/tests/governance-smoke.ps1`：门禁 DAG、waiver、reset、freshness、
  lifecycle 和 slug guard。
- `scripts/tests/intake-smoke.ps1`：inventory、提取、supplement 和事务性。
- `scripts/tests/regression-smoke.ps1`：模式、失败、零测试、schema、freshness 和 Hook warning。
- `scripts/tests/scaffold-smoke.ps1`：项目/阶段脚手架与 CI contract。
- `scripts/tests/static-contract-smoke.ps1`：静态契约 fail-closed 入口。

## Skills 地图

### Skills 地图如何制作

Skills 地图通过五层约束避免 39 个 Skills 抢占上下文：

1. **唯一入口**：只有 `sop-orchestrator` 可以自动触发。
2. **禁用 ambient load**：其余 38 个 `SKILL.md` 均设置
   `disable-model-invocation: true`。
3. **两层路由**：SOP 先选择一个 STAGE suite；stage root 再选择内部能力。
4. **加载预算**：
   - UI：ingest → visual → studio，严格串行
   - ARCH：当前 phase 通常最多两个 peers；grill pair 占满两个名额
   - CODE：最多一个 phase + 两个 stacks
   - PPT：`ppt-studio` 后只选择一个渲染引擎
5. **静态验证**：CI 检查 frontmatter、唯一入口、disabled 标记、链接、
   Hook 和 portable 路径，错误时 fail closed。

原有 Skills 从各过程仓库移植到 `.cursor/skills/` 后，会增加 SOP adapter：

- 阶段 artifact root
- 上游/下游 SSOT
- 进入和退出门禁
- 允许加载的 worker/peer/phase
- 禁止自动触发
- 历史项目 supplement 与 provenance 规则

地图是**路由图**，不是“每轮全部读取”的清单。正确使用方式是：

```text
sop-orchestrator
  → 一个 STAGE root
  → 当前步骤所需的少量 worker / phase / peer / stack
```

### Stage / Root Skills

| Skill | 作用 |
|-------|------|
| `sop-orchestrator` | 唯一 auto-entry；意图、角色、slug、门禁、影响、恢复和阶段路由 |
| `historical-project-onboarding` | 历史项目台账、证据、缺口和六类 handoff |
| `requirements-analysis` | 需求访谈、调研、PRD、验收和定稿证据 |
| `ppt-deck` | 显式 PPT 意图门；调用全局 `ppt-studio` |
| `prd-pack-ingest` | UI suite 入口；读取 PRD/sample data 并生成 handoff |
| `visual-choice-first` | 先比较视觉方向，再由用户选择 |
| `frontend-design-studio` | 根据已选视觉方向实现原型和 design spec |
| `web-3d-vr-experience` | 按触发条件处理 3D/VR/XR 体验 |
| `prd-to-arch-design` | ARCH root；ingest、fusion、design、grill 和 package |
| `project-test` | 从 PRD+ARCH 封装 TEST_PACK 和回归 |
| `dev-agent` | CODE root；选择 phase 和 stacks |
| `docs-output` | 从过程 SSOT 产出文档并维护 style-card |

### CODE Phase Skills

| Skill | 作用 |
|-------|------|
| `ingest-docs` | 读取 PRD/ARCH/UI/TEST，建立 Run Card，不实现 |
| `implement` | 按接受的 slice 和 TDD 增量实现 |
| `verify` | 构建、重启、单测、集成和冒烟 |
| `fix-bug` | 从失败证据定位根因，修复后回到 verify |
| `code-review` | 审查范围、正确性、风险、测试和可维护性 |
| `handoff` | 生成运行、部署、access_url 和已知问题交接 |
| `retrospective` | 非简单故障的根因和防再发记录 |

### CODE Stack Skills

| Skill | 作用 |
|-------|------|
| `web-frontend` | React/Next/Vue/Vite 前端约束和验证 |
| `node-ts` | Node/TypeScript 服务栈 |
| `java-spring` | Java/Spring 构建、测试和运行 |
| `python-web` | FastAPI/Django 等 Python Web 栈 |
| `docker` | 容器、Compose、健康检查和可交付运行 |

### ARCH / Design / Discipline Peers

| Skill | 作用 |
|-------|------|
| `brainstorming` | ARCH/UI 创造性工作前澄清目标与选项 |
| `grill-me` | 把待发布方案组织成质询输入 |
| `grilling` | 压力测试方案；ARCH 发布方案前强制 |
| `domain-modeling` | 领域语言、实体、边界和 ADR |
| `codebase-design` | 深模块、seam、可测试性和 AI 可导航性 |
| `design-an-interface` | 并行探索多个接口形状 |
| `design-documentation` | 把批准需求转为完整技术设计 |
| `prototype` | 为单个设计问题建立可抛弃 probe |
| `writing-plans` | 把已定方案拆为可执行计划 |
| `to-spec` | 把当前会话合成为 spec |
| `to-tickets` | 把计划拆为 tracer-bullet tickets 和阻塞边 |
| `session-handoff` | ARCH→CODE 或跨会话 handoff |
| `test-driven-development` | 实现前建立失败测试和最小增量 |
| `systematic-debugging` | 遇到失败先证据化定位根因 |
| `verification-before-completion` | 宣称完成、提交或 PR 前验证证据 |

### Skill 目录中的其他文件

| 文件类型 | 作用 | 读取时机 |
|----------|------|----------|
| `SKILL.md` | 入口契约、hard rules、流程、产物和 stop conditions | 上层 router 明确激活时 |
| `routing.md` / `identity.md` / `impact.md` / `governance.md` | SOP 控制面拆分 | 当前回合需要时渐进读取 |
| `references/` | 方法、检查维度和冲突矩阵 | root Skill 指名时 |
| `templates/` | canonical artifact 模板 | 创建对应产物时 |
| `agents/openai.yaml` | 上游 peer 的代理元数据 | 保留来源能力，不负责 Cursor 路由 |
| `scripts/` | Skill 自带重复性工具 | Skill 激活且任务需要时 |
| `TRANSPLANT.md` | Skills 移植和 adapter 规则 | 更新 Skills 地图时 |
| `_vendor/SOURCES.md` | 上游来源和版本线索 | 同步/审计移植能力时 |

## 推荐使用习惯

1. 每次明确项目 slug 和本轮目标。
2. 修改前先让编排官做影响分诊。
3. 把测试、文件和 schema 当作证据，而不是批准。
4. 让脚本执行重复检查，聊天只保留关键结论。
5. 每轮只加载当前阶段所需的 Skills。
6. 运行时代码变更后必须产生 fresh full regression。
7. 历史项目先完成 INTAKE，不把现有代码反推为已批准需求。
