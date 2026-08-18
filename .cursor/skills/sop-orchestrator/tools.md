# Tool catalog (all stages)

Do not load this file unless routing a stage that needs a tool. Prefer **scripts over chat replay**.

For repeatable inventory, extraction, comparison, and test execution, run the
canonical script once and present only the relevant evidence summary. This is
the default cost/token policy. It does not replace conversational gate
checklists or explicit user confirmation.

Before calling any MCP tool: `GetMcpTools` then `CallMcpTool`. Built-in browser is `cursor-ide-browser` (not in `.cursor/mcp.json`).

## Stage → tools

| STAGE | MCP / IDE | CLI / scripts | Peer skills (Read path) |
|-------|-----------|---------------|-------------------------|
| INTAKE | `ReadFile` for PDF/images; no PPT production tools | `inventory-historical-project.ps1`, `extract-office-text.py` (docx/pptx/xlsx/pdf/drawio/vsdx; `.ppt` conversion-queue only), `validate-intake-schema.py`, `apply-supplement.ps1` | — |
| REQ | — | `write-governance.ps1` | — |
| PPT | `cursor-ide-browser` for HTML preview | `ppt-master` Python scripts (global skill) | `ppt-studio` then **one** engine (global, see below) |
| UI | **`cursor-ide-browser`** — 6-style mockups, critique screenshots | `npm run dev` in prototype | UI suite workers are serial; companion guide: `.cursor/skills/peers/brainstorming/visual-companion.md` |
| ARCH | — | — | root phase allowlist only; normally ≤2 peers, grill pair counts as 2 |
| TEST | MCP **`playwright`** for exploratory clicks; **scripts** for full regression | `scripts/run-full-regression.ps1`, `validate-json-schema.py` | — |
| SOP | — | `set-lifecycle.ps1`, `record-gate.ps1`, `apply-gate-reset.ps1`, `touch-code-change.ps1`, `write-governance.ps1`, `scaffold-sibling-stage.ps1`, `register-sop-validation-task.ps1` | — |
| CODE | `cursor-ide-browser` smoke `access_url`; Docker CLI | stack test cmds + compose | `peers/test-driven-development`, `peers/systematic-debugging`, `peers/verification-before-completion` |
| DOCS | — | `python` + `python-docx` if user asks DOCX; `validate-docs-artifacts.ps1` | — |

## Built-in (enable in Cursor MCP / Browser UI if missing)

| Server | When |
|--------|------|
| `cursor-ide-browser` | UI visual gate, prototype critique, PPT HTML, CODE/TEST smoke of `access_url` |
| `cursor-app-control` | open files / workspace (already on) |

## Project MCP (`.cursor/mcp.json`)

| Server | When |
|--------|------|
| `playwright` | Product tests, generate/debug Playwright specs, headed traces. Full suite still runs via `run-full-regression.ps1` (saves tokens). |

If `GetMcpTools` does not list `playwright` or `cursor-ide-browser`, tell the user to enable it in **Cursor → Customize → MCP / Browser**, then continue with CLI fallback.

## ARCH peer skills (this repo)

Load **only** when `prd-to-arch-design` names them for the active phase. Never
ambient-load the table. Keep the phase's active peer set within its declared
budget (normally ≤2; `grill-me` + `grilling` consumes both slots):

| Skill | Path |
|-------|------|
| grill-me | `.cursor/skills/peers/grill-me/SKILL.md` |
| grilling | `.cursor/skills/peers/grilling/SKILL.md` |
| brainstorming | `.cursor/skills/peers/brainstorming/SKILL.md` |
| domain-modeling | `.cursor/skills/peers/domain-modeling/SKILL.md` |
| codebase-design | `.cursor/skills/peers/codebase-design/SKILL.md` |
| design-an-interface | `.cursor/skills/peers/design-an-interface/SKILL.md` |
| design-documentation | `.cursor/skills/peers/design-documentation/SKILL.md` |
| prototype | `.cursor/skills/peers/prototype/SKILL.md` |
| to-spec | `.cursor/skills/peers/to-spec/SKILL.md` |
| writing-plans | `.cursor/skills/peers/writing-plans/SKILL.md` |
| to-tickets | `.cursor/skills/peers/to-tickets/SKILL.md` |
| session-handoff | `.cursor/skills/peers/session-handoff/SKILL.md` |

`brainstorming` HARD-GATE applies **inside ARCH/UI design**, not to SOP CODE implementation (CODE has its own ingest).

## PPT engines (stay global — do not duplicate)

Read in order: `~/.agents/skills/ppt-studio/SKILL.md` then the chosen engine (`ppt-master`, `guizang-ppt-skill`, `html-ppt`, …). Scripts live under that skill’s `scripts/`.

## Bootstrap

```powershell
.\scripts\bootstrap-tools.ps1
```

Checks Node / Python / Docker / Playwright browsers / `python-docx` / `python-pptx` / `openpyxl` / `pypdf`.
