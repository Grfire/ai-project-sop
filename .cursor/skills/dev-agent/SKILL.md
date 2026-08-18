---
name: dev-agent
description: >-
  Coding agent router for implementation from product requirements, technical
  architecture, and prototype design document paths. Use when the user provides
  PRD/architecture/prototype paths and asks to develop, implement, unit test,
  integrate, self-test, code review, fix bugs, retrospectively analyze, Docker
  deploy a test environment, or hand off a reachable access_url to a downstream
  testing agent. Orchestrates phase and stack skills; does not author upstream docs.
  Only load when sop-orchestrator instructs.
disable-model-invocation: true
---

# Dev-Agent (Router)

## SOP adapter

Loaded only by `sop-orchestrator` for STAGE CODE. Treat `E:/workspace/ai_code/` as the coding workspace: product at `project/<slug>/`, Run Card at `project/dev-agent/runtime/run-card.md`. After any runtime-affecting change, return control to SOP for **full TEST regression** (do not skip). Before implementing, SOP must have run impact 分诊.

Discipline peers (Read when the phase needs them): `.cursor/skills/peers/test-driven-development/SKILL.md`, `systematic-debugging`, `verification-before-completion`. Smoke `access_url` with `cursor-ide-browser` if Docker health is up.

For a historical project, read
`E:/workspace/ai-project-sop/projects/<slug>/intake/handoffs/CODE.md` before
ingest-docs. Use its discovered repo root and commands, but verify commands
without executing unknown scripts during INTAKE.

After `sop-orchestrator` routes the turn to STAGE CODE, this skill is the CODE
suite's sole root router. It is **not** a workspace auto-entry and must not
compete with `sop-orchestrator`. Never rely on phase/stack skills
auto-triggering.

## Spec / plan

- Design: `project/dev-agent/design/2026-08-05-dev-agent-skills-design.md`
- Plan: `project/dev-agent/plans/2026-08-05-dev-agent-skills.md`
- Prompts: `project/dev-agent/templates/prompt-templates.md`
- Sources: `.cursor/skills/_vendor/SOURCES.md`
- Project pack: `project/dev-agent/README.md`

## Startup checklist

Copy and track:

```
Dev-Agent Progress:
- [ ] Collect input paths (prd, architecture, prototype optional)
- [ ] Create/update Run Card from template
- [ ] Detect stacks; always add docker when delivering a running app
- [ ] Route intent → phase chain (see routing.md)
- [ ] Load ≤1 phase + ≤2 stacks via Read
- [ ] Execute phases; enforce rebuild/restart before verify READY / handoff
- [ ] Produce access_url + handoff package
```

## Inputs (from user chat)

Required for greenfield/feature work:

1. `prd_path` — product requirements doc
2. `architecture_path` — technical design
3. `prototype_path` — optional but recommended

For bugfix mode: bug description and/or bug doc path; docs paths if available.

If paths missing, ask for them (one question at a time). Do not invent upstream docs.

## Run Card

1. Copy `.cursor/skills/dev-agent/templates/run-card.md` → `project/dev-agent/runtime/run-card.md` (create dirs as needed).
2. Keep it updated every phase transition.
3. Enforce validations in [routing.md](routing.md).

## Load rules (anti-chaos)

| Allowed | Forbidden |
|---------|-----------|
| SOP explicitly routes to and reads this CODE root | This skill or phase/stack ambient auto-trigger |
| `Read` exactly one `phases/*/SKILL.md` | Loading all phases at once |
| `Read` ≤2 `stacks/*/SKILL.md` | Loading every stack “just in case” |

Phase/stack skill descriptions intentionally say do-not-auto-trigger. Always open them with the Read tool.

Optional: Read local Superpowers skills (TDD, systematic-debugging, verification-before-completion) as discipline references — do not install them into this repo.

## Mandatory rebuild / restart

Before any self-test that needs the running app, and before every handoff:

```
runtime-affecting change?
  → docker compose build (or repo-equivalent)
  → docker compose up -d (restart onto new image)
  → wait healthcheck
  → smoke access_url
  → update last_rebuild_at, last_restart_at, image_or_container_id
```

Skip only for docs/comments with no runtime effect; record rationale on Run Card.

## Delivery definition

Downstream testing agent receives a **deployed test environment**. Default deploy is **Docker**. Final form is a reachable **`access_url`** (route/URL). Formal bug/callback protocol with the test agent is deferred.

## Verification boundary

`dev-agent` verify is CODE self-verification: build/type checks, unit and
integration tests, container health, and `access_url` smoke. It establishes
`overall=READY` for deployment handoff, but it is **not** SOP acceptance.

After every runtime-affecting CODE change, return control to `sop-orchestrator`.
The TEST owner runs the project-test full regression scripts and reads
`test/last-run.json`. Only that result can satisfy the SOP REGRESSION gate;
neither Run Card checkboxes nor a successful CODE smoke substitutes for it.

## Phase skill paths

| Phase | Path |
|-------|------|
| ingest-docs | `.cursor/skills/phases/ingest-docs/SKILL.md` |
| implement | `.cursor/skills/phases/implement/SKILL.md` |
| verify | `.cursor/skills/phases/verify/SKILL.md` |
| code-review | `.cursor/skills/phases/code-review/SKILL.md` |
| fix-bug | `.cursor/skills/phases/fix-bug/SKILL.md` |
| retrospective | `.cursor/skills/phases/retrospective/SKILL.md` |
| handoff | `.cursor/skills/phases/handoff/SKILL.md` |

## Stack skill paths

| Stack | Path |
|-------|------|
| web-frontend | `.cursor/skills/stacks/web-frontend/SKILL.md` |
| node-ts | `.cursor/skills/stacks/node-ts/SKILL.md` |
| java-spring | `.cursor/skills/stacks/java-spring/SKILL.md` |
| python-web | `.cursor/skills/stacks/python-web/SKILL.md` |
| docker | `.cursor/skills/stacks/docker/SKILL.md` |

## Routing

See [routing.md](routing.md).

## Done means

- Run Card `overall=READY`
- Fresh rebuild/restart evidence
- `access_url` smoke PASS
- No open review Criticals
- `project/dev-agent/runtime/handoff.md` written from
  `.cursor/skills/phases/handoff/templates/handoff.md` with start/stop and scope
- SOP TEST regression remains pending until project-test reports PASS

## Historical supplement closeout

When applying an intake SUP item to a canonical artifact:

1. Edit the canonical file at this stage's sibling root (never the SOP intake copy).
2. Add a `BACKFILL-<STAGE>-<nnn>` row to `E:/workspace/ai-project-sop/projects/<slug>/intake/evidence-map.md` citing intake evidence and the canonical path.
3. Run:

```powershell
.\scripts\apply-supplement.ps1 -Slug <slug> -SupplementId SUP-... `
  -CanonicalTarget <absolute-or-relative-path> -BackfillId BACKFILL-... `
  -AppliedBy "<identity from chat>" -TargetStage <STAGE>
```

4. Keep the `validate-supplement.ps1` report as provenance evidence.
5. Do not treat applied/waived as a human gate. Stage sign-off remains conversational.
