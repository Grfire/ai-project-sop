# React / Next.js Notes

Distilled priorities from vercel-labs `vercel-react-best-practices` (not the full 70-rule set).

When implementing or reviewing React/Next:

1. **Eliminate waterfalls** — parallelize independent fetches (`Promise.all`); await only where needed.  
2. **Bundle size** — avoid barrel imports; prefer direct imports; dynamic-import heavy client components.  
3. **Server components / RSC** — minimize data passed to client; no mutable request state at module scope.  
4. **Client fetching** — dedupe; don't subscribe to state only used in callbacks.  
5. **Rerenders** — derive state in render; use `startTransition` / deferred values for non-urgent UI.  
6. **Testing** — prefer Testing Library user-centric queries; keep E2E journeys for downstream agent.

Read full upstream rule files only when optimizing a hot path.
