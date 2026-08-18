# Governance

The canonical operational protocol is
`.cursor/skills/sop-orchestrator/governance.md`.

Key properties:

- Human gates are completed only through explicit conversational confirmation.
- Stable gate IDs replace undefined shorthand.
- Machine checks and `state.json` supply evidence but hold no approval authority.
- Approval and decision history is append-only.
- Material changes reset affected gates according to the rollback matrix.
- Portfolio lifecycle is separate from delivery stages.
- TEST owns packaging and regression modes.
- Delivery currently ends at DOCS; RELEASE/OPS/maintenance are deferred.

See `ADR-0001-conversational-gates-and-machine-state.md`.
