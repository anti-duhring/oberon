# Grill creates the store at the first settled decision; there is no init skill

Requiring `oberon-init` before `oberon-grill` inverted the dependency: init asks for a project
name and a scope, which are exactly what the grill exists to produce. The user was naming a
feature they did not yet understand, and the id — a slug minted once and never reused
(ADR-0006) — was baked from that cold guess. So `oberon-init` is deleted as a skill and
`oberon-grill` becomes the single entry point: it resolves the project claiming the repo, or,
finding none, interviews storeless and mints at the **first settled decision**. The `oberon
init` CLI verb is unchanged; only its caller moved from the user to the grill.

Decided with Mateus, 2026-09-03.

## Considered Options

- **Mint at the first settled decision.** Taken. The name comes from the design the interview
  just produced, and the store exists from the moment there is anything to lose.
- **Mint at the end of the grill.** Rejected. Maximally informed name, but it buffers every
  decision in the conversation: a grill that dies at Q20 leaves nothing on disk, which is the
  failure this whole project exists to prevent ("survives context compaction and session
  death").
- **Mint up front, inside grill's existing confirmation turn.** Rejected. Smallest diff, but it
  only moves the cold-guess naming problem one skill to the left.
- **Keep `oberon-init` as a skill.** Rejected. Two skills, one of which is a prerequisite the
  user must remember, for a store the other one can create.

## Consequences

- Grill has two openings: **resumed** (id resolved → confirm id + store path) and **storeless**
  (no id → confirm that a store will be created at the first decision). Both still gate on an
  explicit yes (ADR-0012).
- A grill that settles nothing creates nothing. Abandoned interviews leave no empty stores, so
  `oberon list` stays honest.
- The mint is a single turn — propose a working name, confirm, `oberon init`, write `D1`,
  commit — and never repeats for the same project.
- `oberon-status`, `oberon-sync` and `oberon-handoff` used to direct a storeless repo to
  `oberon-init`; they now point at `oberon-grill`.
- The install list drops from six skills to five (`grill`, `status`, `sync`, `handoff`,
  `delete`, plus the unrelated `write-a-skill`).
- Renaming a project after the design shifts is still unsupported: `project_name` is set at
  mint and `oberon set` only takes `--status`. Minting at D1 rather than at the end narrows
  that window but does not close it; add `oberon set --name` if it bites.
