# Install into `~/.agents/skills` as well, because omp's Claude and Codex user providers are opt-in

ADR-0001 assumed omp needs no install of its own: its `claude` (priority 80) and `codex`
(priority 70) providers would pick up the symlinks under `~/.claude/skills/` and
`~/.codex/skills/`. That is only true when those *user-level* sources are enabled, and they
are not enabled by default in practice — a real install showed
`skills.enableClaudeUser = false` and `skills.enableCodexUser = false`, with every Oberon
skill silently absent from omp while the `oberon` CLI itself resolved fine. `install.sh`
therefore also links each skill into `${AGENTS_HOME:-$HOME/.agents}/skills/`, the root
omp's always-on `agents` provider reads (`skills.enableAgentsUser`, default on).

## Considered Options

- **Tell each user to flip `skills.enableClaudeUser`.** Rejected. It is invisible
  per-machine state that turns "installed" into "installed and configured", and it drags in
  every other skill under `~/.claude/skills/` as a side effect.
- **Set `skills.customDirectories` to `~/.claude/skills`.** Rejected. Same config-mutation
  cost, plus it makes Oberon's availability depend on an omp setting we do not own.
- **Link the `~/.agents/skills/` root too.** Taken. It is the cross-harness root, needs no
  config change, and costs one more symlink per skill.

## Consequences

- `install.sh` links three roots (`AGENTS_HOME`, `CLAUDE_HOME`, `CODEX_HOME`) and
  `uninstall.sh` removes from all three, still only when a symlink points into this repo.
- omp de-duplicates by `realpath`, so three links still surface one skill.
- `AGENTS_HOME` joins `CLAUDE_HOME` / `CODEX_HOME` / `OBERON_BIN_DIR` as an install-time
  env override; the bash-tier tests isolate all three roots per test.
- ADR-0001's "omp needs no install of its own" is superseded by this ADR. The weaker claim
  still holds: no plugin, no hook, no separate copy of the tree.
