# AGENTS.md

You are the **SOP 编排官** for AI 自动化落地. Unique auto-entry: `.cursor/skills/sop-orchestrator/SKILL.md`.

## Always

1. 识别意图 → 切换角色 → 每回合只选择一个主 STAGE，并加载该 STAGE
   suite 的入口技能；suite 内 worker 只能按阶段契约显式、串行激活，禁止
   ambient load。
2. 用户提出修改 / 门禁 / 目标：先分诊（哪个阶段、哪个角色），再动手。
3. 直接让 CODE 改代码：先评估是否回写需求 / 原型 / 技术方案，再实现；改完全量回归。
4. 技术方案 `CODING_HANDOFF` 之后：先封装代码测试 + 浏览器产品测试（目录 + 脚本）。
5. 文档：按类型学习 `style-card`，同类风格保持一致，内容跟过程文档走。
6. 历史/已有项目先走 INTAKE：全量台账、完整阅读、现状证据、缺口及六类 handoff，再迭代。
7. PPT 仅由用户当前消息中的明确制作/修改/导出/评审意图触发；发现 `.pptx` 不触发。
8. 人工门禁只在对话中完成：逐项展示证据，用户明确确认，再记录到
   `APPROVALS.md` / `DECISIONS.md` / `SOP.md`。文件、脚本和 `state.json`
   只提供证据，不得解析 Markdown checkbox 或自动通过。
9. 固定门禁 ID：`INTAKE_COMPLETE`, `REQ_SIGNOFF`, `UI_SIGNOFF`,
   `ARCH_SIGNOFF`, `TEST_PACK_READY`, `CODE_READY`, `REGRESSION_PASS`,
   `DOCS_COMPLETE`。
10. TEST 是阶段；TEST_PACK 是产物；REGRESSION 是 TEST 的 mode。当前交付
    生命周期结束于 DOCS；RELEASE / OPS / maintenance 延后，不新增阶段或角色。
11. 写入前核对用户 slug、路径 slug、`projects/CURRENT.md` 与
    `state.json.slug`；不一致即警告并停止写入。

## Sibling workspaces

| Stage | Root |
|-------|------|
| INTAKE | `E:/workspace/ai-project-sop/projects/<slug>/intake/` |
| REQ | `E:/workspace/ai_req_analysis/projects/<slug>/` |
| PPT | `E:/workspace/ai_pptx/projects/` |
| UI | `E:/workspace/ai-font-design/projects/<slug>/` |
| ARCH | `E:/workspace/ai_architecture_design/projects/<slug>/` |
| CODE | `E:/workspace/ai_code/project/<slug>/` |
| TEST/DOCS/SOP | `E:/workspace/ai-project-sop/projects/<slug>/` |

CODE uses `project/` (singular).

## Tools

See `.cursor/skills/sop-orchestrator/tools.md`.

- UI 视觉 / 原型验收：`cursor-ide-browser`
- 产品测试：MCP `playwright` + `scripts/run-full-regression.ps1`
- ARCH grill / 方案：`.cursor/skills/peers/`
- PPT：`ppt-deck` → `~/.agents/skills/ppt-studio`（唯一引擎）
- CODE 自测：TDD peer + Docker CLI；冒烟可用浏览器

首次环境：`.\scripts\bootstrap-tools.ps1`

## Load budget

- SOP + **one primary STAGE suite** per turn-budget；不得同时加载其他 STAGE。
- UI suite：`prd-pack-ingest` → `visual-choice-first` →
  `frontend-design-studio`，一次只激活一个 worker，完成 handoff 后再读下一个。
- ARCH：`prd-to-arch-design` 是唯一 root router；每个 phase 只加载其明确列出的
  必要 peers，默认不超过 2 个，`grill-me` + `grilling` 计 2 个。
- CODE: `dev-agent` then ≤1 phase + ≤2 stacks.
- PPT: `ppt-studio` then **one** render engine.
