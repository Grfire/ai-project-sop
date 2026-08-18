# Verification Report Template

Adapted from affaan-m/everything-claude-code `verification-loop` and obra verification-before-completion.

```markdown
# VERIFICATION REPORT

Build:       [PASS/FAIL/SKIP] — command: — notes:
Types:       [PASS/FAIL/SKIP] — command: — errors:
Lint:        [PASS/FAIL/SKIP] — command: — notes:
Unit:        [PASS/FAIL/SKIP] — passed/total: — command:
Integration: [PASS/FAIL/SKIP] — passed/total: — command:
Docker up:   [PASS/FAIL/SKIP] — compose: — health:
Smoke URL:   [PASS/FAIL/SKIP] — access_url: — status_code:
Rebuild at:  [ISO-8601]
Restart at:  [ISO-8601]
Image/ID:    [...]

Overall:     [READY/NOT READY] for handoff to testing agent

Issues to Fix:
1. ...
```

Rules:
- Prefer repository scripts / wrappers (`./mvnw`, `./gradlew`, `make test`, `npm test` only after discovering package.json scripts).
- Do not re-run the same command on unchanged code for reassurance.
- READY requires Unit + Integration + Docker up + Smoke PASS (or explicit SKIP with justification only when that layer truly does not exist — never skip Docker+Smoke for a deliverable app).
