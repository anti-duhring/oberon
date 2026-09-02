# All skills except `oberon-delete` are self-invocable, gated by confirmation or a no-op check

`oberon-init`, `oberon-grill`, `oberon-sync` and `oberon-handoff` are model-invocable.
`oberon-init` and `oberon-grill` open by confirming with the user before any side effect.
`oberon-sync` reads the last journal entry first and does nothing when nothing observable has
changed. `oberon-delete` is user-invoked only (ADR-0011).

Decided 2026-09-02 (delegated to me by Mateus).

## Consequences

- Self-invocation is where most of the value sits: "we just finished a chunk, record it" and
  "context is running low, write a handoff" are the moments a user reliably forgets and a model
  reliably notices. Restricting those to manual invocation would discard the main benefit.
- The gates exist because self-invocation *executes* rather than offers. Unbidden,
  `oberon-init` would mint an id, create a directory and commit; `oberon-grill` would turn a
  casual design chat into a full interview. Both are commitments the user should make
  knowingly. One confirmation turn preserves auto-discovery at negligible cost.
- `oberon-sync`'s failure mode is different in kind — cheap to trigger, so in a long session it
  would append near-duplicate entries with a commit each (ADR-0008). Its guard is a read of the
  last entry, not a confirmation, because prompting on every sync would defeat the point.
- Descriptions must be written to fire narrowly. A vague description on a self-invocable
  mutating skill is the actual hazard here.
