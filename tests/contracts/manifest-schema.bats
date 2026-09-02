#!/usr/bin/env bats
#
# project.json (manifest) schema contract for Oberon v2.
#
# Locks the shape bin/oberon and the five skills rely on so accidental drift
# — renaming a field, dropping a status value, changing a type — fails here
# before it can corrupt a live store.
#
# Assertions run against fixtures under tests/fixtures/manifest/, never a
# real ~/.oberon store.

_oberon_contracts_dir="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
export REPO_ROOT="$(cd "$_oberon_contracts_dir/.." && cd .. && pwd)"
unset _oberon_contracts_dir

FIXTURE_VALID="$REPO_ROOT/tests/fixtures/manifest/project.valid.json"
FIXTURE_INVALID="$REPO_ROOT/tests/fixtures/manifest/project.invalid.json"

VALID_STATUSES="active closed"

# validate_manifest_schema <path>
# Exits 0 if valid, non-zero with a diagnostic on stderr otherwise.
validate_manifest_schema() {
  local file="$1"

  if [ ! -f "$file" ]; then
    echo "validate_manifest_schema: not a file: $file" >&2
    return 1
  fi

  if ! jq -e . "$file" >/dev/null 2>&1; then
    echo "validate_manifest_schema: invalid JSON: $file" >&2
    return 1
  fi

  if [ "$(jq -r '.schema | type' "$file")" != "number" ]; then
    echo "validate_manifest_schema: .schema must be number" >&2
    return 1
  fi
  if [ "$(jq -r '.schema' "$file")" != "1" ]; then
    echo "validate_manifest_schema: .schema must be 1" >&2
    return 1
  fi

  local field
  for field in project_id project_name project_status created_at updated_at; do
    if [ "$(jq -r ".${field} | type" "$file")" != "string" ] \
       || [ -z "$(jq -r ".${field}" "$file")" ] \
       || [ "$(jq -r ".${field}" "$file")" = "null" ]; then
      echo "validate_manifest_schema: .${field} must be non-empty string" >&2
      return 1
    fi
  done

  local st
  st="$(jq -r '.project_status' "$file")"
  if ! printf '%s\n' $VALID_STATUSES | grep -qx "$st"; then
    echo "validate_manifest_schema: invalid project_status: $st" >&2
    return 1
  fi

  if [ "$(jq -r '.contributing_repos | type' "$file")" != "array" ]; then
    echo "validate_manifest_schema: .contributing_repos must be array" >&2
    return 1
  fi

  # Each contributing repo needs name + path strings; remote may be string or null.
  local n i
  n="$(jq -r '.contributing_repos | length' "$file")"
  i=0
  while [ "$i" -lt "$n" ]; do
    if [ "$(jq -r ".contributing_repos[$i].name | type" "$file")" != "string" ]; then
      echo "validate_manifest_schema: contributing_repos[$i].name must be string" >&2
      return 1
    fi
    if [ "$(jq -r ".contributing_repos[$i].path | type" "$file")" != "string" ]; then
      echo "validate_manifest_schema: contributing_repos[$i].path must be string" >&2
      return 1
    fi
    local rt
    rt="$(jq -r ".contributing_repos[$i].remote | type" "$file")"
    if [ "$rt" != "string" ] && [ "$rt" != "null" ]; then
      echo "validate_manifest_schema: contributing_repos[$i].remote must be string or null" >&2
      return 1
    fi
    i=$((i + 1))
  done

  # push_remote is string or null
  local prt
  prt="$(jq -r '.push_remote | type' "$file")"
  if [ "$prt" != "string" ] && [ "$prt" != "null" ]; then
    echo "validate_manifest_schema: .push_remote must be string or null" >&2
    return 1
  fi

  return 0
}

@test "jq is available" {
  command -v jq >/dev/null 2>&1
}

@test "canonical fixture exists" {
  [ -f "$FIXTURE_VALID" ]
}

@test "invalid fixture exists" {
  [ -f "$FIXTURE_INVALID" ]
}

@test "fixture is well-formed JSON" {
  run jq -e . "$FIXTURE_VALID"
  [ "$status" -eq 0 ]
}

@test "fixture has .schema == 1" {
  [ "$(jq -r '.schema' "$FIXTURE_VALID")" = "1" ]
}

@test "fixture has .project_id as a non-empty string" {
  local v
  v="$(jq -r '.project_id' "$FIXTURE_VALID")"
  [ -n "$v" ]
  [ "$v" != "null" ]
}

@test "fixture has .project_status in {active,closed}" {
  local st
  st="$(jq -r '.project_status' "$FIXTURE_VALID")"
  printf '%s\n' $VALID_STATUSES | grep -qx "$st"
}

@test "fixture has .contributing_repos as an array" {
  [ "$(jq -r '.contributing_repos | type' "$FIXTURE_VALID")" = "array" ]
}

@test "fixture contributing_repos entries have name, remote, path" {
  local n
  n="$(jq -r '.contributing_repos | length' "$FIXTURE_VALID")"
  [ "$n" -ge 1 ]
  [ "$(jq -r '.contributing_repos[0].name | type' "$FIXTURE_VALID")" = "string" ]
  [ "$(jq -r '.contributing_repos[0].path | type' "$FIXTURE_VALID")" = "string" ]
  local rt
  rt="$(jq -r '.contributing_repos[0].remote | type' "$FIXTURE_VALID")"
  [ "$rt" = "string" ] || [ "$rt" = "null" ]
}

@test "fixture has .push_remote null or string" {
  local t
  t="$(jq -r '.push_remote | type' "$FIXTURE_VALID")"
  [ "$t" = "null" ] || [ "$t" = "string" ]
}

@test "validate_manifest_schema accepts the canonical fixture" {
  validate_manifest_schema "$FIXTURE_VALID"
}

@test "validate_manifest_schema rejects the mutated fixture" {
  run validate_manifest_schema "$FIXTURE_INVALID"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid project_status"* ]] || [[ "$output" == *"contributing_repos must be array"* ]]
}
