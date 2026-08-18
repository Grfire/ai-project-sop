---
name: historical-project-onboarding
description: >-
  Onboards an existing or historical project into the SOP by creating a complete
  source inventory, reading ledger, actual-state evidence map, gap analysis, and
  stage-specific supplement packets. Use only when sop-orchestrator routes an
  explicit history-project import, takeover, migration, resume, or iteration request.
disable-model-invocation: true
---

# Historical Project Onboarding

Loaded only by `sop-orchestrator`.

**Announce:** 「正在使用 `historical-project-onboarding`：全量盘点 → 完整阅读台账 → 现状证据 → 分环节补充 → 后续迭代入口。」

## Inputs

- `source_path` — historical project root; keep it in place unless the user asks to copy/migrate it
- `slug` — shared SOP project id
- optional: intended next goal (fix, continue, redesign, document, test)

## Output

`E:/workspace/ai-project-sop/projects/<slug>/intake/`

```text
intake/
  SOURCE.md
  manifest.json
  reading-ledger.csv
  actual-state.md
  evidence-map.md
  stage-gap-matrix.md
  supplement-plan.md
  extracted/                     # extracted text from supported binary docs
  handoffs/
    REQ.md UI.md ARCH.md TEST.md CODE.md DOCS.md
```

Templates live under `templates/`. Inventory script:

```powershell
.\scripts\inventory-historical-project.ps1 `
  -SourcePath "<source_path>" `
  -Slug "<slug>" `
  -MaxFiles 100000 `
  -MaxBytes 10GB `
  -MaxFileBytes 100MB
```

Limits are safety controls, not completeness waivers. `MaxFiles` truncation is
recorded in `manifest.scan` and blocks validation. Files excluded by
`MaxFileBytes` or exhausted `MaxBytes` are `unsupported` with an actionable
reason and are not read or hashed.

## Definition of “complete reading”

Complete does **not** mean reading dependencies, build caches, generated bundles, or secrets. It means every source-root file has a ledger row with exactly one status:

- `read` — content was read and mapped
- `indexed` — machine-readable metadata/hash captured; content is generated or not decision-bearing
- `extracted-read` — binary document text/image was extracted and read
- `skipped-sensitive` — secret/private material was not opened; reason recorded
- `skipped-generated` — an individually ledgered generated file; reason recorded
- `unsupported` — cannot be decoded; user is told what converter/input is needed

The gate passes only when **no eligible file remains `pending`**. Do not claim “完整阅读” from a directory listing alone.
Generated/dependency/cache directories are summarized in
`manifest.excluded_directories`; their children do not receive per-file
`skipped-generated` rows.

## Workflow

### A. Inventory (no interpretation yet)

1. Confirm `source_path` and `slug`; record them in `SOURCE.md` (authoritative
   source record). Inventory also writes the same path into `SOP.md`
   Historical source as a central index only.
2. Run the inventory script. It records relative path, size, extension, SHA-256, class, status, and reason.
3. Never read or hash `.env.*`, private keys, service-account material,
   kubeconfig, credential/token/password files, browser profiles, database dumps
   likely to contain secrets, or auth stores. Record safe metadata only.
4. Generated folders (`.git`, `node_modules`, build/dist/target, caches, IDE state, coverage, virtualenvs) are ledgered by directory exclusion and summarized in `manifest.json`.
5. Do not content-sniff unknown files. Eligibility and sensitivity are decided
   from bounded metadata/path heuristics; ambiguous material is `unsupported`.

### B. Read by evidence priority

Read all eligible files, in this order:

1. Entry and governance: README, AGENTS/CLAUDE/rules, manifests, workspace configs
2. Product: PRD, requirements, tickets, acceptance, sample data descriptions
3. UX: routes, design docs, screenshots/images, prototypes, UI states
4. Architecture: diagrams, ADRs, API/schema/migration/deploy/observability docs
5. Code: entry points, modules, config schemas, important implementations
6. Tests: test configs, fixtures, unit/integration/E2E suites, reports
7. Operations and docs: Docker/CI/scripts/runbooks/user manuals/release notes
8. Historical binary artifacts: PDF/images via `ReadFile`; DOCX/PPTX/XLSX/PDF/
   draw.io/VSDX text via `python scripts/extract-office-text.py` into
   `intake/extracted/`. Legacy `.ppt` is listed in `intake/conversion-queue.md`
   and must be converted to `.pptx` or PDF by a human, then re-inventoried.
   Do not load `ppt-deck`.

Existing `.ppt`/`.pptx` files are **evidence only**. Reading or indexing them does
**not** enter PPT stage and must not load `ppt-deck`/`ppt-studio`.

After each batch, update `reading-ledger.csv` with:

```powershell
.\scripts\update-intake-ledger.ps1 `
  -IntakePath "projects/<slug>/intake" `
  -Path "<source-relative-path>" `
  -Status read `
  -EvidenceIds E-001,E-002
