#!/usr/bin/env bash
# Oberon installer — symlinks commands and skills into ~/.claude/
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
COMMANDS_DIR="$CLAUDE_DIR/commands"
SKILLS_DIR="$CLAUDE_DIR/skills"

COMMANDS=("obr-init.md" "obr-spec.md" "obr-plan.md" "obr-phase.md" "obr-archive.md")
SKILLS=("obr-grill" "obr-prd" "obr-planner" "obr-executor")

log()  { printf '[oberon] %s\n' "$*"; }
err()  { printf '[oberon] error: %s\n' "$*" >&2; }

mkdir -p "$COMMANDS_DIR" "$SKILLS_DIR"

link() {
  local src="$1"
  local dst="$2"

  if [ -L "$dst" ]; then
    local current
    current="$(readlink "$dst")"
    if [ "$current" = "$src" ]; then
      log "ok:    $dst -> $src"
      return 0
    fi
    err "symlink at $dst points to $current (expected $src). Remove it and re-run."
    return 1
  fi

  if [ -e "$dst" ]; then
    err "$dst exists and is not a symlink. Refusing to overwrite. Move it aside and re-run."
    return 1
  fi

  ln -s "$src" "$dst"
  log "link:  $dst -> $src"
}

status=0

for cmd in "${COMMANDS[@]}"; do
  src="$SRC_DIR/commands/$cmd"
  dst="$COMMANDS_DIR/$cmd"
  if [ ! -f "$src" ]; then
    err "missing source: $src"
    status=1
    continue
  fi
  link "$src" "$dst" || status=1
done

for skill in "${SKILLS[@]}"; do
  src="$SRC_DIR/skills/$skill"
  dst="$SKILLS_DIR/$skill"
  if [ ! -d "$src" ]; then
    err "missing source: $src"
    status=1
    continue
  fi
  link "$src" "$dst" || status=1
done

if [ "$status" -eq 0 ]; then
  log "done. Commands: /obr-init, /obr-spec, /obr-plan, /obr-phase, /obr-archive"
else
  err "completed with errors"
fi

exit "$status"
