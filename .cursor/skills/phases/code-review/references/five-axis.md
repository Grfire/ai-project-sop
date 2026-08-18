# Five-Axis Code Review

Distilled from addyosmani `code-review-and-quality`.

## Approval standard

Approve when the change clearly improves code health and matches project conventions — not only when perfect.

## Axes

1. **Correctness** — matches acceptance; edges/errors; tests test the right thing  
2. **Readability & simplicity** — clear names; fewer lines when equal; abstractions earn complexity  
3. **Architecture** — fits existing patterns; boundaries; no feature logic in shared kernels  
4. **Security** — validation; secrets; authz; injection/XSS; untrusted external data  
5. **Performance** — N+1; unbounded work; unnecessary rerenders; missing pagination  

## Severity

| Level | Meaning |
|-------|---------|
| Critical | Must fix before handoff |
| Suggestion | Should improve |
| Nice | Optional |

## Change sizing

- ~100 lines changed: ideal  
- ~300: ok if one logical change  
- ~1000: split  

Watch total file size growth (~1000 lines signal to extract).

## Structural remedies

Prefer named restructures: dispatcher over conditional chains; delete pass-through wrappers; move feature logic to owning module; make type boundaries explicit.
