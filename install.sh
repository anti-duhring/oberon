#!/usr/bin/env bash
# Oberon installer — symlinks skills into the Agents, Claude, and Codex skill
# roots and bin/oberon onto PATH. No plugins, no hooks, no slash-command install.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AGENTS_DIR="${AGENTS_HOME:-$HOME/.agents}"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
BIN_DIR="${OBERON_BIN_DIR:-$HOME/.local/bin}"

# ~/.agents/skills is the cross-harness (omp-native) root; the Claude and Codex
# user roots are opt-in per harness, so installing only there leaves the skills
# invisible to agents that ship those sources disabled.
AGENTS_SKILLS_DIR="$AGENTS_DIR/skills"
CLAUDE_SKILLS_DIR="$CLAUDE_DIR/skills"
CODEX_SKILLS_DIR="$CODEX_DIR/skills"

SKILLS=(
  oberon-grill
  oberon-sync
  oberon-status
  oberon-handoff
  oberon-delete
  write-a-skill
)

log()  { printf '[oberon] %s\n' "$*"; }
err()  { printf '[oberon] error: %s\n' "$*" >&2; }

# Refuse to clobber a non-symlink; accept an already-correct link as a no-op.
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

mkdir -p "$AGENTS_SKILLS_DIR" "$CLAUDE_SKILLS_DIR" "$CODEX_SKILLS_DIR" "$BIN_DIR"

status=0

for skill in "${SKILLS[@]}"; do
  src="$SRC_DIR/skills/$skill"
  if [ ! -d "$src" ]; then
    err "missing source: $src"
    status=1
    continue
  fi
  link "$src" "$AGENTS_SKILLS_DIR/$skill" || status=1
  link "$src" "$CLAUDE_SKILLS_DIR/$skill" || status=1
  link "$src" "$CODEX_SKILLS_DIR/$skill" || status=1
done

OBERON_BIN_SRC="$SRC_DIR/bin/oberon"
if [ ! -e "$OBERON_BIN_SRC" ]; then
  err "missing source: $OBERON_BIN_SRC"
  status=1
else
  link "$OBERON_BIN_SRC" "$BIN_DIR/oberon" || status=1
fi

# Warn (do not fail) when the bin dir is not on PATH.
case ":${PATH}:" in
  *":${BIN_DIR}:"*) ;;
  *)
    log "warn:  $BIN_DIR is not on \$PATH — add it so \`oberon\` resolves"
    ;;
esac

if [ "$status" -eq 0 ]; then
  log "done. Skills: oberon-grill, oberon-sync, oberon-status, oberon-handoff, oberon-delete (+ write-a-skill). CLI: oberon"
else
  err "completed with errors"
fi

exit "$status"
