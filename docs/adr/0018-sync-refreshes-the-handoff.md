# `oberon-sync` refreshes `HANDOFF.md` in the same commit

Every sync that appends a journal entry also overwrites `HANDOFF.md`, following the write and
redaction rules in `oberon-handoff`, and commits both files in one `oberon commit`. The handoff
rules stay in `oberon-handoff`; sync points to them instead of copying them. `oberon-handoff` still
runs on its own for a handoff without a new journal entry.

Decided with Mateus, 2026-09-23.

## Considered Options

- **One commit holding both files.** Taken. `oberon card` flags the handoff `STALE` when
  `PROGRESS.md`'s last commit is newer than `HANDOFF.md`'s (ADR-0017). If both files are in one
  commit, they have the same commit time, so a sync can never leave a stale handoff. It also keeps
  one commit per invocation (ADR-0008).
- **Sync commits, then invokes `oberon-handoff` as a second commit.** Rejected. It doubles the
  store's commit count for every sync, and the gap between the two commits makes the handoff stale
  if the second step fails.
- **Keep them separate; agents remember to hand off.** Rejected. Every sync makes the existing
  handoff stale, and nothing forces the follow-up, so a cold session can resume from an old brief.

## Consequences

- `oberon-test` → `oberon-sync` now refreshes the handoff too. The card still renders once, from
  sync (ADR-0017).
- On sync's no-op path, the handoff is rewritten only when it is missing, `STALE`, or missing
  session state (in-flight work, blockers). That write gets its own `handoff:` commit. Otherwise
  nothing is written, so the no-op guard from ADR-0012 still prevents near-duplicate commits.
- Model-invoked syncs now overwrite `HANDOFF.md`. This is safe because earlier handoffs stay in
  the store repo's history.
