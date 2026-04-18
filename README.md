# Oberon

A meta-prompting, context-engineering, spec-driven development workflow for Claude Code.

Oberon turns "I want to build X" into a structured project with captured decisions and an implementation-ready PRD — via two slash commands.

## Commands

The canonical chain is `/obr-init` → `/obr-spec` → `/obr-plan` → `/obr-phase N`:

- `/obr-init` — initializes a project: runs a terse design grill, writes `.oberon/PROJECT.md` with captured decisions, and sets up state.
- `/obr-spec` — generates a PRD from the project decisions and writes it to `.oberon/PRD.md`.
- `/obr-plan` — decomposes the PRD into a 1–4 phase plan, discovers verification commands, and writes per-task files under `.oberon/phases/N/N-M.md`.
- `/obr-phase N` — executes every task in phase `N` sequentially via fresh executor subagents; `/obr-phase N skip` marks a phase skipped without running it.
- `/obr-status` — prints a read-only snapshot of the current Oberon project's phase and per-task progress, plus a single-line Next advisory. Safe to run from any state.

## Install

Requires Claude Code.

```bash
git clone <this repo> ~/dev/oberon
cd ~/dev/oberon
./install.sh
```

This symlinks the commands into `~/.claude/commands/` and the skills into `~/.claude/skills/`. Existing files are not overwritten; symlinks already pointing to this repo are left in place.

Override the install location with `CLAUDE_HOME=/custom/path ./install.sh`.

## Usage

From inside any project:

```
/obr-init            # grill me from scratch
/obr-init brief.md   # seed the grill with an existing brief
/obr-init "I want to build a todo app with offline support"
```

Follow the prompts. Oberon creates `.oberon/PROJECT.md` and `.oberon/state.json`, and appends `.oberon/` to `.gitignore` if one exists.

When the grill finishes:

```
/obr-spec
```

This reads `PROJECT.md`, asks a few gap-filling questions, and writes `.oberon/PRD.md`.

Then plan and execute:

```
/obr-plan            # propose phases + tasks, confirm verification commands
/obr-phase 1         # run phase 1 — one executor subagent per task, one commit per task
/obr-phase 2 skip    # mark a phase as skipped without running it
```

`/obr-phase N` refuses to run if phase `N-1` isn't `completed` or `skipped`, and hard-aborts if the working tree is dirty. It auto-resumes from the first non-completed task if re-run after a crash or abort.

## Layout

```
.
├── commands/
│   ├── obr-init.md
│   ├── obr-spec.md
│   ├── obr-plan.md
│   ├── obr-phase.md
│   └── obr-status.md
├── skills/
│   ├── obr-grill/     # terse interview skill used by /obr-init
│   ├── obr-prd/       # PRD generator used by /obr-spec
│   ├── obr-planner/   # phase + task generator used by /obr-plan
│   └── obr-executor/  # per-task executor subagent spawned by /obr-phase
├── install.sh
├── uninstall.sh
└── README.md
```

## Uninstall

```bash
./uninstall.sh
```

Removes only the symlinks that point into this repo. Leaves unrelated files alone.
