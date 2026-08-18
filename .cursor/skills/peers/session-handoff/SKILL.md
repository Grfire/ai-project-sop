---
name: session-handoff
description: Write an ARCH-to-CODE package or compact a generic session for another agent.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

# Session Handoff

This peer has two distinct modes. Select from the owning router's context; do
not merge their paths or semantics.

## ARCH package mode (canonical)

When invoked by `prd-to-arch-design`:

1. Write
   `E:/workspace/ai_architecture_design/projects/<slug>/design/CODING_HANDOFF.md`.
2. Use
   `../../prd-to-arch-design/templates/CODING_HANDOFF.md` as the canonical
   template (path relative to this `SKILL.md`).
3. Populate links to the finalized `08-implementation-plan.md`,
   `07-agent-spec.md`, design pack, optional tickets, and PRD.
4. Route the next session back to `sop-orchestrator`, then `dev-agent` /
   `.cursor/skills/phases/implement/SKILL.md`.
5. Do not write a temporary summary in this mode.

The ARCH handoff is a design-package entry point. It is not the CODE deployment
handoff at `project/dev-agent/runtime/handoff.md`.

## Generic session mode

Outside ARCH, write a concise conversation continuation document to the
temporary directory of the user's OS, not the current workspace.

Include a "suggested skills" section in the document, which suggests skills that the agent should invoke.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
