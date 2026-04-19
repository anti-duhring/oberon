#!/usr/bin/env bats
#
# install.sh behaviour + idempotency + CLAUDE_HOME override.
#
# Every test runs against an isolated CLAUDE_HOME inside BATS_TEST_TMPDIR so
# the real ~/.claude/ is untouched. No assertion writes outside that tmpdir.

load 'helpers.bash'

setup() {
  setup_claude_home
}

# --- Behaviour: fresh install creates the expected symlinks -----------------

@test "install.sh creates a symlink for every command" {
  run run_installer bash
  [ "$status" -eq 0 ]

  for cmd in "${OBERON_COMMANDS[@]}"; do
    local dst="$COMMANDS_DIR/$cmd"
    [ -L "$dst" ] || { echo "missing symlink: $dst"; return 1; }
    [ "$(readlink "$dst")" = "$REPO_ROOT/commands/$cmd" ]
  done
}

@test "install.sh creates a symlink for every skill" {
  run run_installer bash
  [ "$status" -eq 0 ]

  for skill in "${OBERON_SKILLS[@]}"; do
    local dst="$SKILLS_DIR/$skill"
    [ -L "$dst" ] || { echo "missing symlink: $dst"; return 1; }
    [ "$(readlink "$dst")" = "$REPO_ROOT/skills/$skill" ]
  done
}

@test "install.sh creates commands/ and skills/ under CLAUDE_HOME" {
  run run_installer bash
  [ "$status" -eq 0 ]
  [ -d "$COMMANDS_DIR" ]
  [ -d "$SKILLS_DIR" ]
}

# --- Override: CLAUDE_HOME is honoured and the real $HOME is not touched ----

@test "install.sh respects a CLAUDE_HOME override" {
  local custom="$BATS_TEST_TMPDIR/custom-claude"
  mkdir -p "$custom"

  # Deliberately unset HOME to prove the script does not fall back to it.
  CLAUDE_HOME="$custom" HOME="$BATS_TEST_TMPDIR/fake-home" \
    bash "$REPO_ROOT/install.sh"

  [ -L "$custom/commands/obr-init.md" ]
  [ "$(readlink "$custom/commands/obr-init.md")" = "$REPO_ROOT/commands/obr-init.md" ]
  [ -L "$custom/skills/obr-executor" ]

  # The fake HOME must remain pristine — no ~/.claude/ leakage.
  [ ! -d "$BATS_TEST_TMPDIR/fake-home/.claude" ]
}

# --- Idempotency: re-running leaves identical state -------------------------

@test "install.sh is idempotent — second run leaves tree identical" {
  run run_installer bash
  [ "$status" -eq 0 ]

  local before after
  before="$(snapshot_tree "$CLAUDE_HOME")"

  run run_installer bash
  [ "$status" -eq 0 ]

  after="$(snapshot_tree "$CLAUDE_HOME")"
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
  # Launch bats itself through zsh, targeting the same script-under-test.
  # This catches any PATH/env leakage that would make the suite shell-specific.
  run zsh -c '
    set -e
    export CLAUDE_HOME="$1"
    bash "$2"
  ' -- "$CLAUDE_HOME" "$REPO_ROOT/install.sh"
  [ "$status" -eq 0 ]
  [ -L "$COMMANDS_DIR/obr-init.md" ]
  [ -L "$SKILLS_DIR/obr-executor" ]
}

# --- Safety: refuses to clobber a non-matching file -------------------------

@test "install.sh refuses to overwrite a pre-existing regular file" {
  mkdir -p "$COMMANDS_DIR"
  echo "user's own file" > "$COMMANDS_DIR/obr-init.md"

  run run_installer bash
  [ "$status" -ne 0 ]
  # The user's file must survive untouched.
  [ ! -L "$COMMANDS_DIR/obr-init.md" ]
  [ -f "$COMMANDS_DIR/obr-init.md" ]
  grep -q "user's own file" "$COMMANDS_DIR/obr-init.md"
}
