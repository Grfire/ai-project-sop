# ADR 0003 — Historical intake and explicit-only PPT routing

## Status

Accepted

## Context

Projects may enter the SOP after years of implementation without canonical PRD,
UI, architecture, test, or documentation packs. Jumping directly to CODE would
make current implementation a silent requirements source. Historical projects
may also contain slide decks that are merely evidence.

## Decision

- Add an `INTAKE` stage owned by 项目接管分析师.
- Require a complete reading ledger: every eligible file has a terminal status,
  while generated directories and sensitive material have explicit exclusions.
- Reconstruct actual state and produce REQ/UI/ARCH/TEST/CODE/DOCS supplement
  packets with provenance.
- Owner roles, not INTAKE, update canonical artifacts.
- PPT is entered only from an explicit current user action to create/edit/review
  a presentation. Existing slide files can be read as evidence without invoking
  the PPT production agent.

## Consequences

- Historical onboarding costs an inventory/read pass before iteration.
- Source projects remain in place by default.
- Current code is evidence, not automatically approved product intent.
- PPT routing is deterministic and cannot be triggered by file discovery.
