# Oberon

Oberon is a workflow that gives an AI coding agent durable working memory for one
feature at a time: a small set of files, kept outside the feature's own pull request,
that survive context compaction and session death.

## Language

**Oberon project**:
One unit of feature work, from first design conversation to shipped. The thing an
Oberon store is about. May draw on knowledge from several repos.
_Avoid_: task, ticket, epic

**Store**:
The directory holding one project's Oberon files, at `~/.oberon/<project-id>/`.
Exactly one per project.
_Avoid_: workspace, "the `.oberon` folder" (a `.oberon` symlink is optional
decoration that nothing resolves — see ADR-0005)

**Store repo**:
The single git repo at `~/.oberon` containing every project's store as a
subdirectory. One history and one remote for all projects.

**Project id**:
A legible identifier minted once at init and never reused: a slug of the project
name plus a short random suffix (`alt-120-reminders-7f3a`). Names the project's
store directory, and is typed by hand to disambiguate two projects in one repo.

**Project status**:
Whether a store is in the working set: `active` or `closed`. It describes the
store's lifecycle, never the work's progress — that is `PROGRESS.md`'s job, and a
status field that describes work decays unnoticed (ADR-0010). Nothing gates on it.

**Contributing repo**:
A repo whose code a project touches, or whose behaviour it depends on. A project
has one or more; the store's location is independent of them.
_Avoid_: target repo

**Manifest**:
A store's own `project.json` — its identity, status, timestamps, and the
contributing repos it claims. Each project owns exactly one; together they are
the only authority on which projects are live in a given repo.
_Avoid_: registry, index (a rebuildable cache may exist, but is never the authority)

**Skill**:
A `SKILL.md` directory discovered by an agent host and invocable by name. The
portable unit of Oberon behaviour.

**Host**:
An agent runtime that discovers and runs skills — Claude Code, Codex, or omp.
Each reads a different skill root, so portability is a property of installation,
not of a skill's content.

**Provider**:
A host's mechanism for discovering skills from one root (e.g. omp's `claude`,
`codex`, and `claude-plugins` providers). Providers are how one installed copy
becomes visible to several hosts.
