---
name: node-ts
description: >-
  Stack skill for Node.js and TypeScript backend APIs. Only load when
  explicitly instructed by dev-agent. Do not auto-trigger.
disable-model-invocation: true
---

# Stack: Node + TypeScript

Influenced by mcollina Fastify best-practice themes and addyosmani API design ideas.

## Responsibilities

- Implement HTTP APIs with explicit validation (schema/zod/etc. per repo).
- Consistent error model (status codes, stable error codes, no stack leaks in prod-like test env).
- Typed boundaries at request/response edges.
- Unit tests for domain logic; integration tests for routes + DB/testcontainers or compose deps.
- Structured logging; never log secrets.

## Commands

Discover from `package.json` scripts / CI. Typical: `pnpm test`, `npm run test`, `npm run build`, `tsc --noEmit`.

## Docker

Service should expose a health route. After API code changes: rebuild+restart before verify READY.
