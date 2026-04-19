#!/usr/bin/env bats
#
# uninstall.sh safety: removes only the symlinks it created, leaves foreign
# files and foreign symlinks alone.
#
# Every test runs against an isolated CLAUDE_HOME inside BATS_TEST_TMPDIR so
# the real ~/.claude/ is untouched.

load 'helpers.bash'

setup() {
  setup_claude_home
}

# --- Behaviour: uninstall removes the symlinks install created -------------

@test "uninstall.sh removes all symlinks it owns" {
  run_installer bash >/dev/null
  run run_uninstaller bash
  [ "$status" -eq 0 ]

  # Every entry uninstall.sh knows about must be gone.
  for cmd in "${OBERON_UNINSTALL_COMMANDS[@]}"; do
    [ ! -e "$COMMANDS_DIR/$cmd" ] && [ ! -L "$COMMANDS_DIR/$cmd" ]
  done
  for skill in "${OBERON_SKILLS[@]}"; do
    [ ! -e "$SKILLS_DIR/$skill" ] && [ ! -L "$SKILLS_DIR/$skill" ]
  done
}

@test "uninstall.sh runs cleanly on a fresh CLAUDE_HOME (nothing to remove)" {
  run run_uninstaller bash
  [ "$status" -eq 0 ]
}

@test "uninstall.sh is idempotent — second run is still a no-op success" {
  run_installer bash >/dev/null
  run_uninstaller bash >/dev/null
  run run_uninstaller bash
  [ "$status" -eq 0 ]
}

# --- Safety: foreign symlinks survive --------------------------------------

@test "uninstall.sh leaves a foreign symlink at a known path untouched" {
  run_installer bash >/dev/null

  # Replace one of the install-owned symlinks with a symlink pointing
  # somewhere *outside* this repo. Uninstall must refuse to touch it.
  local foreign_target="$BATS_TEST_TMPDIR/elsewhere.md"
  echo "not ours" > "$foreign_target"
  rm "$COMMANDS_DIR/obr-init.md"
  ln -s "$foreign_target" "$COMMANDS_DIR/obr-init.md"

  run run_uninstaller bash
  [ "$status" -eq 0 ]

  # Foreign symlink must survive with its original target.
  [ -L "$COMMANDS_DIR/obr-init.md" ]
  [ "$(readlink "$COMMANDS_DIR/obr-init.md")" = "$foreign_target" ]
  [ -f "$foreign_target" ]
}

@test "uninstall.sh leaves a foreign symlink at a skill path untouched" {
  run_installer bash >/dev/null

  local foreign_target="$BATS_TEST_TMPDIR/other-skill"
  mkdir -p "$foreign_target"
  rm "$SKILLS_DIR/obr-executor"
  ln -s "$foreign_target" "$SKILLS_DIR/obr-executor"

  run run_uninstaller bash
  [ "$status" -eq 0 ]

  [ -L "$SKILLS_DIR/obr-executor" ]
  [ "$(readlink "$SKILLS_DIR/obr-executor")" = "$foreign_target" ]
  [ -d "$foreign_target" ]
}

# --- Safety: regular files survive -----------------------------------------

@test "uninstall.sh leaves a regular file at a known path untouched" {
  mkdir -p "$COMMANDS_DIR"
  echo "user's own content" > "$COMMANDS_DIR/obr-init.md"

  run run_uninstaller bash
  [ "$status" -eq 0 ]

  [ -f "$COMMANDS_DIR/obr-init.md" ]
  [ ! -L "$COMMANDS_DIR/obr-init.md" ]
  grep -q "user's own content" "$COMMANDS_DIR/obr-init.md"
}

@test "uninstall.sh leaves unrelated files in CLAUDE_HOME untouched" {
  run_installer bash >/dev/null

  # Drop an unrelated file and an unrelated symlink into CLAUDE_HOME that
  # uninstall.sh has no reason to know about.
  echo "keep me" > "$COMMANDS_DIR/my-own-command.md"
  local foreign_target="$BATS_TEST_TMPDIR/my-target"
  echo "external" > "$foreign_target"
  ln -s "$foreign_target" "$COMMANDS_DIR/my-own-symlink.md"

  run run_uninstaller bash
  [ "$status" -eq 0 ]

  [ -f "$COMMANDS_DIR/my-own-command.md" ]
  grep -q "keep me" "$COMMANDS_DIR/my-own-command.md"
  [ -L "$COMMANDS_DIR/my-own-symlink.md" ]
  [ "$(readlink "$COMMANDS_DIR/my-own-symlink.md")" = "$foreign_target" ]
}

# --- Shell-agnostic: suite works regardless of the invoking shell ----------

@test "uninstall.sh invoked via bats-under-zsh still succeeds" {
  if ! command -v zsh >/dev/null 2>&1; then
    skip "zsh not installed"
  fi
  run_installer bash >/dev/null
  run zsh -c '
    set -e
    export CLAUDE_HOME="$1"
    bash "$2"
  ' -- "$CLAUDE_HOME" "$REPO_ROOT/uninstall.sh"
  [ "$status" -eq 0 ]
  [ ! -L "$COMMANDS_DIR/obr-init.md" ]
  [ ! -L "$SKILLS_DIR/obr-executor" ]
}

# --- Safety: uninstall respects a CLAUDE_HOME override ---------------------

@test "uninstall.sh respects a CLAUDE_HOME override and does not touch \$HOME" {
  local custom="$BATS_TEST_TMPDIR/custom-claude"
  CLAUDE_HOME="$custom" HOME="$BATS_TEST_TMPDIR/fake-home" \
    bash "$REPO_ROOT/install.sh"

  CLAUDE_HOME="$custom" HOME="$BATS_TEST_TMPDIR/fake-home" \
    bash "$REPO_ROOT/uninstall.sh"

  [ ! -L "$custom/commands/obr-init.md" ]
  [ ! -d "$BATS_TEST_TMPDIR/fake-home/.claude" ]
}
