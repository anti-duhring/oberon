# The active project is resolved by scanning per-project manifests, not a folder or a shared registry

Each store carries its own `~/.oberon/<project-id>/project.json`, which lists the project's
contributing repos. Resolution scans those manifests. Every skill resolves in this order:
explicit id argument → `OBERON_PROJECT` environment variable → manifest scan matched against
the current repo. One match auto-selects, several match prompt, none is an error directing the
user to `oberon-init`.

Decided with Mateus, 2026-09-02.

## Considered Options

- **Presence of `.oberon/` in the current repo** — how v1 and the original request worked.
  Rejected: with a central store (ADR-0004) the store is not in the repo, and a single
  well-known path per repo caps a repo at one live project, which is the limit that ADR-0004
  rejected in-repo storage to avoid. Resolving by folder presence would smuggle it back and
  force an archive/activate mechanism again.
- **One shared `~/.oberon/index.json` registry.** Rejected after being briefly adopted. It is
  a single mutable file inside the very repo every project auto-commits to, so concurrent
  projects contend on it on every write — turning an append-only design into a merge-conflict
  generator. It also centralises host-specific absolute paths, which cannot be shared across
  machines.
- **Per-project manifests, scanned; ownership follows the data.** Taken.

## Consequences

- Writes are naturally isolated: a project's own commit touches only its own directory, so two
  projects can never conflict over resolution data.
- A repo may host any number of live projects at once, and a project may span repos
  (ADR-0002) with no privileged one — the mapping is many-to-many, expressed as a list per
  project rather than a map per repo.
- Repos are identified by **git remote URL** first, with the absolute worktree path kept only
  as a local convenience. A path-only identity breaks across machines, across worktrees of the
  same repo, and whenever a checkout moves.
- Lookup is an O(projects) scan of small JSON files. If that ever costs anything, it may be
  cached in an untracked, git-ignored `~/.oberon/.index.json` that is rebuildable from the
  manifests — a cache, never the authority.
- `.oberon` symlinks are decoration. Nothing reads them, so they may be named per project
  (`.oberon-<slug>`) or omitted entirely.
- `oberon-init`'s "error if it already exists" becomes precise: it fails when the **id is
  already taken**, not when some folder happens to be present.
