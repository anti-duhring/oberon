#!/usr/bin/env bash
# Oberon uninstaller — removes symlinks from ~/.claude/ that point into this repo
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
COMMANDS_DIR="$CLAUDE_DIR/commands"
SKILLS_DIR="$CLAUDE_DIR/skills"

COMMANDS=("obr-init.md" "obr-start.md")
SKILLS=("obr-grill" "obr-prd")

log()  { printf '[oberon] %s\n' "$*"; }
err()  { printf '[oberon] error: %s\n' "$*" >&2; }

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

for cmd in "${COMMANDS[@]}"; do
  unlink_if_ours "$SRC_DIR/commands/$cmd" "$COMMANDS_DIR/$cmd"
done

for skill in "${SKILLS[@]}"; do
  unlink_if_ours "$SRC_DIR/skills/$skill" "$SKILLS_DIR/$skill"
done

log "done."
