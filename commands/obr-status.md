---
description: Report the current Oberon project's state (phase, per-task progress) and a concrete next-step advisory. Read-only — never mutates state.
---

You are handling the `/obr-status` command for Oberon.

## Your job

Print a compact, read-only snapshot of the current Oberon project's state, followed by a single-line Next advisory pointing at the concrete next command.

1. Detect whether `.oberon/` exists in the current working directory.
2. If it does not exist, render the uninitialized-directory output (Step 2 below).
3. If it does exist, render the active-project status block (extended by follow-on tasks; see "Active project" below).
4. Print exactly one Next advisory as the final line of output.

Do **not** write, rename, or delete any file. Do **not** modify `state.json`, phase files, or `PROJECT.md` under any circumstance. `/obr-status` is strictly read-only — even when inconsistency is detected.

---

## Step 1 — Detect initialization

Check whether `.oberon/` exists in the current working directory.

- If `.oberon/` does **not** exist, go to Step 2 (uninitialized path).
- If `.oberon/` exists, go to the "Active project" section below.

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

## Active project

When `.oberon/` exists, render the active-project status block. This path is scaffolded here and extended by follow-on tasks:

- Task 1-2 adds: read `state.json`, render a header line with project name and current `state.phase`, map pre-plan phases (`initialized`, `grilled`, `prd-done`) to their Next advisory, list phase/task progress when phase files are present, and emit `Next: run /obr-archive` when every task is `done`.
- Task 1-3 adds: warning lines for state/plan drift (missing phase directory or task file, unrecognized `state.phase`) and a single `error:` line plus `Next: inspect .oberon/state.json` when `state.json` is malformed or missing required fields.

Until those tasks land, the active-project branch is intentionally not implemented here.

---

## Rules (strict)

- **Read-only.** `/obr-status` never writes, renames, or deletes any file.
- **Single Next advisory.** Exactly one Next line per invocation, as the final line of output.
- **Normative advisory format.** Lowercase `run`, slash-prefixed command, no backticks, no trailing period, single line.
- **No emoji. No ANSI color. No ASCII art.** Terse, single-purpose lines.
- **No commit SHAs, no timestamps inside the status block** (the uninitialized-path orienting line is the sole exception, and it reads from the manifest, not from `git`).
