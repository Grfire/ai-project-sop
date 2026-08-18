---
name: retrospective
description: >-
  Phase skill for post-fix or requested retrospectives with actionable
  improvements. Only load when explicitly instructed by dev-agent. Do not
  auto-trigger. Inspired by engineering post-mortem practice.
disable-model-invocation: true
---

# Phase: Retrospective

Loaded only by `dev-agent`. Use after non-trivial bug fixes or when the user asks for 复盘.

## Output structure

Write to Run Card notes and/or `project/dev-agent/runtime/retro-<date>.md`:

1. **Summary** — what broke / what we learned (2–3 sentences)  
2. **Timeline** — detect → repro → fix → verify  
3. **Root cause** — technical + contributing process gaps  
4. **Impact** — users, data, trust, time lost  
5. **What went well**  
6. **Actions** — concrete, owned, checkable (tests, lint, docs, docker health, slice discipline)  
7. **Follow-ups** — optional NOTICED items  

## Exit

- At least one actionable improvement **or** explicit “none needed” with rationale  
- If an action is “add regression test” and missing, send back to fix-bug/implement before done  
