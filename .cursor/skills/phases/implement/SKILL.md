---
name: implement
description: >-
  Phase skill for TDD and incremental coding against Run Card slices. Only load
  when explicitly instructed by dev-agent. Do not auto-trigger.
disable-model-invocation: true
---

# Phase: Implement

Loaded only by `dev-agent`. Implements the next slice from the Run Card.

## Prerequisites

- Run Card has slices + acceptance + stacks
- `Read` ≤2 stack skills listed in `active_loaded.stacks`
- Follow [references/tdd-incremental.md](references/tdd-incremental.md)

## Per-slice workflow

1. Pick the next unchecked slice; mark in progress on Run Card.
2. Discover repo test/build commands.
3. RED → GREEN → REFACTOR for the slice behavior.
4. Keep system compilable; avoid multi-concern dumps.
5. If runtime files changed and you need a running app for local check: rebuild+restart via docker stack rules before claiming the slice works in-container.
6. Hand back to Router → **verify** (do not self-declare READY).

## Scope discipline

- Do not expand beyond docs/acceptance.
- Do not drive-by refactors.
- Record `NOTICED` items on Run Card.

## Exit

- Slice tests exist and pass locally (unit level at minimum)
- Run Card slice checkbox ready to be verified in verify phase
- Status suggestion: `verify`
