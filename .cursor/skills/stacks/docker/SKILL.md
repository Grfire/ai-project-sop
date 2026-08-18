---
name: docker
description: >-
  Stack skill for Docker/Compose test-environment deploy, healthchecks, and
  mandatory rebuild/restart before verify or handoff. Only load when explicitly
  instructed by dev-agent. Do not auto-trigger.
disable-model-invocation: true
---

# Stack: Docker

Default deploy path for this suite. Final deliverable includes a reachable `access_url`.

## When loaded

- Verify / handoff phases for any runnable application
- Implement phase when adding or fixing container definitions
- Always preferred over ad-hoc local process-only delivery for handoff

## Responsibilities

1. Ensure `Dockerfile` + compose file exist (create minimal viable if missing).
2. Wire app + required dependencies (DB, cache) on one compose network.
3. Expose test entry port; set `access_url` / `health_url` on Run Card.
4. Provide `start_command` (build+up) and `stop_command`.
5. Enforce rebuild+restart after runtime-affecting changes.

See [references/compose-delivery.md](references/compose-delivery.md).

## Run Card fields to own

- `deploy_method: docker`
- `compose_file`, `start_command`, `stop_command`
- `access_url`, `health_url`
- `last_rebuild_at`, `last_restart_at`, `image_or_container_id`

## Done for this stack

- `docker compose ps` shows healthy/running
- Smoke against `access_url` succeeds after the latest rebuild
