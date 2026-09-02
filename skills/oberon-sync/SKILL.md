---
name: oberon-sync
description: Append one dated PROGRESS.md journal entry for an Oberon project from observable git evidence. Use after a meaningful chunk of implementation or when the working tree's story has moved on. Reads the last entry first and no-ops when nothing observable changed. Never rewrites prior entries.
---

# oberon-sync

Append one dated entry to the store's `PROGRESS.md` and rewrite the short `## Current state` header. Intent comes from the conversation; **spine** comes from `oberon repo-info` per contributing repo. No confirmation gate — but the no-op check is mandatory. Never raw `git` for store commits; never hand-edit `project.json`.

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
- None → direct the user to `oberon-init`; stop.

Store dir: `oberon path <id>`. Read `project.json` only via that path (or `cat` the file) for `contributing_repos` — do not rewrite the manifest here; use `oberon attach` if a repo is missing.

## No-op check (before any write)

1. Read `PROGRESS.md`.
2. Find the **last journal entry** (below the Current state header).
3. For each contributing repo path in the manifest, run:

   ```bash
   oberon repo-info "<PATH>"
   ```

   JSON fields: `path`, `remote`, `branch`, `sha`, `dirty` (boolean), `stat` (`--stat`-style summary).

4. **Do nothing** (no file edit, no commit) when nothing observable changed since that last entry, e.g.:
   - same branch + sha per repo, `dirty` still false, and no new meaningful intent to record; or
   - dirty snapshot already recorded for the same dirty shape and conversation has no new chunk.

   Tell the user you no-op'd and why, in one or two lines. Exit the skill cleanly.

5. Proceed only when branch/sha/dirty/stat moved, or the conversation completed a real chunk that is not yet reflected.

## File shape

`PROGRESS.md` layout:

```md
# <project title or tracker title>

<optional one-line legend / how to read status words>

## Current state

<few lines only — where we are NOW. Rewritten wholesale every sync.
 Never a status table. Never a growing log.>

## Journal

### YYYY-MM-DD HH:MM Z — <short title>

- **repo** `<path>` · branch `<b>` · sha `<full or 12+ abbrev>` · dirty `<true|false>
- stat: <stat summary or "clean">
- …

<prose: what changed, why it matters, evidence with path:line, tests run,
 blockers. One entry = one sync invocation.>
```

If the file still has a legacy layout, introduce `## Current state` and a journal section without rewriting old body text into fake history — leave prior prose in place and start appending dated entries below a clear journal heading.

### Rules

- **One dated entry per invocation.** Never edit an earlier journal entry. Corrections = new entry that says what changed about the earlier claim.
- **Rewrite `## Current state` wholesale** each successful sync. Hard-bound to a few lines: design settled?, code where?, what blocks next. Not a table of item statuses.
- **Spine every entry on repo-info.** For each contributing repo touched (at least every repo in the manifest that participated, or all of them if unsure), record path, branch, sha, dirty, stat.
- **Dirty trees:** if `dirty` is true, the entry **MUST** say it is a **snapshot of unsaved work**, not a verifiable reference — because `HEAD` predates the work described. Do not pretend the sha alone re-derives the change.
- **Observable density.** Prefer `path:line`, test counts, PR numbers, tag names. "Wired the store" is not enough; "store wired at `routes.go:630`, verified by …" is.
- UTC date in the heading (or local with explicit offset); keep it honest.

### Entry sketch

```md
### 2026-09-02 18:40Z — list route + 403 gate

- **repo** `/Users/…/spa-alt-120` · branch `feature/alt-120-reminders-list` · sha `12cf14c…` · dirty `false`
- stat: 4 files changed, 220 insertions(+)
- `GET /reminders` at `reminders/api.go:29` with `.With(aiInternal)`; 27/27 package tests pass.
- Gate test mutation-checked: drop middleware → fail, restore → pass.
```

Dirty example line:

```md
- **repo** `…/sar-alt-120` · branch `feature/…` · sha `3ece9baf…` · dirty `true`
- **unsaved work snapshot** — HEAD predates the edits below; not a verifiable pin until commit.
- stat: M internal/…/reminder_begin.go | …
```

## Write and commit

1. Update `## Current state`.
2. Append exactly one new journal entry.
3. Commit the store:

   ```bash
   oberon commit <id> -m "sync: <short title from entry>"
   ```

4. Report: id, whether dirty snapshots were flagged, one-line current state.

## Failures

- `repo-info` exit 5 (not a repo): record that path as missing/broken in the entry or current state; do not skip silently if the manifest still claims it.
- Unknown project id: exit path from `path` / resolve — stop and say so.