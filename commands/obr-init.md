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
4. Deriving the project slug (auto-generated — never an interview question)
5. Writing `.oberon/PROJECT.md` and `.oberon/state.json`
6. Appending `.oberon/` to `.gitignore` if one exists
7. Telling the user what's next

Do **not** implement features, write PRDs, or do anything beyond the steps above.

---

## Step 1 — Guard against re-init

Check whether `.oberon/` already exists in the current working directory.

- If `.oberon/` does **not** exist, proceed to Step 2 as normal.
- If `.oberon/` exists and its **only** top-level entry is `archived/` (a previously-archived, not-yet-re-initialized state, as produced by `/obr-archive`), treat this as a valid starting state: proceed to Step 2. Do **not** touch, move, or delete the `archived/` folder — later steps will write the new `PROJECT.md` and `state.json` alongside it.
- Otherwise (i.e. `.oberon/` exists and contains any top-level entry other than `archived/`), abort immediately with:

  > `.oberon/` already exists. Delete it to re-initialize, or run `/obr-spec` to continue.

  Do nothing else. Do not proceed.

"Top-level entry" means any immediate child of `.oberon/` — files or directories, including dotfiles. `archived/` must be the single entry for the bypass to apply; if `archived/` is present alongside anything else, the abort path above still fires.

---

## Step 2 — Resolve arguments

The argument to `/obr-init` is `$ARGUMENTS`. Resolve it in two sub-steps: first pull out the optional `--name <slug>` override, then resolve whatever remains as seed input.

### Step 2a — Extract `--name <slug>` (optional)

Scan `$ARGUMENTS` for a `--name <slug>` token pair. The slug is the next whitespace-delimited token after `--name`; it is a single argument, not a quoted phrase.

- **If `--name` is not present**: no override; `<name-override>` is unset. Proceed to Step 2b with `$ARGUMENTS` unchanged.
- **If `--name` is present but no value follows it** (end of string, or followed by another `--flag`): abort with:

  > `--name` requires a slug argument. Format rules: lowercase ASCII letters, digits, and hyphens only; shape `^[a-z0-9]+(-[a-z0-9]+)*$`; ≤ 40 characters.

  Do not create `.oberon/`, do not write `state.json` or `PROJECT.md`, do not proceed.
- **If `--name` is present with a value**: validate that value against the **Slug validation rules** in Step 4. User-supplied slugs are not truncated — they either satisfy the rules or are rejected. If the value does **not** satisfy the rules, abort with:

  > `--name <slug>` is not a valid project slug. Format rules: lowercase ASCII letters, digits, and hyphens only; shape `^[a-z0-9]+(-[a-z0-9]+)*$`; ≤ 40 characters. No leading, trailing, or doubled hyphens.

  Do not create `.oberon/`, do not write `state.json` or `PROJECT.md`, do not proceed.

  If the value satisfies the rules, remember it as `<name-override>` and **remove the `--name <slug>` token pair from `$ARGUMENTS`** before Step 2b.

When `<name-override>` is set, Step 4's derivation flow is skipped entirely — no LLM slug generation, no cwd-basename fallback, no last-resort constant. `<name-override>` is used as the final slug verbatim.

### Step 2b — Resolve seed input

Using the argument string with any `--name <slug>` token pair already stripped, resolve the seed:

- **If empty**: no seed input. Proceed to Step 3 with no seed.
- **If it looks like a path AND the file exists and is readable**: read the file; its contents are the seed.
- **Otherwise**: treat the entire remaining argument as an inline seed description.

A "looks like a path" heuristic: the argument has no spaces or contains `/`, `./`, `.md`, `.txt`, or similar, AND `test -f` returns true.

Record which form was used — you'll need it for `state.json`. `--name` composes with every seed mode (file path, inline, none): the seed still drives the grill in Step 3; only slug derivation in Step 4 is short-circuited.

---

## Step 3 — Run the grill

Invoke the `obr-grill` skill, passing the seed content (or a note that there is no seed).

Follow the skill's rules strictly: terse one-question-per-turn interview. Only grill gaps the seed doesn't already answer.

**Do not ask the user for a project name.** The slug is derived automatically in Step 4 — it is never an interview question, never a grill branch, and never a standalone prompt.

### Detecting the end of the grill

The grill is "over" when you have enough decisions to write PROJECT.md (every meaningful branch resolved).

At that point the user has just given their last answer. Do **not** ask another question. Do **not** wait for acknowledgement. The next thing you produce in the same turn is:

1. The Overview / Decisions / Open Questions block (for display AND for embedding into PROJECT.md).
2. The slug derivation in Step 4 and the tool calls in Steps 5–7 below.

### Hard rule — no stopping after the grill block

The grill's output block is **not a final message**. It is an intermediate handoff. If you emit the block and stop, the project is broken: no `.oberon/` directory, no `state.json`, `/obr-spec` will fail. This is a command contract violation.

Every turn in which you emit the grill block **must also** contain (in this order, same turn):
- Derive the slug per Step 4.
- `mkdir -p .oberon` (via Bash)
- `Write .oberon/PROJECT.md`
- `Write .oberon/state.json`
- The `.gitignore` check from Step 6
- The confirmation from Step 7

If you find yourself about to end a turn right after emitting the Overview/Decisions block, **stop — you are bugging out**. Continue with Steps 4–7 in the same turn.

---

## Step 4 — Derive the project slug

The project slug is auto-generated. Never prompt the user for it.

### Slug validation rules (normative)

