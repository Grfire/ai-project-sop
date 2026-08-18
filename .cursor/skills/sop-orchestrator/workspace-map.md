# Workspace map

Stage artifacts stay in sibling workspaces. This SOP repo holds **orchestration state**, **test packs**, and **docs output**.

Replace `<slug>` with the kebab-case project id. `projects/CURRENT.md` is the
active pointer; `projects/<slug>/state.json` is the indexable machine summary.
Use `scripts/list-projects.ps1` and `scripts/set-active-slug.ps1`.

| Stage | Role | Artifact root |
|-------|------|----------------|
| INTAKE | 项目接管分析师 | `E:/workspace/ai-project-sop/projects/<slug>/intake/` (source stays at user-provided path) |
| REQ | 需求分析师 | `E:/workspace/ai_req_analysis/projects/<slug>/` |
| PPT | PPT策划 | `E:/workspace/ai_pptx/projects/` (dir name `{slug}_ppt169_{YYYYMMDD}` — record actual path in SOP.md) |
| UI | 原型设计师 | `E:/workspace/ai-font-design/projects/<slug>/` |
| ARCH | 架构师 | `E:/workspace/ai_architecture_design/projects/<slug>/` |
| CODE | 研发工程师 | `E:/workspace/ai_code/project/<slug>/` |
| TEST | 测试架构师 | `E:/workspace/ai-project-sop/projects/<slug>/test/` |
| DOCS | 文档专员 | `E:/workspace/ai-project-sop/projects/<slug>/docs/` |
| SOP | 编排官 | `E:/workspace/ai-project-sop/projects/<slug>/SOP.md` |

## Portfolio and slug resolution

The portfolio is the set of direct project directories under `projects/`
(excluding `_template`) with optional `state.json`. `list-projects.ps1` reports
their lifecycle, stage, mode, and whether each is active.

Before writes, compare:

1. slug explicitly named by the user;
2. slug inferred from the target project path;
3. `projects/CURRENT.md`;
4. `state.json.slug`.

If non-empty values disagree, warn in chat and do not write until the user
resolves the mismatch. Change the pointer atomically with
`set-active-slug.ps1`; do not infer approval or lifecycle changes from it.

## Canonical files (read these, do not invent paths)

| Stage | Must exist when stage is 已定稿 / READY |
|-------|------------------------------------------|
| INTAKE | `manifest.json`, no eligible pending ledger rows, actual/evidence/gaps, six handoff packets |
| REQ | `PRD.md` (status 已定稿), `research-notes.md`, optional `sample-data/` |
| UI | `design/design-spec.md`, `prototype/` |
| ARCH | `design/CODING_HANDOFF.md`, `design/02-architecture.md` … `08-implementation-plan.md` |
| CODE | running `access_url` + `project/dev-agent/runtime/handoff.md` |
| TEST | `test/catalog.yaml` + `test/last-run.json` after any code change |
| DOCS | `docs/registry.md` + `docs/style-memory/<type>/style-card.md` |

Each project governance root also contains `APPROVALS.md`, `DECISIONS.md`, and
`state.json`. The JSON file is machine state, never human gate authority.

## Tools and peer skills

Canonical list: [tools.md](tools.md).

- ARCH / design peers are vendored under `.cursor/skills/peers/` (disabled auto-trigger).
- UI keeps one suite in the UI root: activate `prd-pack-ingest`,
  `visual-choice-first`, and `frontend-design-studio` serially, one worker at a
  time.
- ARCH uses `prd-to-arch-design` as root router; only the active phase's
  allowlisted peers may be read (normally ≤2, with the grill pair counting as 2).
- PPT engines stay global: `~/.agents/skills/ppt-studio`.
- UI visual + smoke: built-in `cursor-ide-browser`.
- Product tests: project MCP `playwright` + `scripts/run-full-regression.ps1`.

## Path rules

- Same `<slug>` across REQ / UI / ARCH / CODE / SOP.
- Historical source roots remain in place by default; intake stores evidence and
  stage packets, not a duplicate codebase.
- CODE root uses **`project/`** (singular). Others use **`projects/`**.
- Never copy sibling product trees into this repo.
- When a transplanted skill says `projects/<slug>/`, resolve it against **that stage's artifact root**, not this SOP repo.
- Validate sibling paths with `scripts/validate-sibling-paths.ps1 -Slug <slug>`
  before cross-workspace writes. Missing paths are evidence/warnings, not gate
  decisions.
