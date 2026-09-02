# Oberon vendors its grilling, domain-modeling and handoff guidance

`oberon-grill` and `oberon-handoff` carry their own copies of the interview, domain-modeling
and handoff instructions inside this repo. They do not invoke the personal `grilling`,
`grill-with-docs`, `domain-modeling` or `handoff` skills at runtime.

Decided with Mateus, 2026-09-02.

## Consequences

- Portability. All four of those skills exist in `~/.claude/skills` and **none** in
  `~/.codex/skills` — verified at decision time — so a runtime dependency on them would break
  Oberon outright on Codex, and would work on omp only through its `claude` provider.
- `grill-with-docs` and `handoff` are both `disable-model-invocation: true`, so a model cannot
  self-invoke them. Since every Oberon skill except `oberon-delete` must be self-invocable,
  wrapping them was never actually possible. Vendoring dissolves this.
- Depending on three unversioned personal skills present on one host is the drift ADR-0001
  exists to prevent. v1 already made this call: `obr-grill` was its own skill, not a wrapper.
- Accepted cost: two copies of grilling guidance on this machine, free to diverge. Oberon's
  copy is the versioned one; `grill-with-docs` remains the ad-hoc personal entry point.
