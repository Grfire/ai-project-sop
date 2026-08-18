# Approvals — {{project-slug}}

Append-only human gate record. A gate is valid only after its evidence checklist
was presented in conversation and the user explicitly confirmed it. Machine
checks and Markdown checkboxes are never approval authority.

## Record template

### APR-{{id}} — {{gate-id}}

| Field | Value |
|-------|-------|
| Project slug | {{project-slug}} |
| Decision | approved / rejected / waived |
| Approver | {{identity stated in chat}} |
| Confirmed at | {{iso-utc}} |
| Scope / version | |
| Evidence snapshot / links | |
| Confirmation quote | |
| Supersedes | none / APR-... |
| Decision reference | none / DEC-... |

Allowed gate IDs: `INTAKE_COMPLETE`, `REQ_SIGNOFF`, `UI_SIGNOFF`,
`ARCH_SIGNOFF`, `TEST_PACK_READY`, `CODE_READY`, `REGRESSION_PASS`,
`DOCS_COMPLETE`.
