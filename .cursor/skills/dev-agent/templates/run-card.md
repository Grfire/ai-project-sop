# Dev-Agent Run Card

## Meta
- run_id:
- started_at:
- status: ingest | implement | verify | review | fix | handoff | blocked | done
- mode: greenfield | brownfield | bugfix

## Inputs
- prd_path:
- architecture_path:
- prototype_path:
- extra_constraints:

## Stack Detection
- stacks: []
- evidence:
- active_loaded:
  - phase:
  - stacks: []

## Slices
- [ ] slice-1:

## Acceptance
-

## Verify Gate
- build: PASS|FAIL|SKIP — command: — evidence:
- typecheck: PASS|FAIL|SKIP — command: — evidence:
- lint: PASS|FAIL|SKIP — command: — evidence:
- unit: PASS|FAIL|SKIP — command: — evidence:
- integration: PASS|FAIL|SKIP — command: — evidence:
- docker_up: PASS|FAIL|SKIP — command: — evidence:
- smoke_access_url: PASS|FAIL|SKIP — evidence:
- overall: READY|NOT_READY

## Deploy
- deploy_method: docker
- compose_file:
- rebuild_required_on_change: true
- last_rebuild_at:
- last_restart_at:
- image_or_container_id:
- access_url:
- health_url:
- start_command:
- stop_command:

## Review
- critical_open: 0
- notes:

## Bugs / Fixes
- current_bug:
- root_cause:
- repro_test:

## Handoff
- ready: false
- package_path: project/dev-agent/runtime/handoff.md
- access_url:

## Assumptions / NOTICED
-
