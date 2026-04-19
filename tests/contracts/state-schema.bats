#!/usr/bin/env bats
#
# state.json v1 schema contract.
#
# Locks the shape downstream commands rely on (obr-init, obr-plan, obr-phase,
# obr-status, the executor subagent, …) so accidental drift in any of them —
# renaming a field, dropping a status value, changing a type — fails this
# test before it can corrupt a live project's state.
#
# The assertions run against a canonical fixture under tests/fixtures/state/,
# never the repo's own .oberon/state.json, so the suite is reproducible on a
# clean clone and does not depend on the developer's Oberon project state.

# Resolve the repo root (two levels up from this file: tests/contracts/).
_oberon_contracts_dir="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
export REPO_ROOT="$(cd "$_oberon_contracts_dir/.." && cd .. && pwd)"
unset _oberon_contracts_dir

FIXTURE_VALID="$REPO_ROOT/tests/fixtures/state/state.json"
FIXTURE_INVALID="$REPO_ROOT/tests/fixtures/state/state.invalid.json"

# The v1 schema's valid enum values. Kept in sync with:
#   - commands/obr-init.md    (top-level phase enum, top-level shape)
#   - commands/obr-phase.md   (phase + task status values)
#   - skills/obr-planner/SKILL.md (per-task object shape)
VALID_PHASE_STATUSES="pending in_progress completed skipped failed"
VALID_TASK_STATUSES="pending completed skipped failed needs_input"

# validate_state_schema <path> — assert the given file is v1-schema-compliant.
# Exits 0 if valid, non-zero with a diagnostic on stderr otherwise. Does not
# shell-out with `set -e`; each jq check is explicit so failures point at the
# first violated invariant rather than the last.
validate_state_schema() {
  local file="$1"

  if [ ! -f "$file" ]; then
    echo "validate_state_schema: not a file: $file" >&2
    return 1
  fi

  # Must be well-formed JSON.
  if ! jq -e . "$file" >/dev/null 2>&1; then
    echo "validate_state_schema: invalid JSON: $file" >&2
    return 1
  fi

  # --- Top-level required fields with correct types ------------------------
  # version must be a number (v1 = 1).
  if [ "$(jq -r '.version | type' "$file")" != "number" ]; then
    echo "validate_state_schema: .version must be number" >&2
    return 1
  fi
  # phase must be a non-empty string.
  if [ "$(jq -r '.phase | type' "$file")" != "string" ] \
     || [ -z "$(jq -r '.phase' "$file")" ]; then
    echo "validate_state_schema: .phase must be non-empty string" >&2
    return 1
  fi
  # created_at, updated_at, project_name must be non-empty strings.
  local field
  for field in created_at updated_at project_name; do
    if [ "$(jq -r ".${field} | type" "$file")" != "string" ] \
       || [ -z "$(jq -r ".${field}" "$file")" ]; then
      echo "validate_state_schema: .${field} must be non-empty string" >&2
      return 1
    fi
  done
  # source is an object with .type (string) and .path (string or null).
  if [ "$(jq -r '.source | type' "$file")" != "object" ]; then
    echo "validate_state_schema: .source must be object" >&2
    return 1
  fi
  if [ "$(jq -r '.source.type | type' "$file")" != "string" ]; then
    echo "validate_state_schema: .source.type must be string" >&2
    return 1
  fi
  local src_path_type
  src_path_type="$(jq -r '.source.path | type' "$file")"
  if [ "$src_path_type" != "string" ] && [ "$src_path_type" != "null" ]; then
    echo "validate_state_schema: .source.path must be string or null" >&2
    return 1
  fi

  # --- phases.N.status ∈ VALID_PHASE_STATUSES ------------------------------
  # Only check phases if present (they don't exist pre-/obr-plan).
  if [ "$(jq -r '.phases | type' "$file")" = "object" ]; then
    local phase_statuses status
    phase_statuses="$(jq -r '.phases | to_entries[] | .value.status' "$file")"
    while IFS= read -r status; do
      [ -z "$status" ] && continue
      if ! printf '%s\n' $VALID_PHASE_STATUSES | grep -qx "$status"; then
        echo "validate_state_schema: invalid phase status: $status" >&2
        return 1
      fi
    done <<< "$phase_statuses"

    # --- phases.N.tasks.N-M.status ∈ VALID_TASK_STATUSES -------------------
    local task_statuses
    task_statuses="$(jq -r '
      .phases
      | to_entries[]
      | .value.tasks // {}
      | to_entries[]
      | .value.status
    ' "$file")"
    while IFS= read -r status; do
      [ -z "$status" ] && continue
      if ! printf '%s\n' $VALID_TASK_STATUSES | grep -qx "$status"; then
        echo "validate_state_schema: invalid task status: $status" >&2
        return 1
      fi
    done <<< "$task_statuses"
  fi

  return 0
}

