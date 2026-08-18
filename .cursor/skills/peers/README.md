# Vendored peer skills

Loaded **only** by SOP stage skills (paths in `../sop-orchestrator/tools.md`). All have `disable-model-invocation: true`.

| Dir | Used by |
|-----|---------|
| grill-me, grilling | ARCH R1 |
| brainstorming, writing-plans | ARCH B / C; UI optional |
| domain-modeling, codebase-design, design-an-interface, design-documentation, prototype | ARCH B |
| to-spec, to-tickets, session-handoff | ARCH C (`session-handoff` = conversation/CODING_HANDOFF packager; CODE deploy handoff is `../phases/handoff`) |
| test-driven-development, systematic-debugging, verification-before-completion | CODE |

Do not auto-invoke. Do not use `executing-plans` inside ARCH (production code is CODE stage).
