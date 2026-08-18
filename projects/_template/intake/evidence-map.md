# Evidence map — {{slug}}

<!-- INTAKE_PLACEHOLDER: remove this line after evidence review -->

| Id | Fact | Source | Confidence | Captured at |
|----|------|--------|------------|-------------|
| E-TODO | Replace with a bounded factual statement | `{{source_path}}` | unknown | pending |

## Provenance rules

- IDs are stable and unique. Source uses a repository-relative path plus a
  section, symbol, slide, page, or line range when available.
- Confidence is one of `observed`, `corroborated`, `inferred`, or `unknown`.
- Do not quote secret values. Sensitive evidence records metadata and the
  `skipped-sensitive` ledger reason only.
- Every ledger row marked `read` or `extracted-read` names at least one evidence
  ID. Handoffs and supplement actions reference IDs defined here.
- Applied canonical backfills use `BACKFILL-<stage>-<nnn>` IDs. Their fact names
  the canonical target and applied change; source cites both the intake evidence
  and the resulting canonical artifact location.
