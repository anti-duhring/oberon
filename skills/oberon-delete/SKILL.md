---
name: oberon-delete
description: User-only removal of one Oberon project store directory after explicit confirmation. Commits the removal to the store repo; history is kept so the tree is recoverable. Do not model-invoke.
disable-model-invocation: true
---

# oberon-delete

Remove one project's store directory from the store repo and commit that removal. History is never rewritten — recovery is a checkout of the path from a prior sha. User-invoked only. All mutation through `oberon`; never hand-edit manifests; never `git rm` the store yourself.

## The `oberon` CLI

Call `oberon` from `PATH`. Every store mutation goes through it. If the command is missing,
stop and tell the user to run `install.sh` from the Oberon repo — never fall back to raw
`git` on the store or to hand-editing `project.json`.

## Resolve the project

1. Explicit id argument (preferred), else
2. `$OBERON_PROJECT`, else
3. `oberon resolve --repo <abs current git root>`

- One match → candidate for delete.
- Several → list and require the user to pick **one** id; never delete several in one go.
- None → nothing to delete; suggest `oberon list` / `oberon-init` as appropriate.

Verify with `oberon path <id>` (exit 5 → unknown id, stop).

## Confirmation (mandatory)

Before calling delete, show **all** of the following and wait for an explicit yes that names the id:

1. **Project id** and name (from `project.json`).
2. **Absolute store path** from `oberon path <id>`.
3. **Entry count** — number of files under that directory (e.g. `find "$(oberon path <id>)" -type f | wc -l`) plus a short listing of top-level names (`project.json`, `DECISIONS.md`, …).
4. **Store repo root** — `oberon home`.
5. **Recovery line** — exact command they can run later. Resolve a current store-repo sha with a read-only inspection if needed (the recovery recipe is documentation for the user; the delete itself still goes through the CLI):

   ```bash
   git -C "$(oberon home)" checkout <sha-before-delete> -- <id>/
   ```

   Use the store repo's current `HEAD` sha as `<sha-before-delete>` in the message you show **before** deleting (that commit still contains the tree). Say plainly: deletion commits a removal; it does not purge history; restore with the line above then commit if they want the restore recorded.

On anything other than clear confirmation, abort with no change.

## Delete

```bash
oberon delete <id> --yes
```

- Requires `--yes` (CLI exits 6 without it) — only pass it after the confirmation above.
- The CLI removes the directory and commits that removal inside the store repo. Do not run raw `git rm` / `git commit` yourself.
- If anything remains uncommitted in that project path (should not), finish with:

  ```bash
  oberon commit <id> -m "delete: <id>"
  ```

  (`delete` already commits; this is only a safety net and no-ops when clean.)
- Do not rewrite history, force-push, or drop the store remote.

## After

Report: id removed, store repo home, the recovery checkout line again, and that `oberon list` no longer shows it. Closed vs deleted: status `closed` means finished work kept on disk; delete means out of the working tree entirely.