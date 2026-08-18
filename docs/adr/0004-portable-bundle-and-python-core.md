# ADR-0004: Portable Bundle and Python Core

- Status: accepted
- Date: 2026-08-18

## Context

The delivery system previously depended on sibling repositories beneath
`E:/workspace`. That made paths, PowerShell hooks, and validation Windows-only.
The target is one cloned Bundle that works in Cursor on Windows and macOS,
without building adapters for other agent harnesses.

## Decision

1. Python >=3.10 is the single behavioral core. `sop.yaml` and project
   `state.json` store `bundle://` or `project://` URIs for active paths.
2. Stage artifacts live under Bundle `workspaces/`; governance, intake, test,
   and docs remain under `projects/<slug>/`.
3. Cursor session start uses a small Node launcher because Cursor installations
   reliably include Node for MCP usage. It locates the Bundle virtual
   environment or a system Python and always emits valid `additional_context`
   JSON.
4. Bootstrap behavior lives in `scripts/bootstrap.py`; PowerShell and
   `bootstrap.command` are thin OS entry points.
5. Legacy sibling paths exist only in `sop.yaml migration.legacy_sources` and
   this ADR. Migration is plan-first, excludes dependencies/caches/secrets,
   stages complete copies, refuses overwrite, and preserves governance records.
6. CI runs package tests, static contracts, CLI smoke, and the hook on Windows
   and macOS. The existing PowerShell unified smoke remains Windows-only.

## Consequences

- A clone is self-contained and movable after bootstrap.
- Active documents and templates cannot rely on an OS drive path.
- Migration cannot merge into an existing target. Operators must choose a new
  slug/clean Bundle or reconcile manually before retrying.
- Atomic rename is guaranteed per target directory on its filesystem. A failed
  multi-target commit removes targets created by that attempt; it cannot offer
  a single filesystem transaction spanning volumes.
- Docker and the global PPT skill remain optional. Product suites that require
  them report those environment gaps separately.
