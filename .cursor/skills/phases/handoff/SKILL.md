---
name: handoff
description: >-
  Phase skill that packages a Docker-deployed test environment and reachable
  access_url for the downstream testing agent. Only load when explicitly
  instructed by dev-agent. Do not auto-trigger.
disable-model-invocation: true
---

# Phase: Handoff

Loaded only by `dev-agent`. Produces the final deliverable: **deployed test env + access_url**.

## Preconditions (block if unmet)

- Run Card `overall=READY` from verify
- `critical_open = 0`
- Fresh rebuild+restart completed after last runtime change
- `access_url` smoke PASS moments ago (re-smoke if unsure)

If unmet → return to Router (verify / fix-bug / code-review). Do not hand off a stale or untested URL.

## Steps

1. Re-read Run Card Deploy + Verify sections.
2. If any runtime file changed since `last_rebuild_at`: force docker rebuild+restart+smoke.
3. Write `project/dev-agent/runtime/handoff.md` using the sole in-repo template:
   [templates/handoff.md](templates/handoff.md).
4. Set Run Card `handoff.ready=true`, `status=done`, copy `access_url`.
5. Tell the user the **access_url** and where the handoff file lives.

## Downstream boundary

- Downstream does business / functional / click testing.
- This package proves CODE self-verification and deploy readiness only. SOP
  acceptance requires the separate project-test full regression and
  `test/last-run.json`.
- Formal bug-doc protocol is deferred; accept future bug paths via Router → fix-bug when provided.

## Exit

User (or orchestrator) can open `access_url` and read `project/dev-agent/runtime/handoff.md` without further coding from this agent.
