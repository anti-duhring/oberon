---
name: oberon-test
description: Run an Oberon project's tests from the recipe recorded in the store's TEST.md, record the run, then hand off to oberon-sync. Reuses TEST.md when it exists and derives it from repo evidence when it does not, so a cold session re-runs the right suites without rediscovering how. User-invoked only.
disable-model-invocation: true
---

# oberon-test

Run the tests that cover **this project's** change surface, and leave behind a recipe good enough that a fresh session re-runs them without rediscovering anything. Two destinations: `TEST.md` in the store holds *how to test* plus the *last* results; `PROGRESS.md` gets the dated journal entry — and that entry is written by `oberon-sync`, which this skill calls at the end, not by hand here.

User-invoked only. All store mutation through `oberon`; never raw `git` on the store; never hand-edit `project.json`.

## The `oberon` CLI

Call `oberon` from `PATH`. Every store mutation goes through it. If the command is missing,
stop and tell the user to run `install.sh` from the Oberon repo — never fall back to raw
`git` on the store or to hand-editing `project.json`.

## Resolve the project

1. Explicit id argument, else
2. `$OBERON_PROJECT`, else
3. `oberon resolve --repo <abs current git root>`

- One match → proceed.
- Several → prompt which id.
- None → no store claims this repo, so there is nowhere to record a test recipe. Point at `oberon-grill`, which mints the store once a design decision settles, and stop. Do not run a suite you cannot record.

Store dir: `oberon path <id>`. Read `project.json` from there for `contributing_repos`.

Optional user argument: which suite or scope to run (`unit`, one package, one failing test). Honour it, and say in `TEST.md` that the run was scoped.

## Read before running

From the store:

- `TEST.md` — **the recipe.** If it exists, it is the plan; you are not re-deriving it.
- `PROGRESS.md` — `## Current state` and the last entry: what changed recently, therefore what must be covered.
- `DECISIONS.md` — decisions and facts that bind testing (a `K#` recording that one suite needs a live service, a `D#` choosing integration over unit coverage).

From each contributing repo: `oberon repo-info "<PATH>"` — branch, sha, dirty, stat. The stat tells you which packages the run must actually cover; the sha and dirty flag are what the recorded results are pinned to.

## Reuse or derive the recipe

**TEST.md exists** → run what it says, in the order it says. Do not invent a different command because you would have chosen differently. When a recorded command is now wrong (script renamed, package moved, prerequisite gone), fix that line in `TEST.md` and say in the run notes that the recipe was stale and how.

**TEST.md is absent** → derive it from evidence, in this order, before asking the user anything:

1. CI definitions — `.github/workflows/*.yml`, `.gitlab-ci.yml`, `Jenkinsfile`. What CI runs is the authoritative suite.
2. Task runners — `Makefile`, `justfile`, `Taskfile.yml`, `package.json` scripts, `mise.toml`.
3. Language defaults — `go test ./...`, `pytest`, `cargo test`, `bats tests/`, framework runners in `pyproject.toml` / `pom.xml` / `Gemfile`.
4. Service prerequisites — `docker-compose*.yml`, `.env.example`, testcontainers usage, migration steps.
5. Repo docs — `README`, `CONTRIBUTING`, `CONTEXT.md`, `docs/`.

Ask the user only what evidence cannot answer: which suite matters for this feature, credentials or a VPN, whether a slow end-to-end tier is in scope. One question at a time, each with a recommendation.

### Scope

Default to the narrowest suite that genuinely covers the project's change surface (repo-info `stat` plus the last progress entry), and record the wider suite command next to it as the pre-merge gate. A monorepo-wide run is a choice, not a default — take it only when the user asks or when nothing narrower is trustworthy.

## Confirm before dangerous or expensive commands

Ask first, once, naming the command, when it would:

- reset, migrate, seed, or truncate a database; delete volumes; start or stop services
- hit the network, a shared environment, or anything that could touch production data
- take more than a couple of minutes, or cost money

Read-only, repo-local test commands just run. Anything you refuse or the user declines goes into `TEST.md` under **Landmines** with the reason, so the next session does not re-ask.

## Run

- Run the commands **verbatim** and record them verbatim, with `cwd`.
- Record exit code, pass/fail/skip counts, duration.
- Never edit a test, loosen an assertion, add a skip, or narrow a selector to get green. If a test is wrong, that is a finding to report, not a fix to smuggle into a test run.
- A command that cannot run (missing service, missing credential) is **not** a pass. Record it as blocked, with the exact error and the prerequisite.
- Keep raw output out of the store. Cite failing test names and `path:line`.

