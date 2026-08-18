---
name: fix-bug
description: >-
  Phase skill for systematic bug reproduction, root-cause fix, and regression
  tests. Only load when explicitly instructed by dev-agent. Do not auto-trigger.
disable-model-invocation: true
---

# Phase: Fix Bug

Loaded only by `dev-agent`. Triggered by verify failures, review Criticals, or user-provided bug text/path.

## Workflow

Follow [references/debug-triage.md](references/debug-triage.md):

1. Capture bug on Run Card (`current_bug`).
2. Write **failing** reproduction test (Prove-It).
3. Localize and fix root cause; record `root_cause`.
4. Confirm repro test green; run related suite.
5. If runtime changed: docker rebuild+restart before claiming fixed in env.
6. Return to Router → **verify** (full gates).
7. For non-trivial bugs, Router should run **retrospective** after READY.

## Exit

- `repro_test` path recorded
- Root cause one-liner on Run Card
- Related tests green
- No “fixed” claim without verify phase
