# Dev-Agent Routing

## Intent → Phase chain

| Intent / signals | Phase chain |
|------------------|-------------|
| User provides PRD/architecture/prototype paths and asks to develop | ingest-docs → implement → verify → code-review → handoff |
| Continue / next slice / keep coding | implement → verify |
| Self-test, integrate, verify, 联调 | verify (on fail → fix-bug → verify) |
| Bug description, bug doc path, test failure | fix-bug → verify → retrospective (if non-trivial) |
| Code review / 审查 | code-review |
| Retrospective / 复盘 | retrospective |
| Deliver / 交付测试 / handoff | verify (must rebuild+restart+smoke) → code-review → handoff |

## Stack detection

| Evidence | Stack |
|----------|-------|
| `package.json` with react/next, `*.tsx`, `next.config.*` | web-frontend |
| `package.json` with vue, `vite.config.*` + vue | web-frontend |
| `package.json` with express/fastify/nest, or `src/**/*.ts` server | node-ts |
| `pom.xml`, `build.gradle`, `build.gradle.kts`, Spring imports | java-spring |
| `pyproject.toml`, `requirements.txt`, FastAPI/Django imports | python-web |
| `Dockerfile`, `docker-compose.y*ml`, `compose.y*ml` | docker |
| Any runnable app needing verify/handoff | **always include docker** |

Also read architecture doc for declared stacks; prefer union of docs + repo evidence.

## Load budget

1. Set `active_loaded.phase` to exactly one phase path under `.cursor/skills/phases/`.
2. Set `active_loaded.stacks` to ≤2 paths under `.cursor/skills/stacks/`.
3. `Read` those SKILL.md files before acting.
4. Do not keep previous phase loaded when switching; update Run Card first.

## Hard blocks

- Do not mark verify `overall=READY` or handoff `ready=true` if:
  - `access_url` missing or smoke failed
  - runtime code/config changed after `last_rebuild_at` without new rebuild+restart
  - unit or integration failed
  - `critical_open > 0` (for handoff)
