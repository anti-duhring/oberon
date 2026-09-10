---
name: oberon-status
description: Read-only TLDR of the Oberon project(s) claiming the current repo, or of one project by id. Use when returning to a feature, before syncing, or anytime you need where things stand without opening store files. Never mutates the store.
---

# oberon-status

Show the CLI's status card and add the reading a human would otherwise miss. Read-only — no store writes, no commits, no confirmation gate. Safe to self-invoke any time.

## The `oberon` CLI

Call `oberon` from `PATH`. This skill only reads via the CLI. If the command is missing,
stop and tell the user to run `install.sh` from the Oberon repo — never fall back to raw
`git` or to opening store files by hand.

## Resolve and fetch

1. Explicit id argument → `oberon card <id>`
2. Else `$OBERON_PROJECT` → `oberon card "$OBERON_PROJECT"`
3. Else bare `oberon card` (every project whose manifest claims the current repo)

Call **once**. Do not prompt to disambiguate when several projects claim the repo — the card renders one block per project, and reporting all of them is correct. Never read store files directly; never run raw `git` — the card already carries branch/sha/dirty.

`oberon status [ID]` returns the same data as a JSON array. Reach for it **only** when the user asks for something the card does not carry (exact timestamps, full `current_state`, `created_at`). Never paste that JSON at the user.

### Failures

- Exit **4** (no id, no matches): no project claims this repo. Tell the user and point at `oberon-grill` — it mints a store at the first settled decision. Stop.
- Exit **5** (explicit id unknown): say the id is unknown. Stop.

## Render the card (canonical rules for every Oberon skill)

`oberon-grill`, `oberon-sync`, `oberon-test`, `oberon-handoff` and `oberon-delete` all point here rather than restating this. The rules:

1. Print the card's stdout **verbatim** inside a fenced block. Do not re-typeset it, re-order rows, drop the store path, or invent a prettier layout — the layout is the CLI's (ADR-0017), so every skill closes identically.
2. **One card per invocation.** A skill that calls another (`oberon-test` → `oberon-sync`) lets the last one render it.
3. At most one line before it and one line after it (the single next action). Never hand-format a substitute card; never paste `oberon status` JSON.
4. Do not restate rows in prose — id, status, current state, decision count, last entry, per-repo `branch@sha` + cleanliness, handoff freshness and store path are all already on the card.

In this skill, the ≤2 lines you add are the reading the card cannot do itself:

- **DIRTY** on a contributing repo means the last sync entry may describe work that is **not in any commit** (ADR-0013). The card prints a `!` line; say what that costs here.
- **STALE** handoff (the card flags it when `PROGRESS.md` has a newer commit than `HANDOFF.md`) means a cold agent would resume from an out-of-date brief.
- A `state` row of `_Not started._` with 0 decisions means the store exists but nothing has been designed yet.

Do not dump raw JSON. Do not expand into full decision text or full journal bodies.

## Close

End with **at most one** suggested next action, for example:

- any repo `dirty` → `/oberon-sync` (or `oberon-sync`) after the chunk lands in commits, or now if the dirty work is the story
- `decisions.count` is 0 → `/oberon-grill`
- handoff missing or stale and context is tight → `/oberon-handoff`
- otherwise omit the suggestion

This skill mutates nothing — never offer a commit.