# --- Preconditions ----------------------------------------------------------

@test "jq is available" {
  command -v jq >/dev/null 2>&1
}

@test "canonical fixture exists" {
  [ -f "$FIXTURE_VALID" ]
}

@test "invalid fixture exists" {
  [ -f "$FIXTURE_INVALID" ]
}

# --- Top-level shape --------------------------------------------------------

@test "fixture is well-formed JSON" {
  run jq -e . "$FIXTURE_VALID"
  [ "$status" -eq 0 ]
}

@test "fixture has .version as a number" {
  run jq -r '.version | type' "$FIXTURE_VALID"
  [ "$status" -eq 0 ]
  [ "$output" = "number" ]
}

@test "fixture has .phase as a non-empty string" {
  run jq -r '.phase' "$FIXTURE_VALID"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [ "$output" != "null" ]
}

@test "fixture has .created_at as a non-empty string" {
  run jq -r '.created_at' "$FIXTURE_VALID"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [ "$output" != "null" ]
}

@test "fixture has .updated_at as a non-empty string" {
  run jq -r '.updated_at' "$FIXTURE_VALID"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [ "$output" != "null" ]
}

@test "fixture has .project_name as a non-empty string" {
  run jq -r '.project_name' "$FIXTURE_VALID"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [ "$output" != "null" ]
}

@test "fixture has .source as an object with .type and .path" {
  [ "$(jq -r '.source | type' "$FIXTURE_VALID")" = "object" ]
  [ "$(jq -r '.source.type | type' "$FIXTURE_VALID")" = "string" ]
  local path_type
  path_type="$(jq -r '.source.path | type' "$FIXTURE_VALID")"
  [ "$path_type" = "string" ] || [ "$path_type" = "null" ]
}

# --- Mid-execution shape (AC: at least one phase in_progress, one task
# completed, one task pending) ---------------------------------------------

@test "fixture has at least one phase with status=in_progress" {
  run jq -r '[.phases[] | select(.status=="in_progress")] | length' "$FIXTURE_VALID"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "fixture has at least one task with status=completed" {
  run jq -r '
    [.phases[].tasks[]? | select(.status=="completed")] | length
  ' "$FIXTURE_VALID"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "fixture has at least one task with status=pending" {
  run jq -r '
    [.phases[].tasks[]? | select(.status=="pending")] | length
  ' "$FIXTURE_VALID"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# --- Enum validation: phase status -----------------------------------------

@test "every phase status is in the valid enum" {
  local statuses status
  statuses="$(jq -r '.phases[].status' "$FIXTURE_VALID")"
  [ -n "$statuses" ]
  while IFS= read -r status; do
    [ -z "$status" ] && continue
    # Bash word-split is intentional here: VALID_PHASE_STATUSES is a space-
    # delimited list, not an array, so `grep -qx` on one-per-line gives us a
    # clean membership check.
    printf '%s\n' $VALID_PHASE_STATUSES | grep -qx "$status" \
      || { echo "invalid phase status: $status"; return 1; }
  done <<< "$statuses"
}

# --- Enum validation: task status ------------------------------------------

@test "every task status is in the valid enum" {
  local statuses status
  statuses="$(jq -r '.phases[].tasks[]?.status' "$FIXTURE_VALID")"
  [ -n "$statuses" ]
  while IFS= read -r status; do
    [ -z "$status" ] && continue
    printf '%s\n' $VALID_TASK_STATUSES | grep -qx "$status" \
      || { echo "invalid task status: $status"; return 1; }
  done <<< "$statuses"
}

# --- Aggregate validator: valid fixture passes, invalid fixture fails ------
#
# This is the "mutated-fixture spot-check" from the AC: we point the same
# validator at a corrupted fixture (invalid task status) and assert it
# rejects it. If the validator ever starts accepting bad input, this test
# fails — catching schema drift in the *validator itself*, not just the
# fixture.

@test "validate_state_schema accepts the canonical fixture" {
  validate_state_schema "$FIXTURE_VALID"
}

@test "validate_state_schema rejects the mutated fixture" {
  run validate_state_schema "$FIXTURE_INVALID"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid task status"* ]]
}
