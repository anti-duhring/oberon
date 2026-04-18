---
description: Report the current Oberon project's state (phase, per-task progress) and a concrete next-step advisory. Read-only — never mutates state.
---

You are handling the `/obr-status` command for Oberon.

## Your job

Print a compact, read-only snapshot of the current Oberon project's state, followed by a single-line Next advisory pointing at the concrete next command.

1. Detect whether `.oberon/` exists in the current working directory.
2. If it does not exist, render the uninitialized-directory output (Step 2 below).
3. If it does exist, render the active-project status block (Step 3 below).
4. Print exactly one Next advisory as the final line of output (Step 4 below for active projects; Step 2 for the uninitialized path).

Do **not** write, rename, or delete any file. Do **not** modify `state.json`, phase files, or `PROJECT.md` under any circumstance. `/obr-status` is strictly read-only — even when inconsistency is detected.

---

## Step 1 — Detect initialization

Check whether `.oberon/` exists in the current working directory.

- If `.oberon/` does **not** exist, go to Step 2 (uninitialized path).
- If `.oberon/` exists, go to Step 3 (active project) and then Step 4 (Next advisory).

---

## Step 2 — Uninitialized directory

When `.oberon/` does not exist, produce exactly this output shape, in this order:

1. A single line: `Oberon: not initialized`
2. **If** `.oberon/archived/manifest.json` exists and is a non-empty JSON array: one orienting line naming the most-recent archived project and its timestamp. The most-recent entry is the last element of the array (`/obr-archive` appends in timestamp order). Format:

   ```
   Last archived: <project_name> (<timestamp>)
   ```

   Use the `project_name` and `timestamp` fields from that entry verbatim. If `project_name` is the empty string, use `<unnamed>` in its place. Skip this line entirely when the manifest is absent, unreadable, not a JSON array, or an empty array.
3. The normative Next advisory on its own final line, exactly:

   ```
   Next: run /obr-init
   ```

Rules for the uninitialized output:

- No blank lines between the three lines beyond what a terminal inserts.
- No other text. No header. No emoji. No ANSI color.
- Do not read or touch any file other than `.oberon/archived/manifest.json` (and only to read it).
- If `.oberon/archived/manifest.json` fails to parse as JSON, treat it as absent and omit the orienting line. Do not print a warning — the uninitialized path is best-effort only.

Stop after printing the Next advisory. Do not proceed to the active-project path.

---

## Step 3 — Active project

When `.oberon/` exists, read `.oberon/state.json`. Before rendering anything, validate it (Step 3a). If validation passes, render a compact status block in this order (steps 3b–3d).

### Step 3a — Validate `state.json`

Before any rendering, check that `state.json` is well-formed:

- **Parse failure.** If the file cannot be parsed as JSON, skip all rendering and emit exactly two lines:

  ```
  error: .oberon/state.json is not valid JSON
  Next: inspect .oberon/state.json
  ```

  Stop. Do not proceed to Step 3b, 3c, 3d, or Step 4.

- **Wrong top-level type.** If the file parses but the top-level value is not a JSON object (e.g. array, string, number, null), emit:

  ```
  error: .oberon/state.json is not a JSON object
  Next: inspect .oberon/state.json
  ```

  Stop.

- **Missing or wrongly-typed `phase`.** If the top-level object has no `phase` key, emit `error: .oberon/state.json missing required field 'phase'`. If `phase` is present but is not a string, emit `error: .oberon/state.json field 'phase' is not a string`. In either case the second line is `Next: inspect .oberon/state.json` and rendering stops.

- **Missing or wrongly-typed `version`.** Same treatment for `version`: absent → `error: .oberon/state.json missing required field 'version'`; present but not a number → `error: .oberon/state.json field 'version' is not a number`. Pair with `Next: inspect .oberon/state.json` and stop.

Error lines use the literal lowercase prefix `error:`. The two-line block is contiguous — no blank line between them, no header, no project name, no best-effort rendering. The Next advisory in every Step 3a case is exactly `Next: inspect .oberon/state.json`.

Other fields (`project_name`, `phases`, `completed_tasks`, `created_at`, `updated_at`, `source`, `verification_commands`) may be absent or have unexpected shapes — treat those as render-time issues (Step 3c) or gracefully omit (Step 3b), not as malformed state. Step 3a is the hard-error branch; everything beyond it is best-effort.

### Step 3b — Header line

Exactly one line naming the project and the current top-level phase:

```
<project_name> — phase: <state.phase>
```

Use `state.project_name` and `state.phase` verbatim. The separator is an em-dash (`—`, U+2014) with a single space on each side. No leading bullet, no trailing period, single line.

**Unknown phase value.** The recognized `state.phase` values are `initialized`, `grilled`, `prd-done`, `planned`, `executing`, and `done`. If `state.phase` holds any other string, still print the header line verbatim with the raw value, then emit a warning on its own immediately-following line:

```
warning: unknown phase '<value>'
```

`<value>` is the raw `state.phase` string, wrapped in single quotes. Warning lines use the literal lowercase prefix `warning:`. Rendering then continues into Step 3c with whatever structure can be read.

### Step 3c — Per-phase block

Emit this block **only if `state.phases` is present and non-empty.** If `state.phases` is absent (pre-plan states: `initialized`, `grilled`, `prd-done`), skip this step entirely and go straight to Step 3d.

Otherwise, iterate over `state.phases` in numeric order of the phase keys (`"1"`, `"2"`, …, sorted as integers — never alphabetically). For each phase:

