# Historical project intake

Created only when an existing project is brought into the SOP.

Run:

```powershell
.\scripts\inventory-historical-project.ps1 `
  -SourcePath "<historical-project-root>" `
  -Slug "<slug>" `
  -MaxFiles 100000 `
  -MaxBytes 10GB `
  -MaxFileBytes 100MB
```

Completion gate: every eligible row in `reading-ledger.csv` is no longer
`pending`, the scan is not truncated, actual-state/evidence/gaps are populated,
and all six non-placeholder stage packets plus `supplement-plan.md` exist.

## Safe inventory behavior

- Potential secrets (`.env.*`, service-account files, kubeconfig/auth stores,
  private keys, and credential/token/password stores) are metadata-only:
  `skipped-sensitive`, never opened or hashed.
- Generated directories are summarized under `excluded_directories` in
  `manifest.json`; they do not produce one ledger row per file.
- An individual generated file encountered outside those directories may use
  `skipped-generated` with a reason.
- Files over `MaxFileBytes`, files excluded after `MaxBytes` is exhausted, and
  unknown formats use `unsupported` with an actionable reason and are not read.
- Reaching `MaxFiles` sets `scan.is_truncated=true`. A truncated inventory is
  partial and cannot pass validation.
- A path retained from an earlier ledger but absent from a complete current scan
  becomes `removed-at-source`; its hash, evidence IDs, and read timestamp remain
  for history. Evidence-map use produces a warning, while a stage handoff backed
  only by removed evidence is an error.

## Resume a partial intake

1. Inspect `manifest.json` for `scan.is_truncated`, budget limits, status counts,
   and `eligible_pending`.
2. If truncated or budget-excluded, rerun inventory with larger limits. Preserve
   completed analysis documents. Inventory merges ledger rows by path+sha256
   (unchanged files keep read status and evidence IDs) and replaces leftover
   `{{slug}}` / `{{source_path}}` placeholders. It only creates missing templates.
3. Process pending rows in bounded batches. After each batch, update rows with:
   `.\scripts\update-intake-ledger.ps1 -IntakePath <path> -Path <relative-path> -Status read -EvidenceIds E-001`.
4. Re-run `validate-intake-artifacts.ps1`. Its nonzero result is an evidence
   report, not a human gate decision. Python and `jsonschema` are mandatory;
   unavailable schema validation fails closed.
5. Record proposed/confirmed/applied/waived supplements and run
   `validate-supplement.ps1`. Before entering a named iteration stage, run it
   again with `-TargetStage <STAGE>`. Confirmation comes from the conversation,
   never from parsing Markdown checkboxes.

If a run is interrupted while writing ledger or manifest files, rerun inventory
before resuming evidence review. The inventory and update scripts write those
contracts through temporary files to avoid accepting partial output.

Existing `.ppt`/`.pptx` files are intake evidence. They do not trigger PPT
production; only an explicit user request to make, edit, regenerate, or export a
presentation enters the PPT stage.
