---
name: obr-plan
description: "Turn `.oberon/PRD.md` into an executable, resumable plan. Proposes a 1–4 phase split grouping related user stories, discovers verification commands, and writes per-task markdown files under `.oberon/phases/N/N-M.md`. Used by the /obr-plan command."
user-invocable: false
---

# obr-plan

Decompose a finished PRD into phases and tasks the executor can run. Input is `.oberon/PRD.md` plus `.oberon/state.json`; output is a set of `.oberon/phases/N/N-M.md` files and an updated `state.json`.

**Do not implement anything the PRD describes. Just plan.**

---

## The Job

1. Read `.oberon/PRD.md` in full.
2. Propose a phase split (1–4 phases) grouping related user stories. User accepts or overrides.
3. Discover candidate verification commands. User confirms, edits, adds, or removes.
4. Write `.oberon/phases/N/N-M.md` for every task in every phase.
5. Update `state.json` with the phase/task structure and the final verification command list.

Ask exactly two interactive rounds, in this order: (1) phase split, (2) verification commands. Bundle each round into a single user-facing message; do not drip-feed questions.

---

## Step 1 — Phase split proposal

Read every user story (US-001, US-002, …) in PRD.md. Group related stories into **1 to 4 phases** so each phase is internally coherent and the phases form a natural implementation order (foundations first, execution later, polish last).

Present the proposal like this:

```
Phase split proposal:

Phase 1 — <theme>
  - US-001: <title>
  - US-002: <title>

Phase 2 — <theme>
  - US-003: <title>
  - …

Accept, or override the phase count (1–4)?
```

If the user overrides, re-group to match the new count. Keep regrouping until the user accepts.

---

## Step 2 — Task breakdown (per phase)

For each accepted phase, decompose its user stories into **ordered tasks**. Rules:

- One task ≈ one focused implementation unit. A user story may become one task or several.
- Tasks within a phase are numbered `N-1`, `N-2`, … in the order they should run.
- Dependencies between tasks (e.g. `N-3` depends on `N-1`) are recorded in the task file; sequencing still follows the numbered order for v1 (no parallelism).
- Do not inflate: fewer, larger tasks beat many tiny ones when there is no real seam.

Each task file `.oberon/phases/N/N-M.md` uses this exact shape:

```markdown
# [N-M] <Task title>

**Phase:** N
**Parent:** <US-### and/or FR-### references, comma-separated>
**Depends on:** <comma-separated task IDs, or "none">
Suggested skills: <skill-name>    # OPTIONAL — include only when match is obvious

## Goal

<one paragraph, plain prose, describing what this task accomplishes and why>

## Acceptance Criteria

- [ ] <verifiable criterion>
- [ ] <verifiable criterion>
- [ ] <…>

## Files to touch

- <path/to/file> — <one-line hint>
- <path/to/file> — <one-line hint>
```

Rules:

- **Parent** must reference at least one US-### or FR-### from PRD.md.
- **Acceptance Criteria** copy or tighten the PRD's own AC for the relevant stories — do not invent looser criteria.
- **Files to touch** is a hint list, not a contract. Executors may touch more or fewer.
- **Suggested skills** — include the line only when there is an obvious match (e.g. `fe` for an email-template task, `architect` for large structural design). Otherwise omit the line entirely. Do not fabricate skills that don't exist in the harness.
- No implementation pseudocode. No code blocks inside task files (except where the PRD itself shows file/data shapes that clarify the goal).

---

## Step 3 — Verification command discovery

Scan the repo for candidate verification commands. At minimum check:

- `package.json` → `scripts.test`, `scripts.lint`, `scripts.typecheck`, `scripts.build` (if present)
- `Makefile` → common targets: `test`, `lint`, `check`, `ci`
- Go projects (`go.mod` present) → `go test ./...`, `go vet ./...`
- Python projects (`pyproject.toml`, `setup.py`, `tox.ini`) → `pytest`, `ruff check`, `mypy`
- Rust projects (`Cargo.toml`) → `cargo test`, `cargo clippy`
- Shell-only repos → any scripts explicitly tagged as tests (`test.sh`, `run-tests.sh`)

Present the candidates to the user:

```
Detected verification commands:

  1. npm test
  2. npm run lint

Accept, edit, add, or remove? (Reply with the final list, one per line.)
```

Rules:

- If zero candidates are found, **do not silently proceed with an empty list**. Prompt the user explicitly: "No verification commands detected. Supply one or more commands (one per line), or reply `none` to proceed without verification (not recommended)."
- The user's final list is authoritative. Store it verbatim in `state.verification_commands`.
- If the user replies `none`, store `[]` and note in your confirmation message that verification is disabled — the executor will skip the verification step but will still attempt to commit.

---

## Step 4 — Write task files

Create `.oberon/phases/<N>/` for each phase. Write one `N-M.md` per task. Do **not** create any other directories or files under `.oberon/phases/`. Do not pre-create `N-M-context.md` — executors write those at run time.

---

## Step 5 — Update `state.json`

Merge the planned structure into `.oberon/state.json`. Keep every existing field. Add/replace:

- `phase` → `"planned"`
- `updated_at` → fresh ISO-8601 UTC timestamp
- `verification_commands` → array of final commands (may be empty if user chose `none`)
- `phases` → object keyed by phase number as string (`"1"`, `"2"`, …)

Each phase entry:

```jsonc
"1": {
  "status": "pending",
  "started_at": null,
  "completed_at": null,
  "tasks": {
    "1-1": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "commit_sha": null,
      "rewrite_commit_sha": null,
      "last_error": null,
      "last_question": null
    },
    "1-2": { … }
  }
}
```

Write atomically (temp file + rename) when practical.

---

## Step 6 — Confirm

Emit a short block:

```
Planned: <N> phase(s), <T> task(s). Verification: <command list or "disabled">.
Files written under `.oberon/phases/`. Phase: `planned`.

Next: run `/obr-phase 1`.
```

Nothing else. No long summary.

---

## Checklist (before returning control)

- [ ] Read PRD.md in full
- [ ] Phase split accepted by the user
- [ ] Every user story is covered by at least one task
- [ ] Every task file has title, Phase, Parent, Depends on, Goal, AC, Files to touch
- [ ] Verification commands confirmed (or explicitly disabled)
- [ ] `state.phase` is `planned`
- [ ] `state.verification_commands` persisted
- [ ] `state.phases` populated with pending tasks
