---
description: Archive the current Oberon project under `.oberon/archived/<timestamp>/`, append an entry to `.oberon/archived/manifest.json`, and print a short summary so a new project can be initialized in the same directory.
---

You are handling the `/obr-archive` command for Oberon.

## Your job

Preserve the current Oberon project state without leaving the working directory:

1. Validate that there is something to archive
2. Capture metadata from the current project (project name, phase, Overview)
3. Compute a UTC timestamp for the archive folder
4. Move every top-level entry of `.oberon/` (except `archived/`) into `.oberon/archived/<timestamp>/`
5. Append an entry to `.oberon/archived/manifest.json`
6. Print a concise summary and the `/obr-init` hint

Do **not** prompt the user for confirmation. Do **not** delete anything — files are moved, not removed. Do **not** modify entries that already exist in `manifest.json`.

---

## Step 1 — Precondition checks

Check, in order:

1. `.oberon/` must exist. If not, abort with:
   > Nothing to archive — `.oberon/` does not exist.
   Stop. Do not create any files.

2. `.oberon/` must contain at least one top-level entry. If it is empty, abort with:
   > Nothing to archive — `.oberon/` is empty.
   Stop. Do not create any files.

3. `.oberon/` must contain at least one top-level entry other than `archived/`. If the only entry is `archived/`, abort with:
   > Nothing to archive — no active project found.
   Stop. Do not create any files. Do not append to the manifest.

Hard errors abort the command with no filesystem changes.

---

## Step 2 — Capture pre-archive metadata

Read the following from the live `.oberon/` tree, **before** moving any files:

- **`project_name`**: the `project_name` field from `.oberon/state.json`. If `state.json` is missing, unreadable, or has no `project_name` field, fall back to the empty string `""`.
- **`phase`**: the `phase` field from `.oberon/state.json`. If `state.json` is missing, unreadable, or has no `phase` field, fall back to the literal string `"unknown"`.
- **`overview`**: the paragraph immediately under the `## Overview` heading in `.oberon/PROJECT.md`. If `PROJECT.md` is missing, unreadable, or contains no `## Overview` heading, fall back to the empty string `""`.

Hold these three values in memory; you will use them in Step 5 (manifest entry) and Step 6 (summary).

---

## Step 3 — Compute the archive timestamp

Generate a single UTC timestamp in the exact format `YYYY-MM-DDTHH-MM-SSZ` — ISO-8601, second precision, with colons replaced by dashes for filesystem safety on every platform.

Example shell:

```bash
TIMESTAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
```

Use the same `TIMESTAMP` value for the archive folder name and for the `timestamp` field in the manifest entry. Do not regenerate it later in the command.

---

## Step 4 — Move project files into the archive folder

Create the archive folder, creating `.oberon/archived/` first if it does not already exist:

```bash
mkdir -p ".oberon/archived/$TIMESTAMP"
```

Then move every top-level entry inside `.oberon/` into `.oberon/archived/$TIMESTAMP/`, **except** the `archived/` directory itself.

Each moved entry must keep its original name and internal structure — for example, `.oberon/PROJECT.md` becomes `.oberon/archived/$TIMESTAMP/PROJECT.md`, and `.oberon/plan/phase-1.md` becomes `.oberon/archived/$TIMESTAMP/plan/phase-1.md`.

Use atomic rename when source and destination share a filesystem (they will, since both live under `.oberon/`). Copy-then-delete is acceptable only as a fallback when rename is unavailable.

Do not transform the contents in any way — no compression, no encoding changes, no rewriting of file bodies.

After this step, `.oberon/` must contain only the `archived/` directory.

---

## Step 5 — Append a manifest entry

The manifest lives at `.oberon/archived/manifest.json` and is a top-level JSON array. Append exactly one new entry with this exact shape:

```json
{
  "timestamp": "<TIMESTAMP>",
  "project_name": "<project_name from Step 2>",
  "phase": "<phase from Step 2>",
  "path": "archived/<TIMESTAMP>"
}
```

Rules:

- If `manifest.json` does not exist, create it as a JSON array containing this single entry.
- If `manifest.json` exists and parses as a JSON array, read it, append the new entry to the end, and write the result back.
- If `manifest.json` exists but is unparseable JSON, overwrite it with a fresh JSON array containing only this single entry. The archive still succeeds; the corrupt prior history is treated as lost.
- Existing valid entries must never be modified or removed by this command — appends only.

Manifest writes must be atomic: write the full new contents to a temp file in `.oberon/archived/` (e.g. `manifest.json.tmp`), then rename the temp file over `manifest.json`. This prevents an interrupted write from leaving a truncated manifest.

The file must be valid JSON after the rename completes.

---

## Step 6 — Print the summary and next-step hint

Print a concise plain-text summary, in this order:

1. Project name (from Step 2 `project_name`).
2. Phase (from Step 2 `phase`).
3. The Overview paragraph (from Step 2 `overview`).

Example:

> Archived: `<project_name>`
>
> Phase: `<phase>`
>
> Overview:
> <overview paragraph>

Then, on a separate line below the summary, print:

> Run `/obr-init` to begin again.

Do **not** list every archived file. Do **not** use ANSI color codes or emoji. Keep the summary tight.

---

## Errors to handle explicitly

- `.oberon/` missing → hard stop with the Step 1.1 message. No files moved, no manifest entry added.
- `.oberon/` empty → hard stop with the Step 1.2 message. No files moved, no manifest entry added.
- `.oberon/` contains only `archived/` → hard stop with the Step 1.3 message. No files moved, no manifest entry added.
- `state.json` missing or unreadable → continue with the documented fallbacks (`project_name` = `""`, `phase` = `"unknown"`); do not abort.
- `PROJECT.md` missing or unreadable, or has no `## Overview` heading → continue with `overview` = `""`; do not abort.
- `manifest.json` unparseable → overwrite with a fresh single-entry array; the archive still succeeds.
- Move operation fails partway → stop and surface the error to the user. Do not append a manifest entry for a partial archive.
