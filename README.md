# Oberon

Oberon gives an AI coding agent **durable working memory for one feature**: a
small store of files kept **outside** the feature's own pull request, so the
memory survives context compaction and session death.

It is **not a plugin**. It installs as plain skills into each host's skill root
(Claude Code, Codex; omp discovers those same roots). No Claude plugin, no host
hooks, no slash-command bundle — just five skill directories and a small CLI
(ADR-0001).

The store lives at `~/.oberon/<project-id>/`, **not** in your repo. That is
deliberate: nothing Oberon writes can leak into the feature PR. The one exception
is `oberon-grill` offering to write a repo-level `CONTEXT.md` entry or a
`docs/adr/NNNN` — each offer is opt-in, and only then does something land in the
PR.

Oberon **never** writes to a contributing repo's `.gitignore`. v1 did, and that
is what made a store unrecoverable when the link lived only inside the repo.

## Getting started

Examples below use Claude Code's `/oberon-…` form. On Codex type the bare name
(`oberon-init`); on omp type `/skill:oberon-init`. Same skill, three spellings.

### 1. Install

```bash
git clone <this repo> ~/dev/oberon
cd ~/dev/oberon
./install.sh
```

Symlinks the five Oberon skills (plus `write-a-skill`) into
`~/.claude/skills/` and `~/.codex/skills/`, and puts `oberon` on your PATH via
`~/.local/bin`. Re-running is a no-op.

### 2. Start a feature — `/oberon-init`

From inside a contributing repo (or any cwd; you can attach repos later):

```
/oberon-init
```

Oberon mints a `project_id`, creates `~/.oberon/<project-id>/` with the four
store files (`project.json`, `DECISIONS.md`, `PROGRESS.md`, `HANDOFF.md`), and
opens the design grill. `oberon-init` is model-invocable but **asks before
running**.

### 3. Settle the design — `/oberon-grill`

```
/oberon-grill
```

Continue or resume the interview until the load-bearing decisions are written.
Decisions land as numbered `D1…Dn` entries in `DECISIONS.md`. Like init, grill is
model-invocable and **asks first**. If it offers a repo-level `CONTEXT.md` entry
or an ADR under `docs/adr/`, that write is opt-in per offer.

### 4. Work, then record — `/oberon-sync`

Build the feature as usual. When something durable changes (a decision, a
milestone, a dead end):

```
/oberon-sync
```

Appends / refreshes `DECISIONS.md` and `PROGRESS.md` from the current session.
`oberon-sync` is model-invocable and **just runs** — the agent may fire it on
its own when it notices state worth keeping.

### 5. Context running low — `/oberon-handoff`

```
/oberon-handoff
```

Rewrites `HANDOFF.md` so a fresh session can pick up cold: where you are, what
matters, what not to redo. Overwrites the previous handoff; the rest of the
store is untouched.

### 6. Feature shipped — `/oberon-delete`

```
/oberon-delete
```

Removes the store directory from `~/.oberon` (git history kept). **User-only** —
`disable-model-invocation` is set so the agent cannot start it. Requires
explicit confirmation.

### Who starts which skill

| Skill | Model may start it? | Gate |
|---|---|---|
| `oberon-init` | yes | asks first |
| `oberon-grill` | yes | asks first |
| `oberon-sync` | yes | runs directly |
| `oberon-handoff` | yes | (session continuity) |
| `oberon-delete` | **no** | user-only |

## Skills reference

| Skill | Role |
|---|---|
| `oberon-init` | Mint a project, create the store, start the design grill |
| `oberon-grill` | Continue / resume the design interview |
| `oberon-sync` | Update `DECISIONS.md` / `PROGRESS.md` from the current session |
| `oberon-handoff` | Rewrite `HANDOFF.md` for the next cold start |
| `oberon-delete` | Remove a store (explicit confirmation required) |

### Invocation names by host

| Host | Example (init) |
|---|---|
| Claude Code | `/oberon-init` |
| Codex | `oberon-init` |
| omp | `/skill:oberon-init` |

omp's `claude` and `codex` skill providers discover the symlinked copies under
`~/.claude/skills/` and `~/.codex/skills/` automatically and de-duplicate by
`realpath`, so linking both roots surfaces **one** skill — there is no separate
omp install path.

## Store layout

The store repo lives at `${OBERON_HOME:-$HOME/.oberon}` (a git repo). Each
project is one subdirectory named by its `project_id`:

```
~/.oberon/<project-id>/
├── project.json   # manifest
├── DECISIONS.md   # numbered decisions D1…Dn + load-bearing facts (append-only)
├── PROGRESS.md    # bounded "Current state" header + dated entries
└── HANDOFF.md     # single file, overwritten each handoff
```

