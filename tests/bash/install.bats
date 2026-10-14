#!/usr/bin/env bats
#
# install.sh behaviour + idempotency + env overrides.
#
# Every test runs against isolated AGENTS_HOME / CLAUDE_HOME / CODEX_HOME /
# OBERON_BIN_DIR inside BATS_TEST_TMPDIR so the real home roots are untouched.

load 'helpers.bash'

setup() {
  setup_install_roots
}

# --- Behaviour: fresh install creates the expected symlinks -----------------

@test "install.sh creates a symlink for every skill in all three roots" {
  run run_installer bash
  [ "$status" -eq 0 ]
  assert_skill_links
}

@test "install.sh creates the oberon bin symlink" {
  run run_installer bash
  [ "$status" -eq 0 ]
  assert_bin_link
}

@test "install.sh creates skills/ under every home and the bin dir" {
  run run_installer bash
  [ "$status" -eq 0 ]
  [ -d "$AGENTS_SKILLS_DIR" ]
  [ -d "$CLAUDE_SKILLS_DIR" ]
  [ -d "$CODEX_SKILLS_DIR" ]
  [ -d "$BIN_DIR" ]
}

# --- Override: env roots are honoured and the real $HOME is not touched ----

@test "install.sh respects AGENTS_HOME CLAUDE_HOME CODEX_HOME OBERON_BIN_DIR overrides" {
  local custom_agents="$BATS_TEST_TMPDIR/custom-agents"
  local custom_claude="$BATS_TEST_TMPDIR/custom-claude"
  local custom_codex="$BATS_TEST_TMPDIR/custom-codex"
  local custom_bin="$BATS_TEST_TMPDIR/custom-bin"
  local fake_home="$BATS_TEST_TMPDIR/fake-home"
  mkdir -p "$custom_agents" "$custom_claude" "$custom_codex" "$custom_bin" "$fake_home"

  # Deliberately point HOME at a pristine fake so leakage is detectable.
  AGENTS_HOME="$custom_agents" \
    CLAUDE_HOME="$custom_claude" \
    CODEX_HOME="$custom_codex" \
    OBERON_BIN_DIR="$custom_bin" \
    HOME="$fake_home" \
    bash "$REPO_ROOT/install.sh"

  [ -L "$custom_agents/skills/oberon-grill" ]
  [ "$(readlink "$custom_agents/skills/oberon-grill")" = "$REPO_ROOT/skills/oberon-grill" ]
  [ -L "$custom_claude/skills/oberon-grill" ]
  [ "$(readlink "$custom_claude/skills/oberon-grill")" = "$REPO_ROOT/skills/oberon-grill" ]
  [ -L "$custom_codex/skills/oberon-grill" ]
  [ "$(readlink "$custom_codex/skills/oberon-grill")" = "$REPO_ROOT/skills/oberon-grill" ]
  [ -L "$custom_bin/oberon" ]
  [ "$(readlink "$custom_bin/oberon")" = "$REPO_ROOT/bin/oberon" ]

  # The fake HOME must remain pristine — no default-root leakage.
  [ ! -d "$fake_home/.agents" ]
  [ ! -d "$fake_home/.claude" ]
  [ ! -d "$fake_home/.codex" ]
  [ ! -d "$fake_home/.local" ]
}

# --- Idempotency: re-running leaves identical state -------------------------

@test "install.sh is idempotent — second run leaves tree identical" {
  run run_installer bash
  [ "$status" -eq 0 ]

  local before after
  before="$(snapshot_install_state)"

  run run_installer bash
  [ "$status" -eq 0 ]

  after="$(snapshot_install_state)"
  [ "$before" = "$after" ]
}

@test "install.sh second run reports ok for each existing symlink" {
  run_installer bash >/dev/null
  run run_installer bash
  [ "$status" -eq 0 ]
  # Every target line should now be "ok:" rather than "link:".
  [[ "$output" == *"ok:"* ]]
  [[ "$output" != *"link:"* ]]
}

# --- Shell-agnostic: suite works regardless of the invoking shell ----------
#
# install.sh carries a `#!/usr/bin/env bash` shebang so `bash install.sh` is
# the only supported invocation. What the AC cares about is that the *test
# suite* is usable whether the user's interactive shell is bash or zsh — the
# bats runner itself works either way, and explicit invocation via both
# shells confirms no accidental shell-specific syntax has crept into helpers.

@test "install.sh invoked via bats-under-zsh still succeeds" {
  if ! command -v zsh >/dev/null 2>&1; then
    skip "zsh not installed"
  fi
  run zsh -c '
    set -e
    export AGENTS_HOME="$1"
    export CLAUDE_HOME="$2"
    export CODEX_HOME="$3"
    export OBERON_BIN_DIR="$4"
    bash "$5"
  ' -- "$AGENTS_HOME" "$CLAUDE_HOME" "$CODEX_HOME" "$OBERON_BIN_DIR" "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [ -L "$AGENTS_SKILLS_DIR/oberon-grill" ]
  [ -L "$CLAUDE_SKILLS_DIR/oberon-grill" ]
  [ -L "$CODEX_SKILLS_DIR/oberon-grill" ]
  [ -L "$BIN_DIR/oberon" ]
}

# --- Safety: refuses to clobber a non-matching file -------------------------

@test "install.sh refuses to overwrite a pre-existing regular file" {
  mkdir -p "$CLAUDE_SKILLS_DIR"
  echo "user's own file" > "$CLAUDE_SKILLS_DIR/oberon-grill"

  run run_installer bash
  [ "$status" -ne 0 ]
  # The user's file must survive untouched.
  [ ! -L "$CLAUDE_SKILLS_DIR/oberon-grill" ]
  [ -f "$CLAUDE_SKILLS_DIR/oberon-grill" ]
  grep -q "user's own file" "$CLAUDE_SKILLS_DIR/oberon-grill"
}
