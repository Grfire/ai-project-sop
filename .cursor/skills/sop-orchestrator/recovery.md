# Recovery and escalation

Use this when state, paths, approvals, or stage ownership are inconsistent.
Recovery restores a trustworthy record; it never auto-approves a gate.

## Recovery order

1. Stop writes and show the mismatch in chat.
2. Resolve slug from the explicit user statement, `projects/CURRENT.md`, target
   project path, and `state.json`. If they disagree, ask the user which project
   is authoritative.
3. Read `SOP.md`, `APPROVALS.md`, `DECISIONS.md`, and available machine evidence.
4. Reconstruct machine status in `state.json`; mark uncertain fields `unknown`
   or a stage `blocked`.
5. Present affected gate evidence conversationally and request explicit
   confirmation if approval must be restored or repeated.
6. Append recovery decisions and superseded references; never rewrite history.

## Escalation

| Condition | Escalate to | Action |
|-----------|-------------|--------|
| Product intent or acceptance conflict | 需求分析师 + user approver | stop downstream writes |
| UI is partial/missing at ARCH | 架构师 + user approver | record partial-UI waiver |
| Security, privacy, legal, or compliance unknown | named compliance owner + user approver | block affected sign-off; no unlawful waiver |
| Architecture evidence conflicts with implementation | 架构师, then 研发工程师 | reset ARCH and downstream gates |
| Regression stale/red/absent | 测试架构师 | block CODE completion and DOCS completion |
| Runtime change was touched but timestamp stamping failed | 编排官, then 研发工程师 | keep invalidated CODE/REGRESSION/DOCS caches; repair state and rerun `touch-code-change` with the original conversational decision context |
| Project slug/path mismatch | 编排官 + user | stop writes until resolved |
| Approval identity/scope unclear | 编排官 + user | treat as unapproved |
| Lifecycle paused/cancelled/archived | 编排官 + user | use `set-lifecycle.ps1`; do not write delivery artifacts |

## Failure behavior

If a state file is missing or malformed, session startup emits a warning and
continues with minimal context. It must not modify files, guess approvals, or
prevent Cursor from starting.
