# Ship Oberon as flat-named skills in one symlink-installed repo, not a Claude plugin

Oberon must work in Claude Code, Codex, and omp. A Claude Code plugin would give us
`oberon:init`-style namespacing and hooks, but Codex does not read Claude plugins (it has
its own `~/.codex/skills/` and an unrelated `~/.codex/plugins` format), so a plugin means a
second separately-installed copy. We therefore keep plain `SKILL.md` directories with flat
names (`oberon-grill`, `oberon-status`, …) in a single repo, symlinked into each host's skill
root — which is what v1's `install.sh` already did for `~/.claude/`.

## Considered Options

- **Claude Code plugin.** Rejected. Gains the literal `oberon:init` name and hooks on one
  host; costs a duplicated tree for Codex. `~/.codex/skills/godfly` and
  `~/.claude/skills/godfly` are already byte-identical hand-copied directories — the drift
  this decision exists to avoid.
- **Flat skills, one repo, symlinks.** Taken.

## Consequences

- The literal name `oberon:grill` is unreachable: `:` is plugin-invocation syntax. Names are
  `/oberon-grill` (Claude), `oberon-grill` (Codex), `/skill:oberon-grill` (omp).
- omp needs no plugin and no separate copy, but it does need its own symlink root:
  `skills.enableClaudeUser` / `skills.enableCodexUser` are off by default, so
  `~/.agents/skills/` is linked too — see ADR-0014, which supersedes the original claim
  that omp discovers the Claude and Codex copies for free. Linking all three roots still
  surfaces one skill because omp de-duplicates by `realpath` (`omp://skills.md`).
- **No behaviour may depend on a hook.** Claude Code has `PreToolUse`, omp has its own hook
  system, Codex has none. Anything that must happen on every Oberon mutation — notably the
  auto-commit — belongs in a script the skill calls, not in a hook.
