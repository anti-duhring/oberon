---
description: Generate a PRD for the initialized Oberon project. Runs the `obr-prd` skill using `.oberon/PROJECT.md` as input and writes `.oberon/PRD.md`.
---

You are handling the `/obr-spec` command for Oberon.

## Your job

Generate a Product Requirements Document for the project that was set up by `/obr-init`.

1. Validate preconditions (state and file existence)
2. Invoke the `obr-prd` skill interactively
3. Write `.oberon/PRD.md`
4. Update `.oberon/state.json`
5. Tell the user what's next

Do **not** start implementing anything the PRD describes.

---

## Step 1 — Validate preconditions

Check, in order:

1. `.oberon/` must exist. If not:
   > No `.oberon/` directory found. Run `/obr-init` first.
   Stop.

2. `.oberon/state.json` must exist and be readable. If not, the project is in a broken state:
   > `.oberon/state.json` missing or unreadable. Re-run `/obr-init` after deleting `.oberon/`.
   Stop.

3. `state.phase` must equal `"grilled"`. If it's anything else (`"initialized"`, `"prd-done"`, or unknown):
   - If `"prd-done"`: "PRD already generated. Delete `.oberon/PRD.md` to regenerate."
   - Otherwise: "Project is not in a `grilled` state (phase=`<value>`). Expected to run after `/obr-init` completes."
   Stop.

4. `.oberon/PROJECT.md` must exist and be readable. If not, stop with an error pointing the user at re-initialization.

5. `.oberon/PRD.md` must **not** already exist. If it does:
   > `.oberon/PRD.md` already exists. Delete it to regenerate.
   Stop.

Hard errors abort the command. Do not silently proceed.

---

## Step 2 — Invoke the PRD skill

Read `.oberon/PROJECT.md` in full. Then invoke the `obr-prd` skill with that content as the input.

`obr-prd` is interactive: it will ask 3–5 targeted clarifying questions to fill gaps that PROJECT.md doesn't already answer. Let it drive. Do not answer its questions on the user's behalf — wait for the user's reply.

### Detecting the end of the PRD interview

The interview is over the moment the user replies to the clarifying questions. `obr-prd` asks questions in a single batch, so there is exactly one user reply to wait for. After that reply, do **not** ask follow-ups and do **not** wait for acknowledgement.

### Hard rule — no stopping after the PRD is produced

The PRD document is **not a final message**. The user's last input during `/obr-spec` is their reply to `obr-prd`'s clarifying questions — everything after that is your job, and it must happen in the same turn as you generate the PRD.

Every turn that generates the PRD content **must also** contain (in this order, same turn):
- `Write .oberon/PRD.md`
- The state update from Step 4 (`Write .oberon/state.json` with `phase: "prd-done"`)
- The confirmation from Step 5

If you find yourself about to end a turn right after producing the PRD body without writing it to disk and updating state, **stop — you are bugging out**. Continue with Steps 3–5 in the same turn. Stopping early leaves the project in an inconsistent state (no `.oberon/PRD.md`, `state.json` still in `grilled` phase) and breaks this command's contract.

---

## Step 3 — Write `.oberon/PRD.md`

Save the PRD to `.oberon/PRD.md`. Single file. Do not create any subdirectories. Do not write to `tasks/` even if the skill's instructions reference it — Oberon's canonical path is `.oberon/PRD.md`.

---

## Step 4 — Update state

Update `.oberon/state.json`:

- `phase` → `"prd-done"`
- `updated_at` → new ISO-8601 UTC timestamp
- All other fields unchanged

Write atomically (write to a temp file, rename) if practical — otherwise a straight overwrite is acceptable.

---

## Step 5 — Confirm

Print a short message:

> PRD written to `.oberon/PRD.md`. Phase: `prd-done`.

Keep it tight.

---

## Errors to handle explicitly

- Any precondition in Step 1 fails → hard stop with the specific message above.
- `obr-prd` skill unavailable → stop and tell the user to run `install.sh`.
- User aborts the PRD interview → do not write a partial PRD. Do not update `state.json`. Leave the project in `grilled` phase so `/obr-spec` can be retried.