- **Phase-directory drift check.** Before emitting anything for phase `N`, check that `.oberon/phases/N/` exists as a directory. If it does not, emit the appropriate phase summary line using whatever status `state.phases["N"].status` reports (counts line for `completed`, `phase N: skipped` for `skipped`, otherwise just `phase N:` with no task rows), then on the immediately-following line emit:

  ```
  warning: state.json references phases/N/ but directory is missing
  ```

  Skip any per-task rendering for that phase (there are no task files to read). Continue to the next phase.

- **If the phase status is `completed`:** emit a single counts line:

  ```
  phase N: X/Y done
  ```

  where `X` is the number of tasks in that phase whose status is `completed`, and `Y` is the total task count. No per-task list for completed phases.

- **If the phase status is `skipped`:** emit a single line:

  ```
  phase N: skipped
  ```

  No per-task list for skipped phases.

- **Otherwise (`pending`, `in_progress`, `failed`) — this is the current or a future phase:** emit a phase header line followed by one indented task row per task, in task-ID order (`N-1`, `N-2`, …, sorted by integer `M`, never alphabetically):

  ```
  phase N:
    <id> <title> — <status>
    <id> <title> — <status>
  ```

  Each task row uses the task ID verbatim (`N-M`), the task's title (read from the first line of `.oberon/phases/N/N-M.md`, which is `# [N-M] <title>` — take everything after `] `), an em-dash (`—`, U+2014) with a single space on each side, and a status word from this vocabulary:

  - per-task `status == "completed"` → render `done`
  - per-task `status == "pending"`, `"in_progress"`, `"failed"`, or `"needs_input"` → render `pending`
  - per-task `status == "skipped"` → render `skipped`

  The three-word rendered vocabulary (`done` / `pending` / `skipped`) is normative; do not surface richer statuses in this step.

  **Task-file drift check.** For each task `N-M` listed under `state.phases["N"].tasks`, if `.oberon/phases/N/N-M.md` does not exist, still emit the task row — use `<missing title>` in place of the title (everything else unchanged: id, em-dash, mapped status) — and immediately after the row emit an inline warning on its own line:

  ```
  warning: state.json references phases/N/N-M.md but file is missing
  ```

  Then continue with the next task row. Use the path form `phases/N/N-M.md` (relative to `.oberon/`) verbatim in the warning.

The per-phase block is a single contiguous group of lines — no blank line between phases, no blank line between a phase header and its task rows, no blank line before or after an inline warning. A medium plan (3 phases × 4 tasks) must fit in one glance.

### Step 3d — Blank line separator

Insert exactly one blank line between the status block (header + per-phase block, including any inline warnings) and the final Next advisory.

---

## Step 4 — Next advisory (active project)

Emit exactly one Next advisory as the final line of output. The mapping is exhaustive — pick the first matching rule:

1. `state.phase == "initialized"` → `Next: run /obr-spec`
2. `state.phase == "grilled"` → `Next: run /obr-plan`
3. `state.phase == "prd-done"` → `Next: run /obr-phase 1`
4. `state.phases` exists and every phase is `completed` or `skipped`, AND every task inside every non-skipped phase has status `completed` → `Next: run /obr-archive`
5. `state.phase == "done"` → `Next: run /obr-archive`
6. `state.phases` exists and at least one phase is still non-terminal → `Next: run /obr-phase N`, where `N` is the lowest-numbered phase whose `status` is neither `completed` nor `skipped`.

All advisories follow the normative format: lowercase `run`, slash-prefixed command, no backticks, no trailing period, single line. Tasks inside skipped phases do **not** need to be `completed` for rule 4 to fire — a skipped phase's tasks are counted as resolved wholesale.

**Drift does not override the advisory.** Warnings emitted during Step 3b (unknown `state.phase`) or Step 3c (missing phase dir / task file) do not change the Next advisory — Step 4's rules still fire on whatever the state reports. The sole case that swaps the advisory is the Step 3a malformed-state branch, which has already emitted its own `Next: inspect .oberon/state.json` line and stopped before reaching Step 4.

**Fallback when no rule matches.** If `state.phase` is an unknown value and `state.phases` is absent (so rules 1–6 all fail), emit `Next: inspect .oberon/state.json` as the final line. This is the only non-`run` advisory Step 4 emits, and it signals "something is off, look at the file" in parallel with the malformed-state case.

---

## Rules (strict)

- **Read-only, even when inconsistency is detected.** `/obr-status` never writes, renames, or deletes any file — not to repair drift, not to rewrite malformed state, not ever.
- **Single Next advisory.** Exactly one Next line per invocation, as the final line of output.
- **Normative advisory format.** Lowercase `run`, slash-prefixed command, no backticks, no trailing period, single line. The malformed-state branch (Step 3a) and the unknown-phase-without-phases fallback (Step 4) use `Next: inspect .oberon/state.json` instead — sanctioned deviations.
- **Warning and error prefixes are normative.** Warning lines use the literal lowercase prefix `warning:`. Error lines use the literal lowercase prefix `error:`. Do not capitalize, do not translate, do not use alternative markers (no `WARN`, no `!`, no emoji).
- **No emoji. No ANSI color. No ASCII art.** Terse, single-purpose lines.
- **No commit SHAs, no timestamps inside the status block** (the uninitialized-path orienting line is the sole exception, and it reads from the manifest, not from `git`).
