---
description: Execute (or skip) a phase produced by `/obr-plan`. Runs every task in phase `N` sequentially via fresh executor subagents. Usage — `/obr-phase N` to run, `/obr-phase N skip` to mark skipped.
argument-hint: "N [skip]"
---

You are handling the `/obr-phase` command for Oberon — Phased Execution.

## Your job — two modes

- **Execute mode** (`/obr-phase N`): run every task in phase `N` sequentially, spawning a fresh executor subagent per task. Resume from the first non-completed task if re-run.
- **Skip mode** (`/obr-phase N skip`): mark phase `N` as skipped in `state.json` after confirmation. Do not run any tasks.

You are the **main agent**. You coordinate. You do not implement tasks yourself — executors do. You are the only thing that talks to the user.

---

## Step 0 — Parse arguments

`$ARGUMENTS` is the raw argument string. Parse:

- First whitespace-separated token must be a positive integer `N`. If not, stop with:
  > Usage: `/obr-phase N` or `/obr-phase N skip`
- Second token, if present, must be the literal string `skip`. Any other second token is invalid; stop with the same usage message.
- No extra tokens allowed.

---

## Step 1 — Shared preconditions

Check, in order (applies to both modes):

1. `.oberon/` and `.oberon/state.json` exist and are readable. If not:
   > No Oberon project found (or state is missing). Run `/obr-init` → `/obr-spec` → `/obr-plan` first.
   Stop.

2. `state.phase` must be `"planned"` or `"executing"` (i.e. a plan exists). If it is `"grilled"`, `"prd-done"`, or missing:
   > Project is not planned yet (phase=`<value>`). Run `/obr-plan` first.
   Stop.

3. `state.phases["<N>"]` must exist. If not:
   > Phase `N` does not exist in the plan. Valid phases: <list keys of state.phases>.
   Stop.

---

## Step 2 — Skip mode (if the second token is `skip`)

If the current status of phase `N` is `"completed"` or `"skipped"`, emit a no-op message and stop:

> Phase `N` is already `<status>`. Nothing to do.

Otherwise, ask the user to confirm, exactly once:

> Mark phase `N` as **skipped**? This will unblock phase `N+1` without running any tasks. (y/N)

Only `y` / `yes` (case-insensitive) proceeds. Anything else stops with "Aborted. No changes made." — do not mutate state.

On confirmation:

- Set `state.phases["<N>"].status = "skipped"`.
- Set `state.phases["<N>"].completed_at` to a fresh ISO-8601 UTC timestamp.
- Update `state.updated_at`.
- Persist.

Emit:

> Phase `N` skipped. Next: `/obr-phase <N+1>` (if planned).

Stop. Do not fall through to execute mode.

---

## Step 3 — Execute mode: additional preconditions

These only apply when running (not skipping):

1. **Out-of-order refusal.** If `N > 1`, phase `N-1` must be `"completed"` or `"skipped"`. If not:
   > Phase `N-1` is `<status>`. Finish it with `/obr-phase <N-1>` or mark it skipped with `/obr-phase <N-1> skip` before running `/obr-phase <N>`.
   Stop. Do not mutate state.

2. **Current-phase status gate.** If phase `N` is already `"completed"`:
   > Phase `N` is already completed. Nothing to do.
   Stop.

   If phase `N` is `"skipped"`:
   > Phase `N` was skipped. It cannot be executed without resetting its status in `state.json`.
   Stop.

3. **Dirty working tree is a hard abort.** Run `git status --porcelain`. If the output is non-empty:
   > Working tree is dirty. Commit or stash changes before running `/obr-phase N`.
   Stop. Do not mutate state. Do not offer to stash.

4. **Verification commands.** `state.verification_commands` must be present (may be an empty array if the user disabled verification during `/obr-plan`). If missing entirely, stop:
   > `state.verification_commands` missing. Re-run `/obr-plan` to configure verification.
   Stop.

---

## Step 4 — Determine starting task (resume)

List `state.phases["<N>"].tasks` in task-ID order (`N-1`, `N-2`, …). The starting task is the first one whose `status` is not `"completed"`.

- If every task is already `"completed"`, jump to Step 7 (phase-level verification + completion).
- Otherwise, count how many tasks are already completed and emit a one-line resume summary **only if** at least one is done:

  > Resuming phase `N`: `<done>`/`<total>` tasks already completed.

  On a fresh run (nothing done), emit instead:

  > Starting phase `N`: `<total>` task(s).

Set `state.phase = "executing"`. Set `state.phases["<N>"].status = "in_progress"` (if not already). Set `state.phases["<N>"].started_at` if null. Persist before spawning the first executor.

---

## Step 5 — Per-task execution loop

For each task starting from the computed task, in order:

### 5a. Mark the task in-progress

- Set `state.phases["<N>"].tasks["<N-M>"].status = "in_progress"`.
- Set `started_at` if null.
- Clear `last_error` and `last_question` — we are about to try again.
- Persist.

### 5b. Spawn a fresh executor

Spawn a **fresh subagent** per task (never reuse an executor across tasks). Pass the `obr-executor` skill and these inputs:

- `task_file` — absolute path to `.oberon/phases/<N>/<N-M>.md`
- `phase_number` — `N`
- `task_id` — `"N-M"`
- `verification_commands` — the array from `state.verification_commands`
- `state_file` — absolute path to `.oberon/state.json`
- `resume_answer` — optional; set only when the previous return was `needs_input` and the user has now answered

