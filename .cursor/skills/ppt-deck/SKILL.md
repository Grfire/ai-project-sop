---
name: ppt-deck
description: >-
  PPT construction stage for the SOP workspace. Routes to ppt-studio then a
  single render engine; writes decks under ai_pptx/projects. Use only when the
  current user message explicitly asks to create, edit, regenerate, beautify,
  convert, export, or review a PPT/幻灯片/路演 deck/汇报稿.
disable-model-invocation: true
---

# PPT Deck (SOP stage)

Loaded only by `sop-orchestrator`. Prefer Chinese unless the user writes otherwise.

**Announce:** 「正在使用 `ppt-deck`：ppt-studio 路由 → 唯一渲染引擎 → `ai_pptx/projects/`。」

## Entry gate (mandatory)

The current user message must contain an explicit presentation action intent:
make/create, edit/modify, regenerate/redesign/beautify, convert/export, or review.

Do **not** enter because intake discovers `.ppt/.pptx`, another document mentions
slides, or existing slide text must be extracted as evidence. Those remain in the
current stage and must not load `ppt-studio`.

## Artifact root

`E:/workspace/ai_pptx/projects/{slug}_ppt169_{YYYYMMDD}/`

Record the actual directory in `projects/<slug>/SOP.md` (`ppt_path`).

## Workflow

1. Read `~/.agents/skills/ppt-studio/SKILL.md`. Follow its exclusive-engine rule.
2. Upstream: REQ pack Markdown (`PRD.md` + notes). Import as sources; do not invent product facts.
3. Default engine for editable PPTX: `ppt-master` / `ppt-master-skill`. HTML magazine/水墨/瑞士: `guizang-ppt-skill` or `html-ppt` per ppt-studio table.
4. Honor ppt-studio blocking gates (Strategist confirm, export gate). Do not skip.
5. Preview HTML decks with **`cursor-ide-browser`**. PPTX: export then open path for the user (`open_resource` if available).
6. After export, update SOP.md PPT status and path.

## Hard rules

- One main render engine per task.
- Explicit user intent must still be present at entry; artifact presence is insufficient.
- Do not change PRD acceptance from a slide comment — escalate to REQ.
- Do not run parallel PPT engines.

## SOP adapter

Resolve outputs against [workspace-map.md](../sop-orchestrator/workspace-map.md). Do not write decks into `ai-project-sop/projects/` except the path pointer in SOP.md.
