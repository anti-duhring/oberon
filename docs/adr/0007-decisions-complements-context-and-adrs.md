# `DECISIONS.md` complements `CONTEXT.md` and ADRs; it does not replace them

Three artefacts, split by lifetime and destination:

| Artefact | Lives in | Holds | Outlives the feature |
|---|---|---|---|
| `DECISIONS.md` | the store | every decision this project settled, numbered, plus the load-bearing facts the design rests on | no |
| `CONTEXT.md` | the contributing repo, at its root | that codebase's durable vocabulary | yes |
| `docs/adr/NNNN` | the contributing repo | the few decisions that clear the ADR bar | yes |

Decided with Mateus, 2026-09-02: "a complement, not a substitute."

## Consequences

- `oberon-grill` writes `DECISIONS.md` unconditionally, and *offers* the other two. It never
  writes an ADR into the store: the store never merges anywhere, so an ADR stranded there is
  invisible to the repo readers who need it.
- Writing to `CONTEXT.md` or `docs/adr/` is therefore the one Oberon output that legitimately
  lands in the feature PR. It is a deliberate act, never automatic.
- `DECISIONS.md` is the only one of the three with room for **knowledge** rather than
  decisions — ALT-120's `K13`, "a green test suite has certified wrong behaviour on this
  project more than once," fits no ADR template and was load-bearing throughout.
- Numbered and append-only, per ALT-120's proven shape: `D1…Dn`, and a reversal gets a new
  number naming the one it supersedes so the reasoning trail survives.
- The ADR bar stays high (hard to reverse · surprising · a real trade-off). A grilling session
  settles dozens of things that clear none of those and must still be recorded — that is
  exactly the gap `DECISIONS.md` fills.
