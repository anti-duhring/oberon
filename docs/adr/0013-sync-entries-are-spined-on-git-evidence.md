# Sync entries are spined on verifiable git state, not only on the conversation

Every `PROGRESS.md` entry records, per contributing repo touched: the repo path, the current
branch, `HEAD`'s sha, a `--stat`-level summary of what changed, and whether the tree was
**dirty** at sync time — alongside the agent's prose account of intent and context.

Decided with Mateus, 2026-09-02.

## Consequences

- The conversation is the thing Oberon exists to survive losing, so it is the right source for
  *intent* — but it is also the least reliable narrator, and ADR-0010's premise is that an
  entry endures because it is a fact rather than a claim.
- This is already the house rule. ALT-120's README states it: *"Progress items are observable.
  'Wired the store' is not a status; 'store wired at `routes.go:NNN`, `go list -deps` shows no
  new import edge' is."* Its strongest entries carry exact paths, `27/27 pass`, and tag names.
  v1 independently recorded `commit_sha` per task, so the value of shas is established across
  both generations.
- An entry becomes re-derivable long after the session: given a branch and a sha, "we did X"
  can be reconstructed from the diff.
- Cost is a few `git` invocations per contributing repo per sync — negligible, and it is also
  the natural place to notice that a repo the manifest claims no longer exists at that path.
- **A sha alone can lie.** If the work being described is uncommitted or only partly staged,
  `HEAD` predates it and the entry looks re-derivable while pointing at a tree that never
  contained the change — ADR-0010's failure mode wearing a sha. A non-empty
  `git status --porcelain` is therefore recorded explicitly, and the entry marked as a
  snapshot of unsaved work rather than a verifiable reference.
