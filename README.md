# Oberon

Oberon gives an AI coding agent **durable working memory for one feature**: a
small store of files kept **outside** the feature's own pull request, so the
memory survives context compaction and session death.

It is **not a plugin**. It installs as plain skills into each host's skill root
(Claude Code, Codex; omp discovers those same roots). No Claude plugin, no host
hooks, no slash-command bundle — just six skill directories and a small CLI
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
(`oberon-grill`); on omp type `/skill:oberon-grill`. Same skill, three spellings.

### 1. Install

```bash
git clone <this repo> ~/dev/oberon
cd ~/dev/oberon
./install.sh
```

Symlinks the six Oberon skills (plus `write-a-skill`) into `~/.agents/skills/`,
`~/.claude/skills/` and `~/.codex/skills/`, and puts `oberon` on your PATH via
`~/.local/bin`. Re-running is a no-op.

### 2. Start a feature — `/oberon-grill`

From inside a contributing repo:

```
/oberon-grill
```

There is **no init step**. Grill is the entry point: it asks first, then runs a
one-question-at-a-time design interview. The store does not exist yet, because a
project you can name is an *output* of that interview, not a prerequisite
(ADR-0015).

The **first settled decision** mints it: grill proposes a working project name
from what you just agreed, confirms it in one line, calls `oberon init`, and
writes that decision as `D1`. From there every settled item is appended to
`DECISIONS.md` and committed as it crystallises, so a session that dies at Q20
costs you one question, not twenty. Re-invoking `/oberon-grill` in a repo that
already has a store resumes that store instead of minting a second one.

If you end the interview before anything settles, **no store is created** —
nothing to clean up.

If grill offers a repo-level `CONTEXT.md` entry or an ADR under `docs/adr/`, that
write is opt-in per offer, and it is the only thing Oberon puts in your PR.

### 3. Check where you are — `/oberon-status`

Coming back to a feature, or before you write anything down:

```
/oberon-status
```

Read-only TLDR of every project whose manifest claims the current repo (or one
id you pass). Current state, decision count, last progress heading, per-repo
branch/sha/dirty, and whether a handoff exists. Safe to invoke any time — it
never mutates the store and needs no confirmation. Model-invocable; **just runs**.

### 4. Work, then record — `/oberon-sync`

Build the feature as usual. When something durable changes (a decision, a
milestone, a dead end):

```
/oberon-sync
```

Appends one dated entry to `PROGRESS.md` and rewrites its short "Current state"
header. It never touches `DECISIONS.md` — that is grill's file — and never edits
an earlier entry. Each entry is spined on real git evidence per contributing repo
(branch, sha, dirty flag, `--stat` summary), and an entry taken against a dirty
tree is marked as a snapshot of unsaved work rather than a verifiable reference.
`oberon-sync` is model-invocable and **just runs** — the agent may fire it on
its own when it notices state worth keeping.

### 5. Run the tests — `/oberon-test`

```
/oberon-test
```

Runs the suites that cover this project from the recipe in `TEST.md`, then
records the run there: how to run each suite, prerequisites, landmines, the last
results, and a ten-line run history. When `TEST.md` does not exist yet it is
derived from repo evidence (CI config, task runners, language defaults) and
created lazily — `oberon init` never seeds it (ADR-0016). So a cold session
re-runs the right tests without rediscovering which suite matters, which service
must be up, or which failure was already red.

Failures are classified `regression` / `pre-existing` / `flaky`, and an
unverified `pre-existing` claim says so. The skill never edits a test, adds a
skip, or narrows a selector to reach green. It commits `TEST.md`, then calls
`/oberon-sync` for the journal entry — a green re-run of an unchanged sha lets
sync no-op, which is correct. **User-only** — `disable-model-invocation` is set,
because running tests has side effects.

### 6. Context running low — `/oberon-handoff`

```
/oberon-handoff
```

Rewrites `HANDOFF.md` so a fresh session can pick up cold: where you are, what
matters, what not to redo. Overwrites the previous handoff; the rest of the
store is untouched.

### 7. Feature shipped — `/oberon-delete`

```
/oberon-delete
```

Removes the store directory from `~/.oberon` (git history kept). **User-only** —
`disable-model-invocation` is set so the agent cannot start it. Requires
explicit confirmation.

### Who starts which skill

| Skill | Model may start it? | Gate |
|---|---|---|
| `oberon-grill` | yes | asks first (and mints the store at the first decision) |
| `oberon-status` | yes | runs directly (read-only) |
| `oberon-sync` | yes | runs directly |
| `oberon-test` | **no** | user-only (test runs have side effects) |
| `oberon-handoff` | yes | (session continuity) |
| `oberon-delete` | **no** | user-only |

## Skills reference

