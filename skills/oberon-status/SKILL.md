---
name: oberon-status
description: Read-only TLDR of the Oberon project(s) claiming the current repo, or of one project by id. Use when returning to a feature, before syncing, or anytime you need where things stand without opening store files. Never mutates the store.
---

# oberon-status

Render a hard-bounded TLDR of project state from `oberon status`. Read-only — no store writes, no commits, no confirmation gate. Safe to self-invoke any time.

## The `oberon` CLI

Call `oberon` from `PATH`. This skill only reads via the CLI. If the command is missing,
stop and tell the user to run `install.sh` from the Oberon repo — never fall back to raw
`git` or to opening store files by hand.

## Resolve and fetch

1. Explicit id argument → `oberon status <id>`
2. Else `$OBERON_PROJECT` → `oberon status "$OBERON_PROJECT"`
3. Else bare `oberon status` (every project whose manifest claims the current repo)

Call **once**. Do not prompt to disambiguate when several projects claim the repo — reporting all of them is correct. Never read store files directly; never run raw `git` — the JSON already carries branch/sha/dirty.

### Failures

- Exit **4** (no id, no matches): no project claims this repo. Tell the user and point at `oberon-init`. Stop.
- Exit **5** (explicit id unknown): say the id is unknown. Stop.

Stdout is always a JSON **array** (even for one project).

## Render (prose only)

For each project in the array, roughly six lines — no more:

1. **Headline** — `project_name` · `project_id` · `project_status` · age since `updated_at` (e.g. "updated 3h ago").
2. **Current state** — `progress.current_state` verbatim (or "(none)" when null).
3. **Decisions** — `decisions.count` and `decisions.last_ids` (e.g. "22 decisions; last D20 D21 D22"). Empty → "0 decisions".
4. **Last progress** — `progress.last_entry_heading`, or "(no journal entries)" when missing/`entry_count` is 0.
5. **Repos** — one line each: `name  branch@sha  clean|DIRTY`. When `exists` is false: `name  MISSING`. Prefer short sha as returned.
6. **Handoff** — if `handoff.present`: "handoff present, updated … ago"; else "no handoff".

### Call-outs the reader will otherwise get wrong

- **DIRTY** on a contributing repo means the last sync entry may describe work that is **not in any commit** (ADR-0013). Say so when any repo is dirty.
- A handoff whose `updated_at` is **older** than the newest progress signal (prefer comparing against `updated_at` of the project / last progress context in the payload) is **stale** — flag it.

Do not dump raw JSON. Do not expand into full decision text or full journal bodies.

## Close

End with **at most one** suggested next action, for example:

- any repo `dirty` → `/oberon-sync` (or `oberon-sync`) after the chunk lands in commits, or now if the dirty work is the story
- `decisions.count` is 0 → `/oberon-grill`
- handoff missing or stale and context is tight → `/oberon-handoff`
- otherwise omit the suggestion

This skill mutates nothing — never offer a commit.
