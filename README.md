# Oberon

A meta-prompting, context-engineering, spec-driven development workflow for Claude Code.

Oberon turns "I want to build X" into a structured project with captured decisions and an implementation-ready PRD — via two slash commands.

## Phase 1

Two slash commands and three skills:

- `/obr-init` — initializes a project: runs a terse design grill, writes `.oberon/PROJECT.md` with captured decisions, and sets up state.
- `/obr-start` — generates a PRD from the project decisions and writes it to `.oberon/PRD.md`.

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
/obr-start
```

This reads `PROJECT.md`, asks a few gap-filling questions, and writes `.oberon/PRD.md`.

## Layout

```
.
├── commands/
│   ├── obr-init.md
│   └── obr-start.md
├── skills/
│   ├── obr-grill/    # terse interview skill used by /obr-init
│   └── obr-prd/      # PRD generator used by /obr-start
├── install.sh
├── uninstall.sh
└── README.md
```

## Uninstall

```bash
./uninstall.sh
```

Removes only the symlinks that point into this repo. Leaves unrelated files alone.
