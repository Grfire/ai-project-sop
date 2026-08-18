# ADR 0001 — Sibling workspaces, SOP as brain

## Status

Accepted

## Context

Existing agents already write artifacts under `ai_req_analysis`, `ai_pptx`, `ai-font-design`, `ai_architecture_design`, and `ai_code`. Unifying all files into this repo would break live projects and skill-relative paths.

## Decision

- **Transplant skills** into `ai-project-sop/.cursor/skills/` so one Cursor workspace can route the whole SOP.
- **Keep stage artifacts in sibling roots**, keyed by the same `<slug>`.
- This repo stores orchestration state (`SOP.md`, `IMPACT.md`), TEST_PACK, and docs output/style-memory.
- Stage skills are `disable-model-invocation: true`; only `sop-orchestrator` auto-enters.

## Consequences

- Agents must resolve `projects/<slug>/` against the stage root in `workspace-map.md`.
- CODE remains `ai_code/project/<slug>/` (singular `project`).
- Method harvest inside a transplanted skill should be proposed here and optionally mirrored back to the source repo.
