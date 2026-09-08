#!/usr/bin/env bash
# Shared helpers for bash-tier bats tests.
#
# These helpers give each test private AGENTS_HOME / CLAUDE_HOME / CODEX_HOME /
# OBERON_BIN_DIR under BATS_TEST_TMPDIR so the real ~/.agents, ~/.claude,
# ~/.codex, and ~/.local/bin are never touched, and expose the repo root as
# REPO_ROOT.

# Resolve the repo root (two levels up from this file: tests/bash/).
_oberon_tests_bash_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="$(cd "$_oberon_tests_bash_dir/../.." && pwd)"
unset _oberon_tests_bash_dir

# Canonical skill list, kept in sync with install.sh / uninstall.sh.
OBERON_SKILLS=(
  oberon-grill
  oberon-sync
  oberon-status
  oberon-test
  oberon-handoff
  oberon-delete
  write-a-skill
)

# setup_install_roots — create isolated Agents, Claude, Codex, and bin roots for
# the current test. Exports AGENTS_HOME, CLAUDE_HOME, CODEX_HOME,
# OBERON_BIN_DIR, plus the derived skill/bin paths install.sh and uninstall.sh
# write into.
setup_install_roots() {
  export AGENTS_HOME="${BATS_TEST_TMPDIR}/agents-home"
  export CLAUDE_HOME="${BATS_TEST_TMPDIR}/claude-home"
  export CODEX_HOME="${BATS_TEST_TMPDIR}/codex-home"
  export OBERON_BIN_DIR="${BATS_TEST_TMPDIR}/bin"
  export AGENTS_SKILLS_DIR="$AGENTS_HOME/skills"
  export CLAUDE_SKILLS_DIR="$CLAUDE_HOME/skills"
  export CODEX_SKILLS_DIR="$CODEX_HOME/skills"
  export BIN_DIR="$OBERON_BIN_DIR"
  mkdir -p "$AGENTS_HOME" "$CLAUDE_HOME" "$CODEX_HOME" "$OBERON_BIN_DIR"
}

# Back-compat alias used by older test names in comments / muscle memory.
setup_claude_home() {
  setup_install_roots
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

# assert_skill_links — every OBERON_SKILLS entry is a correct symlink in the
# Agents, Claude, and Codex skill roots.
assert_skill_links() {
  local skill root
  for skill in "${OBERON_SKILLS[@]}"; do
    for root in "$AGENTS_SKILLS_DIR" "$CLAUDE_SKILLS_DIR" "$CODEX_SKILLS_DIR"; do
      [ -L "$root/$skill" ]
      [ "$(readlink "$root/$skill")" = "$REPO_ROOT/skills/$skill" ]
    done
  done
}

# assert_bin_link — bin/oberon is linked correctly.
assert_bin_link() {
  [ -L "$BIN_DIR/oberon" ]
  [ "$(readlink "$BIN_DIR/oberon")" = "$REPO_ROOT/bin/oberon" ]
}

# assert_no_skill_links — every OBERON_SKILLS entry is gone from all roots.
assert_no_skill_links() {
  local skill root
  for skill in "${OBERON_SKILLS[@]}"; do
    for root in "$AGENTS_SKILLS_DIR" "$CLAUDE_SKILLS_DIR" "$CODEX_SKILLS_DIR"; do
      [ ! -e "$root/$skill" ] && [ ! -L "$root/$skill" ]
    done
  done
}

# assert_no_bin_link — the oberon bin link is gone.
assert_no_bin_link() {
  [ ! -e "$BIN_DIR/oberon" ] && [ ! -L "$BIN_DIR/oberon" ]
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

# snapshot_install_state — stable snapshot of Agents, Claude, Codex, and bin
# roots.
snapshot_install_state() {
  {
    printf '### AGENTS_HOME\n'
    snapshot_tree "$AGENTS_HOME"
    printf '### CLAUDE_HOME\n'
    snapshot_tree "$CLAUDE_HOME"
    printf '### CODEX_HOME\n'
    snapshot_tree "$CODEX_HOME"
    printf '### BIN_DIR\n'
    snapshot_tree "$BIN_DIR"
  }
}
