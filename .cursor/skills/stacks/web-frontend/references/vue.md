# Vue Notes

Distilled from hyf0/vue-skills best-practice themes.

- Prefer Composition API + `<script setup>` unless the repo standardizes Options API.  
- Keep components focused; extract composables for shared stateful logic.  
- Typed props/emits; avoid silent any.  
- Router: lazy-load route components where appropriate.  
- Pinia: store domain state, not every ephemeral UI flag.  
- Test: `@vue/test-utils` / Vitest; assert rendered behavior.  
- With Docker handoff: ensure build output or dev server is what compose serves; rebuild after FE changes.
