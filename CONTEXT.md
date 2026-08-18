# SOP Orchestrator

Ubiquitous language for the AI project delivery SOP. No implementation details.

## Language

**SOP**:
The cross-stage operating procedure that routes a delivery from requirements through docs.
_Avoid_: 流程随便说说, pipeline（except the ARCH `PIPELINE.md` artifact）

**编排官**:
The always-on identity that triages intent and switches roles.
_Avoid_: 总代理, God agent

**Stage**:
One delivery phase with a single owner role (INTAKE, REQ, PPT, UI, ARCH, TEST, CODE, DOCS).
_Avoid_: 模块, 步骤（when you mean a Stage）

**Intake**:
The evidence-first onboarding stage for an existing historical project, ending
with a complete reading ledger and owner-specific supplement packets.
_Avoid_: 直接把老代码当需求, 扫一眼目录

**Role**:
The speaking identity for a Stage (需求分析师, PPT策划, 原型设计师, 架构师, 测试架构师, 研发工程师, 文档专员).
_Avoid_: persona, bot name as a substitute for Role

**分诊**:
The impact analysis that names owner Stage/Role, upstream rewrite, and downstream regression.
_Avoid_: 随便改, 先写了再说

**Gate**:
A conversational approval boundary. The orchestrator shows stable-ID evidence
items in chat, and the user explicitly confirms before the decision is
recorded. Machine checks are evidence, never authority.
_Avoid_: Markdown checkbox parsing, auto-pass, inferred approval, G1–G7

**SSOT**:
The document that wins a class of conflict: PRD for product acceptance, architecture design-pack for tech.
_Avoid_: 聊天纪要当需求

**Slug**:
The kebab-case project id shared across sibling workspaces.
_Avoid_: 中文目录名 as the id

**TEST_PACK**:
The catalog + code tests + browser product tests + scripts created in TEST
`mode=packaging` after `ARCH_SIGNOFF`.
_Avoid_: 临场编几个用例

**Regression**:
TEST `mode=regression`: running TEST_PACK scripts after a CODE change, reading
`last-run.json`, presenting fresh evidence, and obtaining `REGRESSION_PASS`
confirmation.
_Avoid_: 用对话把用例再讲一遍

**Project lifecycle**:
Portfolio handling state (`active`, `paused`, `cancelled`, `archived`), separate
from delivery Stage.
_Avoid_: treating lifecycle as a delivery stage

**Machine state**:
`state.json`, an index/session cache for stage, mode, lifecycle, timestamps,
blocks, and approval references.
_Avoid_: treating JSON as human gate authority

**Style-card**:
The learned fingerprint for one document type so later outputs of that type match.
_Avoid_: 每次换一种排版

**Explicit PPT intent**:
A current user request to create, edit, regenerate, beautify, convert, export, or
review a presentation. Artifact discovery alone is not intent.
_Avoid_: 看到 `.pptx` 就触发 PPT 智能体

Current delivery ends at DOCS. RELEASE, OPS, and maintenance are deferred and
are not Stages or Roles.
