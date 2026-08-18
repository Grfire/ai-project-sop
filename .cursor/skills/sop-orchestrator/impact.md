# Impact analysis (分诊)

Run this when the user requests a **修改 / 门禁 / 目标 / 失败 / 不一致**, and **before** CODE edits anything.

Write/append the result to `projects/<slug>/IMPACT.md` and show a short block in chat.

## Chat block

```text
【分诊】
- 意图：{一句话}
- 主责阶段 / 角色：{STAGE} / {角色}
- 原因：{哪条门禁、哪条 F-xx/AC-xx、哪段方案}
- 回写上游：{否 | REQ | UI | ARCH} — {为什么}
- 下游必做：{TEST 全量回归 | 更新用例 | 刷新文档 | 无}
- 本回合动作：{谁先动手}
```

## Owner table

| Symptom | Owner | Notes |
|---------|-------|-------|
| 历史/已有项目接管、资料不齐但要继续迭代 | INTAKE · 项目接管分析师 | Build full ledger/evidence/gaps before choosing downstream owner |
| 目标/范围/验收/角色权限不清楚或要改 | REQ · 需求分析师 | Product SSOT is PRD |
| `REQ_SIGNOFF` evidence incomplete/rejected | REQ | Do not start UI/ARCH/CODE without a recorded bounded waiver |
| 「好不好看 / 选哪版 / 交互手感」 | UI · 原型设计师 | Visual gate; do not invent PRD |
| 交互与定稿 PRD 冲突 | REQ first | PRD wins acceptance; then UI amends |
| 技术方案/接口/部署/缝合点 | ARCH · 架构师 | Grill before republish |
| 用例缺口、回归红、脚本要封装 | TEST · 测试架构师 | Do not weaken AC to pass |
| 实现、bug、Docker、联调 | CODE · 研发工程师 | After 分诊 |
| 文档风格/手册过期 | DOCS · 文档专员 | Content from process docs |
| 「卡在哪 / 谁负责」 | SOP · 编排官 | Read SOP.md gates |

## CODE change → upstream regression (mandatory)

After identifying a code change (user asked, or you are about to edit CODE), classify:

| If the change … | Must also |
|-----------------|-----------|
| Alters user-visible behavior vs F-xx / AC-xx / P-xx | **Stop or dual-track:** REQ updates PRD (or user confirms PRD already allows it). UI if pages/states change. Then TEST catalog. |
| Alters APIs, data model, authz, module seams, deploy topology | ARCH republish (`02`–`06` + handoff) with grill if it is a 方案 change. Then TEST catalog. |
| Is local (bugfix, refactor, tests, styling within spec) | CODE only + **full TEST regression** |
| Makes a test pass by shrinking coverage | Forbidden. TEST/REQ decide |

Do not let CODE become a silent second PRD.

## Gate → role

For every row, the owner assembles evidence; the orchestrator presents the
numbered checklist in chat; only explicit user confirmation passes the gate.

| Gate | Passes when | Owner |
|------|-------------|-------|
| INTAKE_COMPLETE | No eligible ledger row pending; evidence/gaps + six handoffs + supplement plan exist | 项目接管分析师 |
| REQ_SIGNOFF | PRD completeness, scope/AC, open items, compliance fields | 需求分析师 |
| UI_SIGNOFF | visual selection, prototype/design-spec, states and accessibility evidence | 原型设计师 |
| ARCH_SIGNOFF | design pack/handoff, grill closed, UI mode/waiver, compliance/cost decisions | 架构师 |
| TEST_PACK_READY | catalog maps AC/F/API → code + product cases; commands/skeletons exist | 测试架构师 |
| CODE_READY | accepted slice, code checks, Run Card/handoff, access URL smoke or N/A | 研发工程师 |
| REGRESSION_PASS | fresh `last-run.json` shows all required suites PASS | 测试架构师; fail → CODE/UI/ARCH per fail class |
| DOCS_COMPLETE | registry/style-card/source traceability and gaps presented | 文档专员 |

## Fail class (test / review)

| Fail class | Route to |
|------------|----------|
| assertion/unit/integration red, compile, docker down | CODE |
| browser flow ≠ prototype but = PRD | UI (prototype drift) or CODE |
| browser flow ≠ PRD | REQ if product rule unclear; else CODE |
| API contract ≠ `05-api-data.md` | ARCH + CODE |
| flake / env | TEST (stabilize script) then re-run |

## After every CODE update

1. Run `.\scripts\touch-code-change.ps1 -Slug <slug> -DecisionMaker <chat
   identity> -ConfirmationQuote <exact quote> -Reason <runtime change>` before
   handing back to TEST. The command first applies the `runtime_code` reset to
   `CODE_READY`, `REGRESSION_PASS`, and `DOCS_COMPLETE`, preserving superseded
   approvals and the decision trail; only then does it write the same UTC
   `last_code_change_at` to `state.json` and SOP.md. The conversational fields
   are mandatory—there is no timestamp-only bypass and callers must not rely
   on a separate reset.
2. Switch to 测试架构师
3. Run **full** regression via `scripts/run-full-regression.ps1 -Slug <slug>`
   (mode `full`; both suites). `run-code.ps1` / `run-product.ps1` are debug
   wrappers and must not refresh `last_regression_at` or `regression.state=passed`.
4. Read `last-run.json` only — do not re-derive the suite in chat
5. Present freshness/results as `REGRESSION_PASS` evidence and obtain explicit
   user confirmation. A PASS file, a partial-mode PASS, or
   `state.json.regression.state` alone does not pass the gate.
6. If approved and user-facing/process docs exist → 文档专员 refresh affected docs

## Reset and rollback

Use the matrix in `governance.md`. Any material upstream change supersedes the
affected approval IDs, resets downstream machine statuses, and requires new
chat confirmation. Roll back to the last approved artifact/code state or move
forward through revised evidence; record either choice in `DECISIONS.md`.
