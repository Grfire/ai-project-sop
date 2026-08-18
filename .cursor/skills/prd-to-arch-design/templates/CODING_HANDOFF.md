# Coding Handoff: {{project-slug}}

## Goal

Implement from the design pack. Do not redesign product scope.

## Read order

1. This file
2. `08-implementation-plan.md`
3. `07-agent-spec.md`
4. `tasks/00-index.md` — only if `tasks/` exists
5. `02`–`06` / `../CONTEXT.md` / `../adr/` as needed
6. PRD only for product ambiguity (PRD wins)

## Suggested skills

- Router: `.cursor/skills/dev-agent/SKILL.md`
- Implementation phase:
  `.cursor/skills/phases/implement/SKILL.md` (loaded by `dev-agent`)
- Discipline peer: `.cursor/skills/peers/test-driven-development/SKILL.md`

## First task

Start at Task 1 in `08-implementation-plan.md` (or first frontier ticket if `tasks/` present).

Return to `sop-orchestrator` for CODE entry checks. Do not invoke a generic
execution skill directly; `dev-agent` owns implementation, verification, review,
and deployment handoff.
