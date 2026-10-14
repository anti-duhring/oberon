---
name: oberon-implement
description: Implement an Oberon project repo by repo through the harness's /feature-implementation, keeping the store as the cross-repo memory. Gates each repo on its change contract (.specs/features/<slug>/prd.md + spec.md), hands the build to the harness, and records each chunk with oberon-sync. Use when the design is settled and the contract exists, or to resume implementation. User-invoked only.
disable-model-invocation: true
---

# oberon-implement

Oberon does not build features. The harness does: `/feature-implementation` drives `spec-driven`'s design, tasks, execution and Verifier inside one repo, against that repo's `.specs/features/<slug>/`. This skill is the layer above it. It picks the repo, hands the harness what the store knows, and journals what happened so the next session, or the next repo, starts warm.

**The boundary, from ADR-0019:** the harness owns everything under `.specs/` (PRD, spec, `design.md`, `tasks.md`, the traceability statuses, `validation.md`, `.specs/STATE.md`). Oberon owns the store. Neither writes the other's files. When they disagree, the repo's files win, and the store records why.

User-invoked only. All store mutation goes through `oberon`; never raw `git` on the store; never hand-edit `project.json`.

## The `oberon` CLI

Call `oberon` from `PATH`. If the command is missing, stop and tell the user to run `install.sh` from the Oberon repo.

## Resolve the project

1. Explicit id argument, else
2. `$OBERON_PROJECT`, else
3. `oberon resolve --repo <abs current git root>`

One match → proceed. Several → ask which. None → no store claims this repo; point at `oberon-grill` and stop.

Optional argument: which repo to work in. Without one, take the next repo in the build order (below).

## Read before choosing

- `oberon card <id>` — one `contract` row per repo with a recorded slug.
- `DECISIONS.md` — the build order across repos, and every `D#`/`K#` that constrains implementation.
- `PROGRESS.md` `## Current state` and `HANDOFF.md` — where the last session stopped.
- For the chosen repo: `oberon repo-info <path> --contract <slug>`, plus that repo's `.specs/STATE.md` handoff when the harness was mid-flight.

**Build order.** Take it from the store when a decision records one, else from the product folder's parent issue (the harness PRD's `upstream_docs`). Producers before consumers: a repo whose API another repo reads goes first. Say which repo you chose and why, in one line.

## Gate the repo on its contract

| `contract` shows | Do |
|---|---|
| no slug recorded | Find the folder (`.specs/features/<ticket>-<feature>/`), then `oberon attach <id> --repo <path> --contract <slug>`. No folder at all → the contract is owed: run the grill's **Hand the contract to the harness** step, or tell the user to run `/feature-prd` and `/feature-spec` there. Stop |
| `no prd` / `no spec` | Same: the contract is owed. Stop. Never draft either file |
| `spec INVALID` | Stop. `/feature-implementation` refuses an invalid spec, and building to malformed criteria builds to nothing checkable. The fix is `/feature-spec`'s, in the same PR |
| `spec unchecked` | The validator is not installed. Say so; `/feature-implementation` runs it itself |
| prd · spec | Proceed |

A project the grill classified as a **fix** or **chore** has no contract to gate on. Skip the harness, implement directly, and make sure the PR carries the recorded `change:fix` / `change:chore` label.

## Hand the repo to the harness

In the chosen repo, on its `feat/<slug>` branch, run:

```
/feature-implementation <product folder>      # e.g. ALT-265-alti-report-catalogue
```

Give it, as context, the store's `D#`/`K#` that bind this repo, each with its id, and any cross-repo fact it cannot see from one repo: what the producer repo already shipped, what a consumer expects, a contract another repo's spec pinned. Then follow the harness. Its hard limits are binding here too: never deploy, never merge, never mark a PR ready, never edit `prd.md` or `spec.md`.

While it runs:

- **Decisions land in the store, not only in the chat.** A choice `spec-driven` makes in `design.md` that other repos depend on, a spec gap it stops on, an answer the user gives: append a `D#`/`K#` and `oberon commit <id> -m "implement: D<n> <slug>"`.
- **A stop is a stop.** When the harness stops because the spec is wrong or a requirement ID is missing, do not route around it. Record it as a `K#` naming the repo and the requirement, and tell the user who must amend the spec.
- **Journal each chunk.** After a task, or a small run of tasks, lands in commits, run `oberon-sync`. It reads `tasks.md`, the traceability table and `validation.md` through `repo-info` as evidence; it does not copy them.

## The PR

The harness opens no PR of its own for implementation; the code rides the PRD/spec PR's branch or a follow-up on the same `feat/<slug>`. Either way:

- The PR body carries `Spec: .specs/features/<slug>/` — the check's preferred route.
- **The spec must be in the diff.** `spec-driven` flips each requirement's traceability row as its task lands, which is what keeps a follow-up PR in the diff. Before calling a repo done, read the card: `NOT in diff` means the PR will be flagged. Fix it through the harness, not by a cosmetic edit.

## Moving to the next repo

A repo is done for this skill when the harness has written `validation.md` with a verdict, and the user has the report. Record a `K#` with what the next repo needs from this one (endpoint, field names, flag, merge state), run `oberon-sync`, then take the next repo in the build order. One repo per invocation unless the user asks for more.

## Close

`oberon-sync` renders the card, and it runs last. Do not render a second one. Above it, report per repo: requirement IDs done/total, the `validation.md` verdict, what could not be verified and who must verify it, and the next repo.

## Failures

- `repo-info` exit 5: the repo path is gone. Say so; do not skip a repo the manifest claims.
- Harness skills not installed: say so and stop. Do not reimplement `/feature-implementation` or `spec-driven` from memory.
