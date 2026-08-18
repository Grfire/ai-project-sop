---
name: web-frontend
description: >-
  Stack skill for React, Next.js, and Vue implementation patterns. Only load
  when explicitly instructed by dev-agent. Do not auto-trigger.
disable-model-invocation: true
---

# Stack: Web Frontend

## Use when

Repo or architecture indicates React, Next.js, or Vue.

## Responsibilities

- Implement UI slices against prototype + API contracts from architecture docs.
- Keep components aligned with acceptance flows (not pixel-perfect redesign unless required).
- Add unit/component tests for critical UI logic.
- Coordinate with docker stack for static/SSR serve in test env.

## References

- React/Next: [references/react-next.md](references/react-next.md)
- Vue: [references/vue.md](references/vue.md)

## With verify/handoff

Frontend changes that affect the served bundle **require** image rebuild + container restart before READY.
