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
