---
name: code-review
description: >-
  Phase skill for five-axis self review before handoff. Only load when
  explicitly instructed by dev-agent. Do not auto-trigger.
disable-model-invocation: true
---

# Phase: Code Review

Loaded only by `dev-agent`. Reviews the current change set against docs and [references/five-axis.md](references/five-axis.md).

## Steps

1. Diff the changes (staged/unstaged or since slice start).
2. Score each axis; list findings with severity.
3. Set Run Card `critical_open` to the count of Criticals.
4. If Criticals > 0 → Router → implement or fix-bug.  
5. If clean → Router may proceed to handoff (after verify READY).

## Also check

- Acceptance criteria coverage  
- Tests exist for new behavior / bug fixes  
- No secrets in diff  
- Docker/handoff paths still valid  

## Exit

- Review notes on Run Card
- `critical_open = 0` required before handoff
