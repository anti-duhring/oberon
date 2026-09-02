# The store lives centrally in one `~/.oberon` git repo, not inside a contributing repo

Every project's store is a directory `~/.oberon/<project-id>/` inside a single git repo at
`~/.oberon`. Contributing repos see it through a `.oberon` symlink, excluded per-clone via
`.git/info/exclude`. Persisting a change is `git -C ~/.oberon add <project-id> && git commit`.

Decided with Mateus, 2026-09-02, after the in-repo alternative was costed out.

## Considered Options

- **`.oberon/` inside a contributing repo, auto-committed to a side branch
  `oberon-<project-id>`.** The original request. Rejected: the side branch exists *only* to
  stop the store polluting the feature PR, and buying that costs two mechanisms. (1) The
  store is either permanently dirty in `git status` on the feature branch or gitignored —
  and gitignored is exactly how ALT-120's store became unrecoverable (ADR-0003). (2)
  Committing a path onto a branch that is not HEAD, without disturbing the index or working
  tree, needs either a second worktree or `hash-object`/`write-tree`/`commit-tree` plumbing.
  It also cannot hold two live projects in one repo, since `.oberon/` is a single path —
  v1 built `/obr-archive` for precisely this, and `svc-accounts-payable/.oberon/` on this
  machine contains nothing but an empty `archived/`.
- **Central store.** Taken.

## Consequences

- No branch mechanism, and no archive/activate mechanism. Concurrent projects are sibling
  directories; nothing needs parking.
- No privileged "anchor" repo, which is what ADR-0002 asks for.
- The store survives `git clean -xfd`, `git worktree remove`, and re-cloning a contributing
  repo. Those are the three things that actually destroy a working store — ALT-120's lived
  inside a worktree.
- One remote backs up every project at once.
- `project-id` names a directory, not a branch. Every reason given for the branch still holds.
- New cost, accepted: the store is no longer physically inside the repo, so a project must be
  *resolved* from the current directory rather than found by looking. The `.oberon` symlink is
  that resolution mechanism.
- `.git/info/exclude` is per-clone and never committed, so the symlink cannot leak into a PR —
  but it also does not travel to a teammate or a fresh clone, which must re-run the link step.
