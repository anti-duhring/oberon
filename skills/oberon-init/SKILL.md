---
name: oberon-init
description: Start a new Oberon project store after explicit user confirmation. Use only when the user wants to begin durable working memory for one feature, or when another Oberon skill finds no matching project and directs them here. Collects a project name, mints an id via the oberon CLI, and attaches the current repo. Never invent a project unbidden.
---

# oberon-init

Mint a new Oberon project store for one feature. You confirm with the user before any side effect, then call `oberon` — never raw `git`, never hand-edit `project.json`.

## The `oberon` CLI

Call `oberon` from `PATH`. Every store mutation goes through it. If the command is missing,
stop and tell the user to run `install.sh` from the Oberon repo — never fall back to raw
`git` on the store or to hand-editing `project.json`.

## Confirm before side effects

Model-invocable does **not** mean unbidden. Before creating anything:

1. State that you are about to create a new Oberon project store under `${OBERON_HOME:-$HOME/.oberon}/`.
2. Propose a short project name (or ask for one if nothing in the conversation supplies it).
3. Name the contributing repo you will attach (default: the current git worktree root).
4. Wait for an explicit yes. On no / cancel, stop with no CLI calls.

## Collect inputs

- **Name** (required): human-readable project name. The CLI mints `project_id` as a slug of this name plus a 4-hex suffix.
- **Optional explicit id**: only if the user insists on a specific id; pass `--id`. Exit 3 from the CLI means the id is taken — report it and stop or ask for another.
- **Contributing repo(s)**: at least the current worktree. Extra `--repo PATH` only when the user names more.

If the conversation already has a clear feature name, offer it rather than asking open-ended. Keep the confirmation turn tight.

## Create

From any cwd:

```bash
oberon init --name "<NAME>" [--id "<ID>"] --repo "<ABS_REPO_PATH>" [--repo "..."]
```

- Print the minted `project_id` the CLI emits on stdout.
- Tell the user the store path is `$(oberon path <id>)`.
- Mention the four files created: `project.json`, `DECISIONS.md`, `PROGRESS.md`, `HANDOFF.md`.
- End with a store commit (harmless no-op if `init` already committed everything):

  ```bash
  oberon commit <id> -m "init: <project name>"
  ```

  Do not create or edit store files outside `oberon`.

## Failures

- Exit 3: id taken → say so; do not overwrite.
- Not a git repo / bad path: fix the `--repo` path or ask; do not invent paths.
- Never create directories or files under the store yourself — only through `oberon`.

## After init

Optionally offer `oberon-grill` to settle design into `DECISIONS.md`. Do not auto-start the grill.