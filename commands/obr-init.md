---
description: Initialize an Oberon project. Runs a terse design grill, then writes `.oberon/PROJECT.md` and `.oberon/state.json`. Accepts an optional file path or inline description.
argument-hint: "[file-path | inline description]"
---

You are handling the `/obr-init` command for Oberon — a meta-prompting, context-engineering, spec-driven development workflow.

## Your job

Initialize an Oberon project in the current working directory by:

1. Validating preconditions
2. Resolving seed input (file path, inline text, or none)
3. Running the **obr-grill** skill against that seed
4. Writing `.oberon/PROJECT.md` and `.oberon/state.json`
5. Appending `.oberon/` to `.gitignore` if one exists
6. Telling the user to run `/obr-spec`

Do **not** implement features, write PRDs, or do anything beyond the steps above.

---

## Step 1 — Guard against re-init

Check if `.oberon/` already exists in the current working directory.

If it exists, abort immediately with:

> `.oberon/` already exists. Delete it to re-initialize, or run `/obr-spec` to continue.

Do nothing else. Do not proceed.

---

## Step 2 — Resolve seed input

The argument to `/obr-init` is `$ARGUMENTS`. Handle it as follows:

- **If empty**: no seed input. Proceed to Step 3 with no seed.
- **If it looks like a path AND the file exists and is readable**: read the file; its contents are the seed.
- **Otherwise**: treat the entire argument as an inline seed description.

A "looks like a path" heuristic: the argument has no spaces or contains `/`, `./`, `.md`, `.txt`, or similar, AND `test -f` returns true.

Record which form was used — you'll need it for `state.json`.

---

## Step 3 — Run the grill

Invoke the `obr-grill` skill, passing the seed content (or a note that there is no seed).

Follow the skill's rules strictly: terse one-question-per-turn interview. Only grill gaps the seed doesn't already answer.

You also need a **project name**. If the seed or the grill didn't surface one, ask explicitly as the final grill question: "What should this project be called? (short name, used as the title of PROJECT.md)".

### Detecting the end of the grill

The grill is "over" when **both** are true:
- You have enough decisions to write PROJECT.md (every meaningful branch resolved).
- You have a project name.

At that point the user has just given their last answer. Do **not** ask another question. Do **not** wait for acknowledgement. The next thing you produce in the same turn is:

1. The Overview / Decisions / Open Questions block (for display AND for embedding into PROJECT.md).
2. The tool calls in Steps 4–6 below.

### Hard rule — no stopping after the grill block

The grill's output block is **not a final message**. It is an intermediate handoff. If you emit the block and stop, the project is broken: no `.oberon/` directory, no `state.json`, `/obr-spec` will fail. This is a command contract violation.

Every turn in which you emit the grill block **must also** contain (in this order, same turn):
- `mkdir -p .oberon` (via Bash)
- `Write .oberon/PROJECT.md`
- `Write .oberon/state.json`
- The `.gitignore` check from Step 5
- The confirmation from Step 6

If you find yourself about to end a turn right after emitting the Overview/Decisions block, **stop — you are bugging out**. Continue with Steps 4–6 in the same turn.

---

## Step 4 — Create `.oberon/` and write files

Create the directory:

```bash
mkdir -p .oberon
```

### Write `.oberon/PROJECT.md`

Structure:

```markdown
# <project name>

<Overview / Decisions / Open Questions block emitted by obr-grill, verbatim>
```

### Write `.oberon/state.json`

Schema (v1):

```json
{
  "version": 1,
  "phase": "grilled",
  "created_at": "<ISO-8601 UTC timestamp, now>",
  "updated_at": "<same timestamp>",
  "project_name": "<name>",
  "source": {
    "type": "file" | "inline" | "none",
    "path": "<original path or null>"
  }
}
```

Use actual UTC timestamps (e.g. `2026-04-17T14:32:01Z`). Both `created_at` and `updated_at` are the same at init.

---

## Step 5 — `.gitignore`

If `.gitignore` exists in the current working directory:

- Read it.
- If it already contains a line that matches `.oberon/` (allowing trailing slash variants — `.oberon`, `.oberon/`), leave it alone.
- Otherwise, append a newline + `.oberon/` to it.

If `.gitignore` does **not** exist, do nothing. Do not create one.

---

## Step 6 — Tell the user what's next

Print a short confirmation. Example:

> Oberon initialized. Decisions captured in `.oberon/PROJECT.md`.
>
> Next: run `/obr-spec` to generate the PRD.

Keep it tight. No long summary.

---

## Errors to handle explicitly

- `.oberon/` already exists → abort, see Step 1.
- Argument is a path but the file is unreadable → tell the user and stop (don't silently fall through to inline).
- `obr-grill` skill unavailable → stop and tell the user to run `install.sh`.

Do not proceed past a hard error.
