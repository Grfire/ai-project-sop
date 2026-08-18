---
name: ingest-docs
description: >-
  Phase skill that reads user-provided PRD, architecture, and prototype paths,
  extracts acceptance criteria, and builds implementation slices. Only load when
  explicitly instructed by dev-agent. Do not auto-trigger.
disable-model-invocation: true
---

# Phase: Ingest Docs

Loaded only by `dev-agent`. Turns upstream standardized docs into a buildable Run Card.

## Inputs

From Run Card (`project/dev-agent/runtime/run-card.md`) / user:

- `prd_path` (required for feature work)
- `architecture_path` (required)
- `prototype_path` (optional)
- `extra_constraints`

Read the files at those paths. Do not invent missing documents; ask for paths.

## Extract

| Bucket | Capture |
|--------|---------|
| Goals / non-goals | In/out of scope |
| Domain model | Entities, key fields |
| Interfaces | APIs, events, auth |
| UI / prototype | Screens, flows, states |
| NFR | Perf, security, deploy notes |
| Acceptance | Testable bullets |

## Slice

Prefer **vertical slices** (thin end-to-end paths) over horizontal layers.

Write into Run Card:

- `stacks` + `evidence` (union of docs + repo markers)
- Ordered `Slices` checklist
- `Acceptance` list

Always include `docker` in stacks when a running URL will be delivered.

## Clarifications

Ask only **blocking** questions, one at a time. Record non-blocking gaps under `Assumptions / NOTICED`.

## Exit

- Run Card status → `implement`
- Slices and acceptance filled
- Stacks detected
- No unresolved blockers (or explicit assumptions listed)
