# CODE project scaffold

Use `scripts/scaffold-sibling-stage.ps1 -Slug <slug> -Stage CODE` to create
`E:/workspace/ai_code/project/<slug>/` when CODE starts.

Dev-agent state belongs under:

```text
project/dev-agent/runtime/
  run-card.md
  handoff.md
```

Create `handoff.md` from
`.cursor/skills/phases/handoff/templates/handoff.md`. CODE verify establishes
deploy readiness; SOP acceptance remains the project-test full regression.
The canonical CODE handoff path is `project/dev-agent/runtime/handoff.md`.