```

The script sets terminal status/read time/evidence IDs and recomputes manifest
status counts and `eligible_pending`. Facts in outputs cite source paths.

### C. Reconstruct actual state

Write:

- `actual-state.md` — what currently runs, stacks, entrypoints, data, integrations,
  deployment, known risks; distinguish observed vs inferred
- `evidence-map.md` — fact → source path/section → confidence (`observed`,
  `corroborated`, `inferred`, `unknown`)
- `stage-gap-matrix.md` — current evidence vs required REQ/UI/ARCH/TEST/CODE/DOCS contracts

Historical code is evidence of current behavior, **not automatically product intent**.
If code, docs, tests, and user statements disagree, surface the contradiction.
Evidence IDs are stable. `read` and `extracted-read` ledger rows reference IDs
defined in `evidence-map.md`; handoffs and supplement actions use those same IDs.

### D. Prepare supplements for other roles

Create stage packets under `intake/handoffs/`:

| Packet | Contains |
|--------|----------|
| REQ | observed users/flows/rules, proposed F/P/AC mapping, unresolved product decisions |
| UI | existing routes/screens/states/assets, prototype gaps; no automatic redesign |
| ARCH | as-is topology/modules/APIs/data/deploy, technical debt, to-be decision list |
| TEST | existing suites/commands/coverage, missing AC/API/browser cases |
| CODE | repo root, stack, build/run/test commands, hotspots, constraints |
| DOCS | existing document types, samples, style fingerprints, stale content |

There is no PPT packet by default. Existing slide content may be cited as historical
evidence in another packet, but **PPT production is explicit-intent only**.

### E. Owner-controlled backfill

1. Write `supplement-plan.md`: each proposed canonical update, owner role, source
   evidence, and whether user confirmation is required.
2. Do not silently overwrite signed-off PRD/architecture/UI documents.
3. Switch to each owner role only as needed; that role reads its handoff packet,
   applies approved updates to its canonical workspace, then runs the same
   `apply-supplement.ps1` closeout (BACKFILL row, applied status, revalidation).
4. If the user only asks for a CODE iteration, still finish intake and impact triage;
   then route to the minimum upstream owners needed.

Supplement statuses are `proposed`, `confirmed`, `applied`, or `waived`.
`confirmed`/`waived` record `confirmed_by` and `confirmed_at` from the
conversation. `applied` also records `applied_at` and a
`BACKFILL-<stage>-<nnn>` evidence ID that traces the intake evidence and resulting
canonical artifact. Run `validate-supplement.ps1` to check this provenance.
Validators report evidence only; they never infer or approve a human gate from
Markdown checkboxes, status words, or confirmation fields.

### F. Resume / partial intake

1. Treat `manifest.scan.is_truncated=true`, budget-excluded rows, and pending
   rows as explicit partial state; do not restart interpretation from memory.
2. Rerun inventory with larger limits when needed. Existing analysis/handoff
   files are preserved. Inventory **merges** the previous ledger by
   `path+sha256`: unchanged files keep `status` / `evidence_ids` / `read_at`;
   changed or newly eligible files return to `pending`. Remaining
   `{{slug}}` / `{{source_path}}` placeholders are replaced even if the file
   already exists.
3. Work pending rows in bounded batches and use `update-intake-ledger.ps1` after
   each batch. Reconcile refreshed ledger rows with prior evidence IDs.
4. Run `validate-intake-artifacts.ps1`; fix every reported artifact/provenance
   failure before presenting evidence for the conversation gate.
5. Before entering a named iteration stage, run
   `validate-supplement.ps1 -IntakePath ... -TargetStage <STAGE>`. Related SUP
   items must be `applied` or `waived`, applied canonical files must exist, and
   BACKFILL IDs must be present. The validator is evidence only.
6. If interrupted writes are suspected, rerun inventory and validation before
   resuming.

## Gate

`INTAKE_COMPLETE` requires:

- manifest exists and source root is recorded
- inventory is not truncated
- no eligible ledger row is `pending`
- unsupported/sensitive/generated exclusions have reasons
- actual-state + evidence-map + stage-gap-matrix exist
- all six stage handoff packets exist (may explicitly say “no evidence”)
- supplement-plan names the next owner and gate

`INTAKE_COMPLETE` does **not** by itself authorize a named iteration stage.
After that gate, owners apply or waive related SUP items. Entering `<STAGE>`
requires `validate-supplement.ps1 -TargetStage <STAGE>` evidence, then that
stage's own conversational gate.

Artifact validation:

```powershell
.\scripts\validate-intake-artifacts.ps1 -IntakePath "projects/<slug>/intake"
.\scripts\validate-supplement.ps1 -IntakePath "projects/<slug>/intake"
.\scripts\validate-supplement.ps1 -IntakePath "projects/<slug>/intake" -TargetStage REQ
```

Both return nonzero on incomplete evidence/provenance. Neither approves
`INTAKE_COMPLETE`; the human gate is checked in the conversation.

## Hard rules

- Do not execute unknown historical scripts during intake.
- Do not expose or copy secrets.
- Do not mistake current implementation for approved requirements.
- Do not trigger PPT because `.pptx` exists or because slides are mentioned as evidence.
- Do not claim completeness while the reading ledger has unresolved eligible rows.
