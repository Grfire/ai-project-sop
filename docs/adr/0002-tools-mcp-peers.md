# ADR 0002 — Project MCP + vendored peers

## Status

Accepted

## Context

Stage skills depended on global `~/.agents` peers and on Browser/Playwright tools that were not declared in this workspace. The SOP chat only had `cursor-app-control`.

## Decision

- Register **Playwright MCP** in `.cursor/mcp.json` for product-test authoring/debug.
- Use built-in **`cursor-ide-browser`** (not declared in mcp.json) for UI visual gates and smoke.
- Vendor ARCH/CODE **peer skills** under `.cursor/skills/peers/` with `disable-model-invocation`.
- Leave **ppt-studio / ppt-master** global (large script trees); `ppt-deck` reads them by absolute path.
- Bootstrap CLI via `scripts/bootstrap-tools.ps1`.
- Session hook injects the tool map.

## Consequences

- User must enable Browser in Cursor Customize if `cursor-ide-browser` is missing from the session.
- Full regression still prefers scripts over MCP to save tokens.
- `session-handoff` is the ARCH packager; CODE deploy handoff remains `phases/handoff`.
