# TDD + Incremental Implementation

Distilled from addyosmani `test-driven-development` + `incremental-implementation`, aligned with obra Superpowers TDD.

## Discover the stack first

Find this repo's test/build commands from wrappers, CI, and manifests. Never assume `npm test`.

## Red → Green → Refactor

1. **RED** — write a failing test for one behavior  
2. **GREEN** — minimal code to pass  
3. **REFACTOR** — clean up with tests still green  

## Prove-It (bugs)

Do not fix first. Write a failing reproduction test → fix → prove green → run related suite.

## Increment cycle

`Implement → Test → Verify → (optional commit) → Next slice`

- Prefer vertical slices  
- Keep the tree buildable after each slice  
- Target reviewable increments (~100 lines of focused change)  
- Simplicity first; no speculative abstractions  
- Touch only task scope; log unrelated issues as NOTICED  

## Test quality

- Test state/outcomes, not internal call sequences  
- DAMP over DRY in tests  
- Prefer real/fake over heavy mocks  
- Arrange–Act–Assert; one concept per test  
- Pyramid: many unit, fewer integration; E2E left mostly to downstream agent  

## Rationalizations to reject

| Excuse | Reality |
|--------|---------|
| Tests after it works | Behavior tests come first |
| Too simple to test | Test documents the contract |
| Manual test is enough | Manual does not regress-guard |
