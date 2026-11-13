# When the store repo has an `origin` remote, mutating commands pull then push; reads fast-forward

The store repo is one git repo at `~/.oberon` (ADR-0004). Commits stay local unless a project opts into `push_remote` (ADR-0008). That is the right default on a single machine, but it is not enough once the same store is used on more than one machine: without a repo-wide remote, each clone drifts, and a project-level `push_remote` is easy to leave unset.

When the store repo has an `origin` remote, Oberon treats it as the shared copy of every project:

- Every mutating command (`init`, `attach`, `set`, `commit`, `delete`) first runs `git pull --rebase --autostash` from `origin`. A conflict fails the command with a message to resolve it in the store and run `oberon sync-store`. The rebase is aborted so the store is not left mid-rebase, and local work is not clobbered.
- After the store commit, Oberon pushes to `origin`. A failed push (offline, rejected) is a warning; the local commit is kept.
- Read commands (`list`, `status`, `card`, `resolve`, `path`) do a quiet best-effort fetch and fast-forward, with a short timeout. They never fail because `origin` is unreachable.
- `oberon sync-store` runs the pull-and-push cycle on its own.

`push_remote` is unchanged as an optional *extra* push target for one project. If it is unset, or if it names `origin` or the same URL as `origin`, only the store-wide push runs. If it names a different remote, that push still happens after the origin push.

A missing `origin` keeps today's behaviour: local commits only, plus an opt-in `push_remote`.

Decided with Mateus, 2026-11-13.

## Consequences

- One remote backs up and shares every project, which is what ADR-0004 already assumed a remote was for.
- Offline machines still record work. The next successful `oberon sync-store` (or mutating command) reconciles.
- `.DS_Store` is never staged, so Finder metadata cannot sneak into a shared store commit.
