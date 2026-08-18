# Style card — `test-report`

## Voice
- Language: Chinese by default
- Person / tone: objective, concise, evidence-first
- Formality: formal verification report

## Structure
- Title pattern: `<项目名> 测试报告 — <run id>`
- Heading levels used: H1–H3
- Numbering: stable case/suite identifiers from the test catalog
- Opening meta block: run time, revision, environment, result source

## Patterns
- Tables when: suite outcomes, failures, traceability
- Lists when: blockers, observations, follow-up actions
- Callouts / 注意: incomplete suites, flaky evidence, environment exceptions

## Required sections
1. Scope and authoritative inputs
2. Execution summary
3. Results and failures
4. Risks, limitations, and conclusion

## Forbidden
- Re-derived or invented test results
- Treating CODE smoke as full SOP acceptance

## Fingerprint (excerpt)
```text
本报告只陈述 last-run.json 与关联证据。
总体结果：PASS / FAIL / BLOCKED。
失败项保留原始 suite 与 case 标识。
未执行项不得计为通过。
结论不扩大到本次范围之外。
```