These rules are the single source of truth for every slug handled by `/obr-init` — both the auto-generated path (this step) and the `--name <slug>` override path (Step 2a). Any code path that produces or accepts a slug **must** apply these rules:

- **Character set:** lowercase ASCII letters, digits, and hyphens only.
- **Shape:** matches the regex `^[a-z0-9]+(-[a-z0-9]+)*$` — one or more alphanumeric segments joined by single hyphens, no leading/trailing/doubled hyphens.
- **Length cap:** ≤ 40 characters.
- **Truncation:** if the initial draft exceeds 40 characters, truncate at a hyphen boundary — cut at the last `-` that keeps length ≤ 40, then drop the trailing hyphen. Never cut mid-word.
- **Non-empty:** a slug with zero characters after normalization is invalid; fall back to the next source below.

Call this section **"Slug validation rules"** and reference it from any other step that needs slug validation; do not re-state the rules elsewhere in this command.

### Derivation flow

If Step 2a set `<name-override>`, **skip this entire derivation flow**. The slug is `<name-override>` verbatim; it has already been validated in Step 2a against the Slug validation rules above. Do not run LLM slug generation, do not fall back to cwd basename, do not emit a fallback note in Step 7 (the user picked the name; there is no "fallback" to disclose).

Otherwise, pick the first path that produces a slug matching the Slug validation rules:

1. **Seed path (LLM-generated).** If a seed is present (from Step 2b, `type: file` or `type: inline`), generate a kebab-case slug from the seed content. The slug should reflect the project's purpose in 2–5 words. Apply the Slug validation rules, including word-boundary truncation. If the first draft does not validate even after truncation, fall through to step 2.
2. **cwd-basename fallback.** Take the basename of the current working directory. Lowercase it, strip non-ASCII, replace every run of non-alphanumeric characters with a single hyphen, and trim leading/trailing hyphens. Apply the Slug validation rules, including word-boundary truncation. If this still does not validate (e.g., basename is empty or purely non-ASCII after stripping), fall through to step 3.
3. **Last-resort constant.** Use the literal slug `oberon-project`.

Record which path produced the slug — you will need it for the confirmation message in Step 7 when a non-primary path was taken:

- `<name-override>` supplied → override path; no fallback note needed.
- Seed present and step 1 succeeded → primary path; no fallback note needed.
- No seed at all → cwd-basename is the primary path; no fallback note needed.
- Seed present but step 1 failed → note that LLM slug generation failed and the cwd basename was used instead.
- Both failed → note that both LLM generation and cwd basename failed and the last-resort slug was used.

The chosen slug is the value of `<slug>` for the remainder of the command.

---

## Step 5 — Create `.oberon/` and write files

Create the directory:

```bash
mkdir -p .oberon
```

### Write `.oberon/PROJECT.md`

Structure:

```markdown
# <slug>

<Overview / Decisions / Open Questions block emitted by obr-grill, verbatim>
```

The first-line `# <slug>` heading is the slug chosen in Step 4 — written verbatim, no rewording, no casing changes.

### Write `.oberon/state.json`

Schema (v1):

```json
{
  "version": 1,
  "phase": "grilled",
  "created_at": "<ISO-8601 UTC timestamp, now>",
  "updated_at": "<same timestamp>",
  "project_name": "<slug>",
  "source": {
    "type": "file" | "inline" | "none",
    "path": "<original path or null>"
  }
}
```

`project_name` is the slug from Step 4, written verbatim. Use actual UTC timestamps (e.g. `2026-04-17T14:32:01Z`). Both `created_at` and `updated_at` are the same at init.

Both writes happen in the same turn as the slug derivation — `state.json.project_name` and `PROJECT.md`'s first-line heading always agree.

---

## Step 6 — `.gitignore`

If `.gitignore` exists in the current working directory:

- Read it.
- If it already contains a line that matches `.oberon/` (allowing trailing slash variants — `.oberon`, `.oberon/`), leave it alone.
- Otherwise, append a newline + `.oberon/` to it.

If `.gitignore` does **not** exist, do nothing. Do not create one.

---

## Step 7 — Tell the user what's next

Print a short confirmation that announces the auto-generated slug and reminds the user how to override it. Do **not** ask for approval — no `[y/N]`, no pause, no waiting.

Format:

> Oberon initialized as `<slug>`. Decisions captured in `.oberon/PROJECT.md`.
>
> If the name is wrong, re-run `/obr-init --name <your-slug>`.
>
> Next: run `/obr-spec` to generate the PRD.

Substitute `<slug>` with the verbatim slug from Step 4.

If a non-primary derivation path was taken (per Step 4's recording), insert a single advisory line directly after the first line, before the `--name` reminder:

- Seed was provided but LLM generation failed → `LLM slug generation failed; fell back to the current directory name.`
- Seed was provided but both LLM generation and cwd basename failed → `LLM slug generation and cwd-basename fallback failed; used the last-resort slug.`

If the primary path succeeded, emit the three-line form above with no fallback advisory.

Keep it tight. No long summary. No approval prompt.

---

## Errors to handle explicitly

- `.oberon/` already exists → abort, see Step 1.
- `--name` present with no value, or with a value that fails the Slug validation rules → abort, see Step 2a. Do not write `.oberon/`, `state.json`, or `PROJECT.md`.
- Argument is a path but the file is unreadable → tell the user and stop (don't silently fall through to inline).
- `obr-grill` skill unavailable → stop and tell the user to run `install.sh`.

Do not proceed past a hard error.
