---
name: verify
description: >-
  Phase skill for unit tests, integration tests, Docker deploy, and access_url
  smoke. Only load when explicitly instructed by dev-agent. Do not auto-trigger.
disable-model-invocation: true
---

# Phase: Verify

Loaded only by `dev-agent`. Proves the product is READY for downstream business/click testing.

## Read first

- Run Card: `project/dev-agent/runtime/run-card.md`
- Report template: [references/verification-report.md](references/verification-report.md)
- If Docker involved: `.cursor/skills/stacks/docker/SKILL.md`

## Gate order (stop on fatal fail → route to fix-bug)

1. **Discover commands** from README/CI/`package.json`/`pom.xml`/`pyproject.toml` — never assume `npm test`.
2. **Build / compile**
3. **Typecheck** (if toolchain exists)
4. **Lint** (block on fatal; note style debt)
5. **Unit tests**
6. **Integration / contract tests** (API+DB, FE/BE contract, service wiring)
7. **Rebuild + restart** if any runtime-affecting change since `last_rebuild_at`
8. **Docker up + healthcheck**
9. **Smoke `access_url`** (HTTP 2xx on health or agreed entry route)
10. Write Verification Report; set Run Card `overall`

## Rebuild / restart (hard)

```
code or config changed since last_rebuild_at
  → build images
  → recreate/restart containers
  → wait healthy
  → then smoke and mark evidence
```

Forbidden: READY on stale containers; restart without rebuild when image inputs changed.

## Exit criteria

| Field | Required for READY |
|-------|--------------------|
| unit | PASS |
| integration | PASS (or N/A only if single-process pure lib with no I/O — rare) |
| docker_up | PASS |
| smoke_access_url | PASS |
| last_rebuild_at / last_restart_at | present and ≥ last runtime change |
| access_url | set and reachable |

On NOT_READY: update Run Card, return control to Router → `fix-bug` (or implement if missing tests/features).

## Out of scope

Full business/exploratory/click QA — that is the downstream testing agent.
