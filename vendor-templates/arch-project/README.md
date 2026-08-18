# ARCH project scaffold

Use `scripts/scaffold-sibling-stage.ps1 -Slug <slug> -Stage ARCH` to create
resolved `state.paths.arch` when ARCH starts.

Create the canonical pack under `design/` using
`.cursor/skills/prd-to-arch-design/templates/`. The coding entry point is
`design/CODING_HANDOFF.md`. After it is written, return to `sop-orchestrator`
for conversational `ARCH_SIGNOFF`, then TEST packaging / `TEST_PACK_READY`,
then CODE. Do not route `dev-agent` from handoff publication alone.
