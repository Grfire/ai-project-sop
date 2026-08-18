---
name: docs-output
description: >-
  Generates project documents from process artifacts and learns a per-type
  style-card so later docs of the same type stay consistent. Use when
  sop-orchestrator loads this skill for 文档产出, 手册, 说明书, 部署文档,
  测试报告, or 统一文档风格.
disable-model-invocation: true
---

# Docs Output (SOP stage)

Loaded only by `sop-orchestrator`. Prefer Chinese unless the user writes otherwise.

**Announce:** 「正在使用 `docs-output`：过程文档 → 类型风格卡 → 产出。不纠结展示形态。」

Display format is whatever the user asked (Markdown default, DOCX/PDF only if they name it). Do not spend turns on visual chrome.

DOCX: `python scripts/md-to-docx.py <md> <docx>` after Markdown is final. Need `python-docx` (`.\scripts\bootstrap-tools.ps1`).

For a historical project, read
`project://intake/handoffs/DOCS.md`. Existing
documents are style/content evidence; extract a style-card before generating the
next document, and flag stale facts instead of copying them.

## Artifact root

```text
project://docs
  registry.md
  style-memory/<doc-type>/style-card.md
  output/<doc-type>/<YYYYMMDD>-<short-title>.md
```

`<doc-type>` kebab-case: `user-guide`, `deploy-guide`, `test-report`, `tech-spec-export`, `meeting-notes`, `handover`, or user-named types.

## Workflow

1. **Classify type** from the user request. Reuse an existing type if it matches; do not fork synonyms (`用户手册` = `user-guide`).
2. **Read style-card** if `style-memory/<doc-type>/style-card.md` exists. Follow it strictly (headings, voice, numbering, tables, meta block).
3. **Collect facts** only from process docs (workspace-map): PRD, design-spec, architecture pack, CODE handoff, `test/last-run.json`, prior output of this type. Never invent metrics or APIs.
4. **Write** under `output/<doc-type>/`. Update `registry.md` with type, path,
   sources, **Source revision**, **Output revision**, and **Stale** (`yes`/`no`).
5. **Validate** `.\scripts\validate-docs-artifacts.ps1 -DocsPath projects/<slug>/docs`.
   The report is freshness evidence; it does not approve `DOCS_COMPLETE`.
6. **Learn style** after every successful generation (including the first): refresh the style-card from what you just wrote. Merge; do not reset unless the user says 换风格 / 重学风格.
7. **Ask for confirmation** in the conversation when the requested document set
   is current and ready. Record the answer in the registry; do not infer
   completion from a Markdown checkbox.

If there is no style-card yet, imitate the user's sample if they attached one; else use a plain, consistent default and **still** write the card so the next run matches.

## Style-card (keep short)

See [templates/style-card.md](templates/style-card.md). Capture:

- Title pattern, heading depth, numbering
- Voice (e.g. 公文书面 / 技术说明 / 操作步骤第二人称)
- Meta block (version, audience, sources)
- Tables vs prose preference
- Required sections for this type
- Forbidden (emoji, marketing fluff, unexplained English jargon — only if observed)
- A 5–10 line excerpt as the fingerprint

## Content drift

When PRD/ARCH/CODE/TEST change, regenerate **affected types** listed in `registry.md` (at least user-guide if F/P changed; tech-spec-export if ARCH republished; test-report after regression). Keep the same style-card.

This refresh is ongoing lifecycle work and does not add a new stage after DOCS:

- During REQ/UI/ARCH/CODE/TEST changes, refresh affected registered documents
  and mark their source revisions current.
- `DOCS_COMPLETE` is a conversational gate at the end of DOCS: the user confirms
  that the requested document set is complete and current.
- Later upstream changes reopen only affected document types. Refresh them, then
  ask for confirmation again.
- Registry/checklist state is evidence and bookkeeping, never an automatic gate
  validator.

## Hard rules

- Style is per **type**, not per project mood swing. Cross-project: if `style-memory` already exists for that type in this slug, it wins.
- Optional global hints: `docs/_global-style/<doc-type>/style-card.md` in this SOP repo — copy into the project on first use, then evolve per slug.
- Global seeds are provided for `user-guide`, `deploy-guide`, `test-report`, and
  `tech-spec-export`. They are defaults, not frozen brand rules.
- Do not “improve” layout each time. Consistency > novelty.
- The lifecycle ends at DOCS / `DOCS_COMPLETE`; do not introduce release or ops
  roles/stages.

## Historical supplement closeout

When applying an intake SUP item to a canonical artifact:

1. Edit the canonical file at this stage's sibling root (never the SOP intake copy).
2. Add a `BACKFILL-<STAGE>-<nnn>` row to `project://intake/evidence-map.md` citing intake evidence and the canonical path.
3. Run:

```powershell
.\scripts\apply-supplement.ps1 -Slug <slug> -SupplementId SUP-... `
  -CanonicalTarget <absolute-or-relative-path> -BackfillId BACKFILL-... `
  -AppliedBy "<identity from chat>" -TargetStage <STAGE>
```

4. Keep the `validate-supplement.ps1` report as provenance evidence.
5. Do not treat applied/waived as a human gate. Stage sign-off remains conversational.
