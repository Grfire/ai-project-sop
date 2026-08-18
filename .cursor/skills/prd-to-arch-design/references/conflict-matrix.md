# Conflict Matrix

## Artifact writers

| Artifact | Writer |
|----------|--------|
| `00-brief.md` | ARCH-local ingest in `prd-to-arch-design` |
| `01-prototype-map.md` / `01a-ui-req-validation.md` | A2 fusion (orchestrator; `prototype` only for probe) |
| `02`–`06` | Phase B draft → **publish only after G** |
| `CONTEXT.md` / `adr/*`（under `projects/<slug>/`） | `domain-modeling` (+ grill amendments) |
| `09-grill.md` | every G gate (append-only) |
| `07` / `08` | ARCH root / `writing-plans`; grill new solution choices before publish |
| `tasks/*` | ARCH root from the accepted plan (optional) |
| `_probe/**` | `prototype` |
| `CODING_HANDOFF.md` | `session-handoff` + orchestrator |
| `PIPELINE.md` | orchestrator |

## Collisions

| Pair | Rule |
|------|------|
| R1 grill vs “ship draft now” | **Grill wins** — no 方案 publish without G |
| UI vs PRD | PRD wins acceptance; UI wins silent interaction detail; core contradiction → stop |
| External UI assets vs `prototype` skill | Assets → fusion docs; skill → throwaway probe only |
| `grilling` vs batch | Batch may confirm recommended answers in one shot; blockers still stop |
| Fusion vs design-from-PRD-only | Forbidden when `UI_INPUT=yes` |
| Production UI skills vs fusion | Fusion/validation ≠ implementing production UI |
| UI `prd-pack-ingest` vs ARCH Phase A | ARCH-local ingest wins; UI worker is forbidden in ARCH |
| Peer usefulness vs load budget | Active phase allowlist wins; no ambient or carried-over peers |

## Parallelism

Never publish SSOT in parallel with an open grill on that same draft.
Never activate peers from two ARCH phases at once. Phase budgets are A=0,
A2≤1, B≤2, G=2 (`grill-me` + `grilling`), C≤2
(`writing-plans` + `session-handoff`, serial).
