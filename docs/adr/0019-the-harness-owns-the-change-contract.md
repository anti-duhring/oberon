# The harness owns the change contract; Oberon calls it and reads it

Since 2026-09-29 every pull request in the 45 `svc-*` repositories gets a `Change Contract` check.
A PR with no `change:fix` or `change:chore` label is a feature, and a feature owes
`.specs/features/<slug>/prd.md` and `spec.md` in the repo it changes, with the spec in that PR's
diff. The check is advisory during a four-week measurement, then blocks. Three harness skills write
those files: `/feature-prd`, `/feature-spec`, and `/feature-implementation`, which drives
`spec-driven`'s design, tasks, execution and Verifier (`validation.md`).

The store never merges (ADR-0004), so nothing Oberon records reaches a repo reader or the check.
Oberon therefore **calls the harness skills and reads what they write**; it never writes `.specs/`
itself, and the harness never writes the store.

- `oberon-grill` ends by classifying the change. For a feature it runs `/feature-prd` then
  `/feature-spec` in each repo, seeded from `DECISIONS.md`, and records each repo's slug on the
  manifest (`contract_slug`, via `oberon attach --contract`). For a fix or chore it records the
  label.
- `oberon-implement` (new) gates each repo on its contract and hands the build to
  `/feature-implementation`, one repo at a time in build order. The store keeps the cross-repo facts
  and the decisions made while building.
- `oberon repo-info` and `oberon status` gain a `contract` object per repo: the files present, the
  spec validator's verdict, done/total from the Requirement Traceability table, the
  `validation.md` verdict, and whether the branch's diff touches the folder. The card renders one
  `contract` row per repo and a `!` line for what the check would flag. `oberon-sync`,
  `oberon-handoff` and `oberon-test` read it as evidence.

When the store and the repo disagree, the repo's files win and the store records why.

Decided with Mateus, 2026-10-06, after the ALT-265 design session ran the same steps by hand.

## Considered Options

- **Oberon calls the harness and reads `.specs/`.** Taken. One owner per file, so the PRD and spec
  the check reads are the ones the harness validated, and Oberon's value stays where the harness
  has none: memory across repos and sessions.
- **Oberon writes `prd.md` and `spec.md` itself from the store.** Rejected. It would be a second
  implementation of `/feature-prd` and `/feature-spec` that drifts from the one the organisation
  maintains, and it would skip the spec author's read of the code, which is what catches a wrong
  PRD.
- **Keep them separate and let the user run both.** Rejected. The ALT-265 session needed both and
  ran them by hand: the store held decisions that never reached the spec until they were copied
  over, and nothing on the card said which repos still owed a contract.
- **Track traceability statuses in `PROGRESS.md`.** Rejected. `spec-driven` already updates the
  table in each task's commit, and that edit is what keeps a follow-up PR in the diff. A second
  copy in the store would disagree with it within a day.

## Consequences

- The manifest gains an optional `contract_slug` per contributing repo; schema stays `1` because
  absent means "not recorded". Without it, a `feat/<slug>` branch names the slug only when that
  folder exists, which is how the check resolves it and keeps an unrelated feature branch in a
  shared clone from reading as a missing contract.
- The CLI runs the spec validator when it finds one (`OBERON_SPEC_VALIDATOR`, else `spec-driven`
  under the Claude, Agents or Codex skill root). Without it the card says `spec unchecked` rather
  than guessing.
- `done` counts traceability rows whose status starts with `verified` or `implemented`, because
  existing specs write `Implemented · T16, T18 …`.
- Install list goes from six Oberon skills to seven. `oberon-implement` is user-invoked, like
  `oberon-test`, because it changes code.
- The card grows by one row per slugged repo. Nothing blocks on it, matching the check's advisory
  phase.
