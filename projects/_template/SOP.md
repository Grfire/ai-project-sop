# {{project-slug}}

| Field | Value |
|-------|--------|
| Slug | {{project-slug}} |
| Lifecycle | active |
| Interaction mode | interactive |
| Current stage | REQ |
| Stage mode | none |
| Blocked by | none |
| Project origin | new / historical |
| Historical source | |

## Paths

| Stage | Path |
|-------|------|
| INTAKE | `project://intake` |
| REQ | `bundle://workspaces/req/projects/{{project-slug}}` |
| PPT (`ppt_path`) | |
| UI | `bundle://workspaces/ui/projects/{{project-slug}}` |
| ARCH | `bundle://workspaces/arch/projects/{{project-slug}}` |
| CODE | `bundle://workspaces/code/project/{{project-slug}}` |
| TEST | `project://test` |
| DOCS | `project://docs` |

## Stage status

Values: `not_started | in_progress | blocked | approved | na`.
TEST_PACK is an artifact and REGRESSION is a TEST mode, not stages.

| Stage | Status | Approval / note |
|-------|--------|-----------------|
| INTAKE | na | |
| REQ | in_progress | |
| PPT | na | explicit current-user intent only |
| UI | not_started | |
| ARCH | not_started | `ui_input_mode=complete|partial|none` |
| TEST | not_started | `mode=packaging|regression` |
| CODE | not_started | |
| DOCS | not_started | lifecycle delivery end |

## Timestamps

| Event | When |
|-------|------|
| intake_completed_at | |
| last_code_change_at | |
| last_regression_at | |
| test_pack_at | |
| docs_completed_at | |
| lifecycle_changed_at | |

## Open gates

| Gate ID | Stage | Owner role | Evidence gap / approval ref |
|---------|-------|------------|-----------------------------|
| | | | |

Stable IDs only: `INTAKE_COMPLETE`, `REQ_SIGNOFF`, `UI_SIGNOFF`,
`ARCH_SIGNOFF`, `TEST_PACK_READY`, `CODE_READY`, `REGRESSION_PASS`,
`DOCS_COMPLETE`.

Gates are confirmed in conversation and recorded in `APPROVALS.md`. Machine
state and Markdown formatting are not approval authority.

## Governance

| Field | Value |
|-------|-------|
| Data classification | public / internal / confidential / restricted |
| Regulated data | none / describe |
| Residency / retention | |
| Access / audit | |
| Third-party transfer | |
| Compliance owner | |
| UI input mode | complete / partial / none |
| Active waiver IDs | |
| Cost/token approach | canonical scripts first; concise evidence in chat |

## Log

| When | Stage | Role | Event | Reference |
|------|-------|------|-------|-----------|
| | | | | |
