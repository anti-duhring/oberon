#!/usr/bin/env bash
# Shared helpers for bash-tier bats tests.
#
# These helpers give each test a private CLAUDE_HOME under BATS_TEST_TMPDIR so
# the real ~/.claude/ is never touched, and expose the repo root as REPO_ROOT.

# Resolve the repo root (two levels up from this file: tests/bash/).
_oberon_tests_bash_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="$(cd "$_oberon_tests_bash_dir/../.." && pwd)"
unset _oberon_tests_bash_dir

# Canonical lists, kept in sync with install.sh / uninstall.sh.
OBERON_COMMANDS=(obr-init.md obr-spec.md obr-plan.md obr-phase.md obr-archive.md obr-status.md)
OBERON_SKILLS=(obr-grill obr-prd obr-planner obr-executor)

# Uninstall.sh currently omits obr-status.md from its list; tests that care
# about what uninstall actually touches should use this list instead.
OBERON_UNINSTALL_COMMANDS=(obr-init.md obr-spec.md obr-plan.md obr-phase.md obr-archive.md)

# setup_claude_home — create an isolated CLAUDE_HOME for the current test.
# Exports CLAUDE_HOME, COMMANDS_DIR, SKILLS_DIR. Nothing outside this dir is
# touched by subsequent installer/uninstaller runs because install.sh and
# uninstall.sh both honour $CLAUDE_HOME.
setup_claude_home() {
  export CLAUDE_HOME="${BATS_TEST_TMPDIR}/claude-home"
  export COMMANDS_DIR="$CLAUDE_HOME/commands"
  export SKILLS_DIR="$CLAUDE_HOME/skills"
  mkdir -p "$CLAUDE_HOME"
}

# run_installer [shell] — invoke install.sh, defaulting to bash. Passing "zsh"
# (or any other shell on PATH) re-runs the same script under that interpreter
# so we can assert shell-agnostic behaviour.
run_installer() {
  local shell_bin="${1:-bash}"
  "$shell_bin" "$REPO_ROOT/install.sh"
}

# run_uninstaller [shell] — same idea for uninstall.sh.
run_uninstaller() {
  local shell_bin="${1:-bash}"
  "$shell_bin" "$REPO_ROOT/uninstall.sh"
}

# snapshot_tree <dir> — emit a stable, sorted listing of <dir> with each entry
# annotated as either a symlink (and its target) or a regular file/dir. Used
# to assert idempotency: two snapshots taken before and after a re-install
# must be byte-identical.
snapshot_tree() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    printf 'MISSING %s\n' "$dir"
    return 0
  fi
  # Use find with -print0 + sort -z to get a deterministic order regardless
  # of filesystem enumeration quirks.
  find "$dir" -mindepth 1 -print0 |
    LC_ALL=C sort -z |
    while IFS= read -r -d '' entry; do
      if [ -L "$entry" ]; then
        printf 'LINK %s -> %s\n' "$entry" "$(readlink "$entry")"
      elif [ -d "$entry" ]; then
        printf 'DIR  %s\n' "$entry"
      else
        printf 'FILE %s\n' "$entry"
      fi
    done
}
