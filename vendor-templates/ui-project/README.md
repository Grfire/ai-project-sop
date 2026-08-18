# UI project scaffold

Use `scripts/scaffold-sibling-stage.ps1 -Slug <slug> -Stage UI` to create
`E:/workspace/ai-font-design/projects/<slug>/` when UI starts. Do not copy this
directory by hand into the SOP repo.

```text
design/
  visual-direction.md   # choice ID, evidence links, timestamps, confirmation
  design-spec.md        # confirmed UI specification
prototype/              # runnable UI prototype
```

The UI stage ends after conversational confirmation of `design-spec.md`; return
to `sop-orchestrator` for ARCH routing.
