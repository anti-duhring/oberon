#!/usr/bin/env bash
# Oberon uninstaller — removes only symlinks that point into this repo
# from Agents skills, Claude skills, Codex skills, and the bin dir.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AGENTS_DIR="${AGENTS_HOME:-$HOME/.agents}"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
BIN_DIR="${OBERON_BIN_DIR:-$HOME/.local/bin}"

AGENTS_SKILLS_DIR="$AGENTS_DIR/skills"
CLAUDE_SKILLS_DIR="$CLAUDE_DIR/skills"
CODEX_SKILLS_DIR="$CODEX_DIR/skills"

SKILLS=(
  oberon-grill
  oberon-sync
  oberon-status
  oberon-test
  oberon-handoff
  oberon-delete
  write-a-skill
)

log()  { printf '[oberon] %s\n' "$*"; }

# Remove dst only when it is a symlink whose target equals src.
unlink_if_ours() {
  local src="$1"
  local dst="$2"

  if [ ! -L "$dst" ]; then
    if [ -e "$dst" ]; then
      log "skip:  $dst is not a symlink (not touching)"
    fi
    return 0
  fi

  local current
  current="$(readlink "$dst")"
  if [ "$current" = "$src" ]; then
    rm "$dst"
    log "rm:    $dst"
  else
    log "skip:  $dst points to $current (not ours)"
  fi
}

for skill in "${SKILLS[@]}"; do
  src="$SRC_DIR/skills/$skill"
  unlink_if_ours "$src" "$AGENTS_SKILLS_DIR/$skill"
  unlink_if_ours "$src" "$CLAUDE_SKILLS_DIR/$skill"
  unlink_if_ours "$src" "$CODEX_SKILLS_DIR/$skill"
done

unlink_if_ours "$SRC_DIR/bin/oberon" "$BIN_DIR/oberon"

log "done."
