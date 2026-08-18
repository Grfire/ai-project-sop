# Routing examples

## 「把 E:\legacy\order-system 接进来继续迭代」 

→ INTAKE · 项目接管分析师. Inventory every eligible file, finish the reading
ledger, reconstruct actual state, and write six owner handoffs. Do not jump
straight to CODE even if the source contains runnable code.

## 「老项目里有一个汇报.pptx，帮我接管项目」

→ INTAKE, not PPT. Extract/index the deck as historical evidence. Do not load
`ppt-deck`.

## 「基于接管结果重新制作一份汇报 PPT」

→ PPT because the user explicitly requests production. Load `ppt-deck`.

## 「帮我做一个新项目，大概是内部知识门户」

→ REQ · 需求分析师. Create slug, run `sop scaffold REQ --slug <slug>` into resolved `state.paths.req`, start 调研澄清.

## 「定稿，可以给下游了」

→ Stay REQ and present the `REQ_SIGNOFF` evidence checklist. Ask: “请明确确认
`REQ_SIGNOFF` 通过，或指出不通过项。” Only after explicit confirmation,
append `APPROVALS.md`/`SOP.md` and mirror REQ=`approved` in `state.json`.

## 「按这份 PRD 做原型」

→ UI. `prd-pack-ingest` on req pack, then visual-choice-first (6 版) before any implementation.

## 「出技术方案」

→ ARCH. `prd-to-arch-design`. If UI exists, fusion first. Grill before publishing `02`–`06`.

## 「技术方案定了，下一步」

→ TEST · 测试架构师, `mode=packaging`. Generate `test/catalog.yaml` +
code/product script skeletons from AC/F/API. Present `TEST_PACK_READY` evidence
and wait for explicit confirmation before offering CODE.

## 「让 code 把登录改成 SSO」

```text
【分诊】
- 意图：登录改为 SSO
- 主责：REQ（验收/身份模型）然后 ARCH（集成缝）再 CODE
- 回写上游：是
- 下游：TEST 更新目录 + 全量回归；DOCS 若有用户手册
- 本回合：需求分析师改 PRD，不要先写代码
```

## 「让 code 修一下列表空态文案，PRD 已写」

Code-local. 研发工程师 fixes → 测试架构师 full regression scripts.

## 「门禁过了没 / 谁来解决」

编排官 reads SOP.md + remaining gates, names owner role, does not start unrelated work.

## 「回归一下」

测试架构师 enters TEST `mode=regression`, runs
`scripts/run-full-regression.ps1` (or project-local wrapper), and presents the
`REGRESSION_PASS` evidence. A green result is not approval; ask the user to
explicitly confirm the gate.

## 「项目里发现了 pptx，要不要顺手优化」

→ Stay in the current stage. Discovery is not explicit intent. Ask only if the
user wants a separate PPT action; do not load PPT skills in this turn.