## Triage every failure

Classify each failure and say which:

- **regression** — caused by this project's work. Evidence: the failure touches files in the repo-info `stat`, or the assertion names this feature's behaviour.
- **pre-existing** — fails independently of this work. Verify it (run the same test on a clean tree or the base sha) when that is cheap; when you do not verify, write **unverified** next to the claim. Never assume pre-existing because it is inconvenient.
- **flaky** — passes on re-run. Record how many runs out of how many, or it is not a flake claim.

A dirty tree means the results describe **unsaved work**: `HEAD` predates what was tested, so the sha alone does not re-derive the run (ADR-0013). Say so in the entry.

## Write `TEST.md`

Path: `$(oberon path <id>)/TEST.md`. Create it lazily on first use — `oberon init` does not seed it. Reuse and update the existing file; never start a second test doc.

```md
# Tests — <project name>

## How to run

1. `<cwd>` → `<command>` — <what it covers> · ~<runtime>
2. …

## Environment

- <service, env var name, tool version> — why it is needed, where to obtain it.

## Suites

| id | scope | command | cwd | ~runtime | last verdict |
|---|---|---|---|---|---|
| unit | package X | `go test ./internal/...` | `/abs/repo` | 40s | green |

## Landmines

- <command not to run, or not to run blind> — <why>.

## Last run — YYYY-MM-DD HH:MMZ

- **repo** `<path>` · branch `<b>` · sha `<12+ abbrev>` · dirty `<true|false>`
- `<command>` → exit `<n>` · <counts> · <duration>
- FAIL `<test name>` — `path:line` — <regression | pre-existing (verified|unverified) | flaky 1/5>
- verdict: <green | red — one clause>

## Run history

- YYYY-MM-DD — <suite id> — <green | red: one clause>
```

### Rules

- **`## Last run` is rewritten wholesale** every invocation. It is a current-state header, not a log.
- **`## Run history` gets one prepended line** per invocation, newest first, **capped at 10** — drop the oldest. Long-form history belongs in `PROGRESS.md`.
- **Recipe first, results second.** The point of the file is that a cold session can re-run the suite; results are the evidence that the recipe works.
- **Only claim what you ran.** A suite listed but not run this invocation keeps its previous verdict and is not mentioned in the run notes as green.
- **Commands must be copy-pasteable** from a stated `cwd`, with prerequisites named. No "run the usual tests".
- **Redact secrets.** Env var and service *names*, never values; say where the value comes from (password manager, teammate, `.env.example`).
- Keep the whole file scannable — if it grows past a page, the recipe is not tight enough.

## Commit

```bash
oberon commit <id> -m "test: <suite> <green|red> — <short note>"
```

## Then hand off to `oberon-sync`

After the commit, invoke `oberon-sync` for the same project id. It writes the dated `PROGRESS.md` entry and rewrites `## Current state`, spined on repo-info evidence — that is the journal, and duplicating it here would fork the history.

- Pass it the run as the chunk to record: suites, counts, verdict, notable failures.
- Its no-op check is legitimate: nothing observable changed since the last entry and a green re-run of the same sha is not news. Accept the no-op — `TEST.md` already holds the result — and say so in one line.
- A **red** run, a newly derived recipe, or a first run on a new sha is news. If sync would no-op on those, the chunk was not described to it properly.

## Report

Report: suites run, verdict per suite, failures with classification, and whether `oberon-sync` appended an entry or no-op'd. No raw test output dumps.

## The status card comes from `oberon-sync`

`oberon-sync` always closes with `oberon card <id>` — on its no-op path too — and it runs last here. So **do not render a second card**: one invocation, one card. Put your report above sync's card and leave the card itself untouched.

The card carries no test verdict (ADR-0016): that lives in your report and in `TEST.md`.

## Failures

- `repo-info` exit 5 (not a repo): note the broken/missing contributing repo path in `TEST.md` under Environment; do not silently skip a repo the manifest still claims.
- Unknown project id (`path` / `resolve` exit 5): stop and say so.
- Every suite blocked by prerequisites: still write `TEST.md` with the recipe, the blockers, and a verdict of **blocked** — the recipe is the deliverable even when the run is not possible yet.
