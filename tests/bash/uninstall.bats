#!/usr/bin/env bats
#
# uninstall.sh safety: removes only the symlinks it created, leaves foreign
# files and foreign symlinks alone.
#
# Every test runs against isolated AGENTS_HOME / CLAUDE_HOME / CODEX_HOME /
# OBERON_BIN_DIR inside BATS_TEST_TMPDIR so the real home roots are untouched.

load 'helpers.bash'

setup() {
  setup_install_roots
}

# --- Behaviour: uninstall removes the symlinks install created -------------

@test "uninstall.sh removes all symlinks it owns" {
  run_installer bash >/dev/null
  run run_uninstaller bash
  [ "$status" -eq 0 ]

  assert_no_skill_links
  assert_no_bin_link
}

@test "uninstall.sh runs cleanly on a fresh root (nothing to remove)" {
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

@test "uninstall.sh leaves a foreign symlink at a known skill path untouched" {
  run_installer bash >/dev/null

  # Replace one of the install-owned symlinks with a symlink pointing
  # somewhere *outside* this repo. Uninstall must refuse to touch it.
  local foreign_target="$BATS_TEST_TMPDIR/elsewhere-skill"
  mkdir -p "$foreign_target"
  rm "$CLAUDE_SKILLS_DIR/oberon-grill"
  ln -s "$foreign_target" "$CLAUDE_SKILLS_DIR/oberon-grill"

  run run_uninstaller bash
  [ "$status" -eq 0 ]

  # Foreign symlink must survive with its original target.
  [ -L "$CLAUDE_SKILLS_DIR/oberon-grill" ]
  [ "$(readlink "$CLAUDE_SKILLS_DIR/oberon-grill")" = "$foreign_target" ]
  [ -d "$foreign_target" ]
}

@test "uninstall.sh leaves a foreign symlink at the bin path untouched" {
  run_installer bash >/dev/null

  local foreign_target="$BATS_TEST_TMPDIR/other-bin"
  echo "not ours" > "$foreign_target"
  rm "$BIN_DIR/oberon"
  ln -s "$foreign_target" "$BIN_DIR/oberon"

  run run_uninstaller bash
  [ "$status" -eq 0 ]

  [ -L "$BIN_DIR/oberon" ]
  [ "$(readlink "$BIN_DIR/oberon")" = "$foreign_target" ]
  [ -f "$foreign_target" ]
}

# --- Safety: regular files survive -----------------------------------------

@test "uninstall.sh leaves a regular file at a known path untouched" {
  mkdir -p "$CLAUDE_SKILLS_DIR"
  echo "user's own content" > "$CLAUDE_SKILLS_DIR/oberon-grill"

  run run_uninstaller bash
  [ "$status" -eq 0 ]

  [ -f "$CLAUDE_SKILLS_DIR/oberon-grill" ]
  [ ! -L "$CLAUDE_SKILLS_DIR/oberon-grill" ]
  grep -q "user's own content" "$CLAUDE_SKILLS_DIR/oberon-grill"
}

@test "uninstall.sh leaves unrelated files untouched" {
  run_installer bash >/dev/null

  # Drop an unrelated file and an unrelated symlink that uninstall.sh has no
  # reason to know about.
  echo "keep me" > "$CLAUDE_SKILLS_DIR/my-own-skill.md"
  local foreign_target="$BATS_TEST_TMPDIR/my-target"
  echo "external" > "$foreign_target"
  ln -s "$foreign_target" "$CLAUDE_SKILLS_DIR/my-own-symlink"
  echo "keep bin" > "$BIN_DIR/my-own-tool"

  run run_uninstaller bash
  [ "$status" -eq 0 ]

  [ -f "$CLAUDE_SKILLS_DIR/my-own-skill.md" ]
  grep -q "keep me" "$CLAUDE_SKILLS_DIR/my-own-skill.md"
  [ -L "$CLAUDE_SKILLS_DIR/my-own-symlink" ]
  [ "$(readlink "$CLAUDE_SKILLS_DIR/my-own-symlink")" = "$foreign_target" ]
  [ -f "$BIN_DIR/my-own-tool" ]
  grep -q "keep bin" "$BIN_DIR/my-own-tool"
}

# --- Shell-agnostic: suite works regardless of the invoking shell ----------

@test "uninstall.sh invoked via bats-under-zsh still succeeds" {
  if ! command -v zsh >/dev/null 2>&1; then
    skip "zsh not installed"
  fi
  run_installer bash >/dev/null
  run zsh -c '
    set -e
    export AGENTS_HOME="$1"
    export CLAUDE_HOME="$2"
    export CODEX_HOME="$3"
    export OBERON_BIN_DIR="$4"
    bash "$5"
  ' -- "$AGENTS_HOME" "$CLAUDE_HOME" "$CODEX_HOME" "$OBERON_BIN_DIR" "$REPO_ROOT/uninstall.sh"
  [ "$status" -eq 0 ]
  [ ! -L "$AGENTS_SKILLS_DIR/oberon-grill" ]
  [ ! -L "$CLAUDE_SKILLS_DIR/oberon-grill" ]
  [ ! -L "$CODEX_SKILLS_DIR/oberon-grill" ]
  [ ! -L "$BIN_DIR/oberon" ]
}

# --- Safety: uninstall respects env overrides ------------------------------

@test "uninstall.sh respects env overrides and does not touch \$HOME" {
  local custom_agents="$BATS_TEST_TMPDIR/custom-agents"
  local custom_claude="$BATS_TEST_TMPDIR/custom-claude"
  local custom_codex="$BATS_TEST_TMPDIR/custom-codex"
  local custom_bin="$BATS_TEST_TMPDIR/custom-bin"
  local fake_home="$BATS_TEST_TMPDIR/fake-home"
  mkdir -p "$fake_home"

  AGENTS_HOME="$custom_agents" \
    CLAUDE_HOME="$custom_claude" \
    CODEX_HOME="$custom_codex" \
    OBERON_BIN_DIR="$custom_bin" \
    HOME="$fake_home" \
    bash "$REPO_ROOT/install.sh"

  AGENTS_HOME="$custom_agents" \
    CLAUDE_HOME="$custom_claude" \
    CODEX_HOME="$custom_codex" \
    OBERON_BIN_DIR="$custom_bin" \
    HOME="$fake_home" \
    bash "$REPO_ROOT/uninstall.sh"

  [ ! -L "$custom_agents/skills/oberon-grill" ]
  [ ! -L "$custom_claude/skills/oberon-grill" ]
  [ ! -L "$custom_codex/skills/oberon-grill" ]
  [ ! -L "$custom_bin/oberon" ]
  [ ! -d "$fake_home/.agents" ]
  [ ! -d "$fake_home/.claude" ]
  [ ! -d "$fake_home/.codex" ]
  [ ! -d "$fake_home/.local" ]
}
