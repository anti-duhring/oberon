---
description: Decompose `.oberon/PRD.md` into an executable phase/task plan. Writes `.oberon/phases/N/N-M.md` files and updates `state.json`. Runs after `/obr-spec`, before `/obr-phase N`.
---

You are handling the `/obr-plan` command for Oberon — Phased Execution.

## Your job

Turn the completed PRD into a plan the executor can run. Steps:

1. Validate preconditions
2. Invoke the `obr-planner` skill interactively
3. Confirm files written and state updated
4. Tell the user what's next

Do **not** start implementing the PRD. Do **not** spawn executors. This command only plans.

---

## Step 1 — Validate preconditions

Check, in order:

1. `.oberon/` must exist. If not:
   > No `.oberon/` directory found. Run `/obr-init` first.
   Stop.

2. `.oberon/state.json` must exist and be readable. If not:
   > `.oberon/state.json` missing or unreadable. Re-run `/obr-init` after deleting `.oberon/`.
   Stop.

3. `.oberon/PRD.md` must exist and be readable. If not:
   > No PRD found. Run `/obr-spec` first.
   Stop.

4. `state.phase` must equal `"prd-done"`. If it's anything else:
   - If `"planned"`, `"executing"`, or a phase-level status: "Project is already planned (phase=`<value>`). Delete `.oberon/phases/` and reset `state.phase` to `prd-done` to re-plan."
   - Otherwise: "Project is not in a `prd-done` state (phase=`<value>`). Expected to run after `/obr-spec` completes."
   Stop.

5. `.oberon/phases/` must **not** already exist. If it does:
   > `.oberon/phases/` already exists. Delete it and reset `state.phase` to `prd-done` to re-plan.
   Stop.

Hard errors abort the command. Do not silently proceed.

---

## Step 2 — Invoke the plan skill

Invoke the `obr-planner` skill. It reads `.oberon/PRD.md`, proposes a phase split, discovers verification commands, and writes task files plus the updated `state.json`.

The skill runs two interactive rounds (phase split, verification commands). Let it drive. Do not answer on the user's behalf — wait for their reply. Do not pad the skill's questions with preamble.

**Do not stop here.** The skill's output is an intermediate artifact. Once the skill has written files and updated state, proceed immediately to Steps 3–4 **in the same turn**. Stopping mid-flow leaves the project in an inconsistent state.

---

## Step 3 — Sanity-check the result

After the skill returns, verify:

- `.oberon/phases/` exists and contains at least one `N-M.md` file.
- `.oberon/state.json` has `phase == "planned"`, a `verification_commands` array, and a `phases` object with at least one phase and one task.

If either check fails, stop and report the specific discrepancy. Do not attempt to repair.

---

## Step 4 — Tell the user what's next

Print a short confirmation — exactly two lines: one "what happened" line plus the normative advisory line. Example:

> Planned: 2 phase(s), 7 task(s). Verification: `npm test`, `npm run lint`.
>
> Next: run /clear to reset context, then /obr-phase 1

The advisory line is **normative**: lowercase `r` in `run`, slash-prefixed commands (no backticks), simple comma-separated clauses (no em-dash), no trailing period, single line. Do **not** invoke `/clear` automatically — the hint is advisory only. No multi-paragraph rationale, no extra emoji.

Keep it tight. No long summary.

---

## Errors to handle explicitly

- Any precondition in Step 1 fails → hard stop with the specific message above.
- `obr-planner` skill unavailable → stop and tell the user to run `install.sh`.
- User aborts the plan interview → do not write partial task files. Do not update `state.json`. Leave the project in `prd-done` so `/obr-plan` can be retried. Remove any partially-written files under `.oberon/phases/` before returning.
