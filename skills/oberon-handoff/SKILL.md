---
name: oberon-handoff
description: Overwrite the Oberon store's HANDOFF.md so a fresh agent can continue the project. Use when context is tight, the session is ending, or the user asks for a handoff to another agent. References DECISIONS.md and PROGRESS.md by path instead of restating them. Redacts secrets and PII.
---

# oberon-handoff

Compact the live session into the store's single `HANDOFF.md` (overwrite in place; prior versions live in store-repo history). Goal: a cold agent can resume without this conversation. All store commits go through `oberon`; never raw `git` on the store; never hand-edit `project.json`.

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
- None → nothing to hand off. Point at `oberon-grill`, which mints the store once a design decision settles. Stop.

Optional user argument: what the **next** session should focus on — tailor the doc to that.

## Read before writing

From `oberon path <id>`:

- `project.json` — id, name, status, contributing repos
- `DECISIONS.md` — know what already exists
- `PROGRESS.md` — especially `## Current state` and the latest journal entry
- existing `HANDOFF.md` — only to avoid dropping still-true operational notes

For each contributing repo, optionally `oberon repo-info <path>` so branch/sha/dirty in the handoff match reality.

## Write `HANDOFF.md`

**Overwrite** the file entirely. Do not append. Do not duplicate long content from other artefacts — **reference by store-relative or absolute path**.

### Required substance

1. **Resume at** — one tight paragraph: what to do first in the next session (honour user focus args when given).
2. **Project** — id, name, store path, status.
3. **Contributing repos** — path, remote if known, branch, sha, dirty flag (note unsaved work if dirty).
4. **Pointers, not copies**
   - Decisions & knowledge: `DECISIONS.md` (cite specific `D#` / `K#` that still constrain the next move).
   - Progress: `PROGRESS.md` → Current state + last entry date/title.
   - Design docs, PRs, tickets, ADRs in contributing repos: path or URL only.
5. **In-flight work** — what this session did that may not yet be in PROGRESS; patches half-finished; commands that must be re-run.
6. **Blockers and landmines** — ordered by severity; include verification gaps and "do not trust X without re-check".
7. **Suggested skills** — section listing Oberon (and other) skills the next agent should consider, e.g. `oberon-sync`, `oberon-grill`, host-local helpers. Phrase as invocations the next agent can take, not vague advice.
8. **Environment / ops** — branch rules, worktree paths, flag names, required services — only what is still true.

### Redaction

Strip API keys, tokens, passwords, cookies, private URLs with embedded credentials, and unnecessary PII. If a secret was required operationally, say *where* to obtain it (password manager, teammate), never the value.

### Tone

Dense, scannable, second-agent-facing. No transcript. No celebration. Path:line evidence where it prevents a wrong turn.

### Sketch

```md
# Handoff — <project name>

**Resume at:** <one paragraph>

## Project
- id: `…`
- store: `…`
- status: active

## Repos
| path | branch | sha | dirty |
|---|---|---|---|
| … | … | … | false |

## Artefacts
- Decisions: `DECISIONS.md` (spine: D14 provenance, K13 green-suite trap)
- Progress: `PROGRESS.md` — Current state + entry <date/title>
- PRs: …

## In flight
- …

## Blockers
1. …

## Suggested skills
- `oberon-sync` — after the next landed chunk
- `oberon-grill` — only if D-scope questions reopen
- …

## Ops notes
- …
```

## Commit

```bash
oberon commit <id> -m "handoff: <short focus>"
```

Say in one line that older handoffs remain in `git log` of the store repo (they recover via ordinary history — you do not run raw git for them unless they ask outside this skill). The store path comes from the card, not from prose.

## Close with the status card

```bash
oberon card <id>
```

Paste stdout **verbatim** in a fenced block; ≤1 line before, ≤1 line after. Never hand-format a substitute, never paste `oberon status` JSON. Full rules: `oberon-status`.

Handoff-specific: the card's `handoff` row is this run's receipt and must not read `STALE`. It does when `PROGRESS.md` has a **newer commit** than `HANDOFF.md` — so either you wrote the handoff before the last sync landed, or the write did not land at all. Re-check before handing over.

## Model invocation

You may self-invoke when context pressure is real or a natural session boundary hit. Still resolve the project correctly; still redact. If multiple projects match and you cannot safely choose, ask.