| Skill | Role |
|---|---|
| `oberon-grill` | Design interview; mints the store at the first settled decision, resumes an existing one |
| `oberon-status` | Read-only TLDR of project state (safe any time) |
| `oberon-sync` | Append a dated `PROGRESS.md` entry from git evidence |
| `oberon-test` | Run the suites from `TEST.md`, record results, then call `oberon-sync` |
| `oberon-handoff` | Rewrite `HANDOFF.md` for the next cold start |
| `oberon-delete` | Remove a store (explicit confirmation required) |

### Invocation names by host

| Host | Example (grill) |
|---|---|
| Claude Code | `/oberon-grill` |
| Codex | `oberon-grill` |
| omp | `/skill:oberon-grill` |

omp discovers the copies under `~/.agents/skills/` through its always-on
`agents` provider (`skills.enableAgentsUser`, default on). Its `claude` and
`codex` user providers are opt-in — `skills.enableClaudeUser` and
`skills.enableCodexUser` default to off — so linking only `~/.claude/skills/`
and `~/.codex/skills/` leaves Oberon invisible to omp. That is why `install.sh`
links the `~/.agents/skills/` root too; omp de-duplicates by `realpath`, so all
three links still surface **one** skill. Check with
`omp config get skills.enableClaudeUser`.

## Store layout

The store repo lives at `${OBERON_HOME:-$HOME/.oberon}` (a git repo). Each
project is one subdirectory named by its `project_id`:

```
~/.oberon/<project-id>/
├── project.json   # manifest
├── DECISIONS.md   # numbered decisions D1…Dn + load-bearing facts (append-only)
├── PROGRESS.md    # bounded "Current state" header + dated entries
├── HANDOFF.md     # single file, overwritten each handoff
└── TEST.md        # how to test + last results; created lazily by oberon-test
```

`oberon init` seeds the first four; `TEST.md` appears the first time
`/oberon-test` runs (ADR-0016). Extra ad-hoc `NN-topic.md` notes are allowed but
never created automatically. There is no per-store README.

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
| `oberon init --name NAME [--id ID] [--repo PATH]...` | mint id, create dir + 4 files, commit — called by `oberon-grill`, not by the user | `project_id` | exit 3 if `--id` is taken |
| `oberon list [--status active\|closed\|all]` | one project per line | TSV `id<TAB>status<TAB>name` | — |
| `oberon resolve [--repo PATH]` | ids whose manifest claims that repo (remote URL first, absolute path second) | one id per line | exit 4 if none |
| `oberon status [ID]` | read-only TLDR payload for one id, or every project claiming the current repo | JSON array of project summaries | exit 4 if none claim the repo; exit 5 if `ID` unknown |
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

1. Symlinks each of `skills/oberon-{grill,status,sync,test,handoff,delete}` and
   `skills/write-a-skill` into **all three**:
   - `${AGENTS_HOME:-$HOME/.agents}/skills/` (omp / cross-harness native root)
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
| `AGENTS_HOME` | `$HOME/.agents` | Cross-harness skill root omp reads by default (skills under `skills/`) |
| `CLAUDE_HOME` | `$HOME/.claude` | Claude Code config root (skills under `skills/`) |
| `CODEX_HOME` | `$HOME/.codex` | Codex config root (skills under `skills/`) |
| `OBERON_BIN_DIR` | `$HOME/.local/bin` | Where the `oberon` CLI symlink lands |
| `OBERON_HOME` | `$HOME/.oberon` | Store repo root (used by the CLI, not the installer) |

Nothing is registered as a Claude plugin or a host hook; the only omp-side
footprint is the `~/.agents/skills/` symlinks, which omp reads with no config
change.

### Uninstall

```bash
./uninstall.sh
```

Removes only symlinks that point into this repo, across all three skill roots
and the bin dir. Unrelated files are left untouched. The same `AGENTS_HOME` /
`CLAUDE_HOME` / `CODEX_HOME` / `OBERON_BIN_DIR` overrides apply.

## Running tests

Oberon ships a vendored copy of [bats-core](https://github.com/bats-core/bats-core)
under `tests/bats/`, so the suite works on a fresh clone with no extra install:

```bash
./tests/bats/bin/bats tests/bash tests/contracts
```

## Design

Glossary and settled terms: [`CONTEXT.md`](./CONTEXT.md).

Architecture decisions: [`docs/adr/`](./docs/adr/) (ADR-0001 through ADR-0016).

## Known gaps / ideas

v1 carry-over ideas — not commitments for v2:

- Explore a codebase once per repo and inherit that exploration on later projects
  instead of re-running it
- An option for quick tasks
- Use fewer tokens / make runs faster
- Prompt to clear context between phases
- Skip phase-level verification when a phase has only one sub-phase
- `oberon status` does not report whether `TEST.md` exists or what its last
  verdict was — the CLI parses `DECISIONS.md`, `PROGRESS.md` and `HANDOFF.md`
  only (ADR-0016)
