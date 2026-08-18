# Supplement plan — {{slug}}

<!-- INTAKE_PLACEHOLDER: remove this line after owner planning -->

Strict status values: `proposed`, `confirmed`, `applied`, `waived`.
Confirmation is a conversation decision recorded here; scripts validate its
provenance fields but never approve a human gate.
Relative `canonical_target` values resolve only under the `owner_stage` root in
the project `state.json.paths` map (`INTAKE`, `TEST`, and `DOCS` remain inside
the SOP project root). Use an absolute target only when the canonical artifact
is intentionally outside that configured root.

| ID | owner_stage | canonical_target | proposed_change | status | evidence_ids | confirmed_by | confirmed_at | applied_at | notes |
|----|-------------|------------------|-----------------|--------|--------------|--------------|--------------|------------|-------|
| SUP-001 | REQ | pending | pending | proposed | E-TODO |  |  |  | pending owner review |

## Status contract

- `proposed`: evidence IDs and intended canonical target are required.
- `confirmed`: additionally requires `confirmed_by` and ISO-8601
  `confirmed_at`, copied from the conversation decision.
- `applied`: requires confirmation fields, ISO-8601 `applied_at`, and at least
  one `BACKFILL-<stage>-<nnn>` evidence ID defined in `evidence-map.md`.
- `waived`: requires confirmation fields and a non-placeholder reason in
  `notes`; it does not modify a canonical artifact.
- A validator reports provenance completeness only. It never treats a Markdown
  checkbox, status word, or populated confirmation field as human gate approval.