Extra ad-hoc `NN-topic.md` notes are allowed but never created automatically.
There is no per-store README.

### `project.json` schema (`schema: 1`)

```json
{
  "schema": 1,
  "project_id": "alt-120-reminders-7f3a",
  "project_name": "ALT-120 reminder workflow",
  "project_status": "active",
  "created_at": "2026-09-02T12:00:00Z",
  "updated_at": "2026-09-02T12:00:00Z",
  "contributing_repos": [
    {
      "name": "svc-accounts-receivable",
      "remote": "git@github.com:getalternative/svc-accounts-receivable.git",
      "path": "/Users/mateusvinicius/alt/svc-accounts-receivable"
    }
  ],
  "push_remote": null
}
```

`project_status` is exactly `active` or `closed`. `project_id` is a slug of
`project_name` plus a 4-hex-char suffix. Timestamps are UTC ISO-8601 with `Z`.

## CLI (`bin/oberon`)

Every mutating command bumps `updated_at`, stages **only** that project's
directory, and commits it in the store repo. It pushes only when the manifest's
`push_remote` is non-null. The store repo is created and `git init`'d on first
use.

| Command | Behaviour | Output | Failure |
|---|---|---|---|
| `oberon home` | print store repo path | path | — |
| `oberon init --name NAME [--id ID] [--repo PATH]...` | mint id, create dir + 4 files, commit | `project_id` | exit 3 if `--id` is taken |
| `oberon list [--status active\|closed\|all]` | one project per line | TSV `id<TAB>status<TAB>name` | — |
| `oberon resolve [--repo PATH]` | ids whose manifest claims that repo (remote URL first, absolute path second) | one id per line | exit 4 if none |
| `oberon path ID` | absolute store directory | path | exit 5 if unknown |
| `oberon repo-info PATH` | inspect a contributing repo | JSON `{path,remote,branch,sha,dirty,stat}` | exit 5 if not a repo |
| `oberon attach ID --repo PATH` | add a contributing repo (idempotent), commit | — | exit 5 if unknown id |
| `oberon set ID --status active\|closed` | update manifest, commit | — | exit 5 if unknown id |
| `oberon commit ID -m MSG` | stage `ID/`, commit | — | exit 0 no-op when nothing staged |
| `oberon delete ID --yes` | `git rm -r` the directory, commit the removal (never rewrite history) | — | exit 6 without `--yes` |

`resolve` scans every `*/project.json` — there is no central registry file.

## Install details

Requires `git` and `jq`.

```bash
./install.sh
```

What it does:

1. Symlinks each of `skills/oberon-{init,grill,sync,handoff,delete}` and
   `skills/write-a-skill` into **both**:
   - `${CLAUDE_HOME:-$HOME/.claude}/skills/`
   - `${CODEX_HOME:-$HOME/.codex}/skills/`
2. Symlinks `bin/oberon` into `${OBERON_BIN_DIR:-$HOME/.local/bin}` (creates the
   directory if missing). Warns, but does not fail, when that directory is not
   on `$PATH`.

Existing non-symlink files are never overwritten; a symlink that already points
at the correct source is reported as `ok:` and left alone.

Env overrides:

| Variable | Default | Purpose |
|---|---|---|
| `CLAUDE_HOME` | `$HOME/.claude` | Claude Code config root (skills under `skills/`) |
| `CODEX_HOME` | `$HOME/.codex` | Codex config root (skills under `skills/`) |
| `OBERON_BIN_DIR` | `$HOME/.local/bin` | Where the `oberon` CLI symlink lands |
| `OBERON_HOME` | `$HOME/.oberon` | Store repo root (used by the CLI, not the installer) |

Nothing is installed into omp itself, and nothing is registered as a Claude
plugin or a host hook.

### Uninstall

```bash
./uninstall.sh
```

Removes only symlinks that point into this repo, across both skill roots and the
bin dir. Unrelated files are left untouched. The same `CLAUDE_HOME` /
`CODEX_HOME` / `OBERON_BIN_DIR` overrides apply.

## Running tests

Oberon ships a vendored copy of [bats-core](https://github.com/bats-core/bats-core)
under `tests/bats/`, so the suite works on a fresh clone with no extra install:

```bash
./tests/bats/bin/bats tests/bash tests/contracts
```

## Design

Glossary and settled terms: [`CONTEXT.md`](./CONTEXT.md).

Architecture decisions: [`docs/adr/`](./docs/adr/) (ADR-0001 through ADR-0013).

## Known gaps / ideas

v1 carry-over ideas — not commitments for v2:

- Explore a codebase once per repo and inherit that exploration on later projects
  instead of re-running it
- An option for quick tasks
- Use fewer tokens / make runs faster
- Prompt to clear context between phases
- Skip phase-level verification when a phase has only one sub-phase