Use the Agent tool (or an equivalent subagent-spawning mechanism). Do not implement the task yourself. Stream the subagent's verification output to the user in real time — that's the whole point of spawning it live.

### 5c. Handle the executor's return payload

**`status: "success"`**

- Set `tasks["<N-M>"].status = "completed"`, `completed_at` = now, `commit_sha`, `rewrite_commit_sha`.
- Persist.
- Emit a one-line per-task marker, e.g. `✓ [N-M] <title> — <short-sha>`.
- Continue to the next task.

**`status: "failed"`**

- Set `tasks["<N-M>"].status = "failed"`.
- Set `tasks["<N-M>"].last_error = { summary, detail }` from the payload.
- Persist.
- Surface the failure to the user:

  > ✗ [N-M] failed — `<error.summary>`
  >
  > (relevant detail, verbatim, trimmed to a reasonable length)
  >
  > Choose: **retry**, **skip**, or **abort**?

- Wait for the user's choice. Only these three words (case-insensitive) are valid.
  - **retry** → go back to 5a for the same task. Fresh executor.
  - **skip** → set `tasks["<N-M>"].status = "skipped"`, `completed_at` = now, persist, continue to the next task. (A skipped task inside a phase does NOT count as "completed" for the phase-completion gate — see Step 7.)
  - **abort** → stop immediately. Do not touch phase status. Do not mutate further. Emit `Aborted at [N-M]. Re-run /obr-phase N to resume.` and return.

**`status: "needs_input"`**

- Set `tasks["<N-M>"].status = "needs_input"`.
- Set `tasks["<N-M>"].last_question = question`.
- Persist.
- Prompt the user verbatim with the executor's question. Wait for their reply.
- Once the user replies, go back to 5a for the same task with `resume_answer` set to the user's reply. Fresh executor.

---

## Step 6 — All tasks processed

After the loop completes without an abort, proceed to Step 7. If the user aborted mid-loop, you have already returned.

---

## Step 7 — Phase-level verification & completion

Before marking the phase completed, run one final pass of `state.verification_commands`, in order, directly from the main agent (no executor needed for this — we already know the tree is clean and every task passed its own verification).

- Stream output to the user.
- If any command exits non-zero:
  - Leave `state.phases["<N>"].status = "in_progress"`.
  - Set `state.phases["<N>"].last_error = { summary, detail }` (same shape as task failures).
  - Persist.
  - Surface the failure to the user with the same **retry / skip / abort** choice as per-task failures:
    - **retry** → re-run the phase-level verification (do not re-run tasks).
    - **skip** → refuse. Phase-level verification failure cannot be skipped at this level; the user must fix the underlying issue or abort. Re-prompt.
    - **abort** → stop with `Phase N not marked completed. Re-run /obr-phase N once the issue is fixed.`
- If `verification_commands` is empty, skip this step entirely and proceed.

On success (or empty verification list):

- Set `state.phases["<N>"].status = "completed"`, `completed_at` = now.
- Set `state.phase = "planned"` again (so state.phase tracks "a plan exists, phase-level progress lives in state.phases"). If `N` is the final planned phase and every other phase is `completed` or `skipped`, set `state.phase = "done"` instead.
- Clear any phase-level `last_error`.
- Persist.

Emit a phase summary:

> Phase `N` completed.
>
>   ✓ [N-1] <title> — <sha>
>   ✓ [N-2] <title> — <sha>
>   · [N-3] <title> — skipped
>   …

---

## Step 8 — Auto-propose next phase

If `state.phases["<N+1>"]` exists, ask the user to confirm — do not run it automatically:

> Run `/obr-phase <N+1>` next? (y/N)

Only `y` / `yes` (case-insensitive) triggers execution. On `y`, re-enter this command with `N+1` from Step 1 (shared preconditions onward). On anything else, stop with:

> Stopping after phase `N`. Run `/obr-phase <N+1>` when ready.

If `state.phases["<N+1>"]` does not exist:

> All planned phases are complete. Nothing further to do.

---

## Persistence rules (apply everywhere)

- Every state transition (task start, task complete, task failure, task needs_input, task skipped, phase start, phase complete, phase skipped, phase failure) **must be persisted to `state.json` before control returns to the user** — including while waiting for a retry/skip/abort choice or a `needs_input` answer.
- Always update `state.updated_at` when writing.
- Write atomically (temp file + rename) when practical.
- Never lose a commit SHA — capture it the moment the executor returns, not later.

---

## Output style

- One line per state change. One line per task completion.
- One line for the resume summary. One short block for the phase summary.
- Executor verification output is streamed verbatim — do not paraphrase it.
- No long narration between tasks. Silence between state-change lines is fine.

---

## Errors to handle explicitly

- Bad arguments → usage message from Step 0.
- Shared precondition failure → stop with the specific message from Step 1.
- Out-of-order invocation → hard refuse per Step 3.1; no state mutation.
- Dirty working tree → hard abort per Step 3.3; no state mutation.
- `obr-executor` skill unavailable → stop and tell the user to run `install.sh`.
- Mid-loop crash / session exit → state is already persisted; re-running `/obr-phase N` will resume.
