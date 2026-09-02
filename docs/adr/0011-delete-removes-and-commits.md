# `oberon-delete` removes the store directory and commits the removal

On confirmation, `oberon-delete` removes `~/.oberon/<project-id>/` and commits that removal to
the store repo. History is never rewritten, so every byte stays recoverable.

Decided with Mateus, 2026-09-02.

## Consequences

- The skill's original purpose — "remove the `.oberon` folder to give room to a new project" —
  no longer exists under ADR-0004, since sibling directories mean nothing blocks a new
  project. What remains is clutter control: `~/.oberon` would otherwise accumulate one
  directory per feature forever.
- Deletion is safe for the first time. The old design's danger was that the store was
  gitignored, making removal terminal — the ALT-120 story (ADR-0003). Here the working tree
  stops showing it and the content survives in history.
- The confirmation prompt can therefore be honest rather than alarming: it shows the path, the
  entry count, and the `git -C ~/.oberon checkout <sha> -- <project-id>/` that restores it.
- Not redundant with `project_status`: closed means finished, deleted means out of the working
  set.
- `oberon-delete` stays user-invoked only, as originally specified.
