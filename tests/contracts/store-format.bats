#!/usr/bin/env bats
#
# Pins oberon status parsing to the DECISIONS.md / PROGRESS.md shapes that
# skills/oberon-grill and skills/oberon-sync actually prescribe.
#
# Fixtures under tests/fixtures/store/ are copied from those skill sections
# (and from `oberon init` for the empty skeleton). Do not invent new shapes
# here — if a skill rewords its example, re-sync the fixture and the parser.
#
# Hermetic: every test sets OBERON_HOME under BATS_TEST_TMPDIR.

_oberon_contracts_dir="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
export REPO_ROOT="$(cd "$_oberon_contracts_dir/.." && cd .. && pwd)"
unset _oberon_contracts_dir

OBERON_BIN="${OBERON_BIN:-$REPO_ROOT/bin/oberon}"
FIXTURE_DIR="$REPO_ROOT/tests/fixtures/store"
GRILL_SKILL="$REPO_ROOT/skills/oberon-grill/SKILL.md"
SYNC_SKILL="$REPO_ROOT/skills/oberon-sync/SKILL.md"

setup() {
  export OBERON_HOME="${BATS_TEST_TMPDIR}/oberon-home"
  mkdir -p "$OBERON_HOME"
}

oberon() {
  "$OBERON_BIN" "$@"
}

# Copy fixture over the store's DECISIONS.md or PROGRESS.md.
install_fixture() {
  local id="$1"
  local fixture="$2"
  local target="$3"
  cp "$FIXTURE_DIR/$fixture" "$OBERON_HOME/$id/$target"
}

# ---------------------------------------------------------------------------
# Skill-doc drift guard
# ---------------------------------------------------------------------------

@test "skill docs still show table-form, heading-form, and dated entry shapes" {
  # Structural patterns only — innocent prose rewording must not trip this.
  # Table row: a markdown cell opening with **D<n>**
  if ! grep -E '\|[[:space:]]*\*\*D[0-9]+\*\*' "$GRILL_SKILL" >/dev/null; then
    echo "skills/oberon-grill/SKILL.md lost its table-form D-row example." >&2
    echo "Re-sync tests/fixtures/store/ and bin/oberon status parsing with the skill's documented DECISIONS.md shape." >&2
    return 1
  fi
  # Heading: ### D<n> — …
  if ! grep -E '^#{1,6}[[:space:]]+D[0-9]+([^0-9]|$)' "$GRILL_SKILL" >/dev/null; then
    echo "skills/oberon-grill/SKILL.md lost its heading-form D example." >&2
    echo "Re-sync tests/fixtures/store/ and bin/oberon status parsing with the skill's documented DECISIONS.md shape." >&2
    return 1
  fi
  # Dated journal entry: ### YYYY-MM-DD …
  if ! grep -E '^#{2,3}[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2}' "$SYNC_SKILL" >/dev/null; then
    echo "skills/oberon-sync/SKILL.md lost its ###-style dated entry example." >&2
    echo "Re-sync tests/fixtures/store/ and bin/oberon status parsing with the skill's documented PROGRESS.md shape." >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# DECISIONS.md shapes
# ---------------------------------------------------------------------------

@test "table-form decisions: count and numeric last_ids (D7 before D12)" {
  local id
  id="$(oberon init --name "Table Form" --id "fx-table")"
  install_fixture "$id" "DECISIONS.table.md" "DECISIONS.md"

  run oberon status "$id"
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null

  [ "$(jq -r '.[0].decisions.count' <<<"$output")" -eq 2 ]
  # File order is D12 then D7; last_ids must be numeric, not file order.
  [ "$(jq -c '.[0].decisions.last_ids' <<<"$output")" = '["D7","D12"]' ]
}

@test "heading-form decisions: count ignores Supersedes and prose D99" {
  local id
  id="$(oberon init --name "Heading Form" --id "fx-headings")"
  install_fixture "$id" "DECISIONS.headings.md" "DECISIONS.md"

  run oberon status "$id"
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null

  # Only D12 and D7 headings count — not "Supersedes D11" and not prose D99.
  [ "$(jq -r '.[0].decisions.count' <<<"$output")" -eq 2 ]
  [ "$(jq -c '.[0].decisions.last_ids' <<<"$output")" = '["D7","D12"]' ]
  # Explicitly: neither D11 nor D99 appear in last_ids or as extra count.
  jq -e '.[0].decisions.last_ids | index("D11") == null and index("D99") == null' \
    <<<"$output" >/dev/null
}

@test "mixed-form decisions: table and heading anchors both count" {
  local id
  id="$(oberon init --name "Mixed Form" --id "fx-mixed")"
  install_fixture "$id" "DECISIONS.mixed.md" "DECISIONS.md"

  run oberon status "$id"
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null

  [ "$(jq -r '.[0].decisions.count' <<<"$output")" -eq 2 ]
  [ "$(jq -c '.[0].decisions.last_ids' <<<"$output")" = '["D7","D12"]' ]
}

@test "empty seeded DECISIONS: count 0 and comment D1/D2 not counted" {
  local id
  id="$(oberon init --name "Empty Seed" --id "fx-empty")"
  install_fixture "$id" "DECISIONS.empty.md" "DECISIONS.md"

  # Fixture must still carry the init comment that names D1, D2.
  grep -q 'D1, D2' "$OBERON_HOME/$id/DECISIONS.md"

  run oberon status "$id"
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null

  [ "$(jq -r '.[0].decisions.count' <<<"$output")" -eq 0 ]
  [ "$(jq -c '.[0].decisions.last_ids' <<<"$output")" = '[]' ]
}

# ---------------------------------------------------------------------------
# PROGRESS.md shapes
# ---------------------------------------------------------------------------

@test "PROGRESS.sync: current_state stops at ### entry; entry_count and last heading" {
  local id
  id="$(oberon init --name "Progress Sync" --id "fx-psync")"
  install_fixture "$id" "PROGRESS.sync.md" "PROGRESS.md"

  run oberon status "$id"
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null

  local state
  state="$(jq -r '.[0].progress.current_state' <<<"$output")"
  [ "$state" != "null" ]
  [[ "$state" == *"Design settled on the queue."* ]]
  [[ "$state" == *"Code lives on feature/x"* ]]
  # Must terminate before the first ### YYYY-MM-DD entry (no year leak).
  # Use grep (not bash [[ ]]) so a multi-line current_state leak fails loudly.
  if printf '%s' "$state" | grep -qE '2026|list route|tag bump'; then
    echo "progress.current_state leaked journal content:" >&2
    printf '%s
' "$state" >&2
    return 1
  fi

  [ "$(jq -r '.[0].progress.entry_count' <<<"$output")" -eq 2 ]
  # Append-only: newest is last in file order.
  [ "$(jq -r '.[0].progress.last_entry_heading' <<<"$output")" \
    = "### 2026-09-02 19:15Z — tag bump discharged" ]
}

@test "PROGRESS.nostate: current_state is null; entry_count still correct" {
  local id
  id="$(oberon init --name "Progress No State" --id "fx-pnostate")"
  install_fixture "$id" "PROGRESS.nostate.md" "PROGRESS.md"

  run oberon status "$id"
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null

  [ "$(jq -r '.[0].progress.current_state' <<<"$output")" = "null" ]
  [ "$(jq -r '.[0].progress.current_state | type' <<<"$output")" = "null" ]
  [ "$(jq -r '.[0].progress.entry_count' <<<"$output")" -eq 2 ]
  [ "$(jq -r '.[0].progress.last_entry_heading' <<<"$output")" \
    = "### 2026-09-02 18:40Z — list route + 403 gate" ]
}
