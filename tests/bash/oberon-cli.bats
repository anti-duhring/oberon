#!/usr/bin/env bats
#
# bin/oberon CLI behaviour.
#
# Every test sets OBERON_HOME to a private mktemp dir under BATS_TEST_TMPDIR
# so the real ~/.oberon is never touched.

_oberon_tests_bash_dir="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
export REPO_ROOT="$(cd "$_oberon_tests_bash_dir/../.." && pwd)"
unset _oberon_tests_bash_dir

OBERON_BIN="$REPO_ROOT/bin/oberon"

setup() {
  export OBERON_HOME="${BATS_TEST_TMPDIR}/oberon-home"
  mkdir -p "$OBERON_HOME"
  # Isolated contributing repo for attach/resolve/repo-info.
  export FAKE_REPO="${BATS_TEST_TMPDIR}/fake-repo"
  mkdir -p "$FAKE_REPO"
  git -C "$FAKE_REPO" init -q
  git -C "$FAKE_REPO" config user.name "Test"
  git -C "$FAKE_REPO" config user.email "test@example.com"
  echo "hello" >"$FAKE_REPO/README"
  git -C "$FAKE_REPO" add README
  git -C "$FAKE_REPO" commit -q -m "init"
  git -C "$FAKE_REPO" remote add origin "git@github.com:example/fake-repo.git"
}

oberon() {
  "$OBERON_BIN" "$@"
}

@test "bash -n bin/oberon is clean" {
  bash -n "$OBERON_BIN"
}

@test "bin/oberon is executable" {
  [ -x "$OBERON_BIN" ]
}

@test "home prints OBERON_HOME" {
  run oberon home
  [ "$status" -eq 0 ]
  [ "$output" = "$OBERON_HOME" ]
}

@test "unknown command exits non-zero" {
  run oberon totally-bogus
  [ "$status" -ne 0 ]
}

@test "init creates four files and exactly one commit" {
  run oberon init --name "ALT-120 reminder workflow" --repo "$FAKE_REPO"
  [ "$status" -eq 0 ]
  local id="$output"
  [ -n "$id" ]

  local dir="$OBERON_HOME/$id"
  [ -f "$dir/project.json" ]
  [ -f "$dir/DECISIONS.md" ]
  [ -f "$dir/PROGRESS.md" ]
  [ -f "$dir/HANDOFF.md" ]

  # Exactly one commit in the store repo
  local count
  count="$(git -C "$OBERON_HOME" rev-list --count HEAD)"
  [ "$count" -eq 1 ]

  # Manifest shape
  [ "$(jq -r '.schema' "$dir/project.json")" = "1" ]
  [ "$(jq -r '.project_id' "$dir/project.json")" = "$id" ]
  [ "$(jq -r '.project_status' "$dir/project.json")" = "active" ]
  [ "$(jq -r '.project_name' "$dir/project.json")" = "ALT-120 reminder workflow" ]

  # PROGRESS has Current state header
  grep -q '## Current state' "$dir/PROGRESS.md"
}

@test "init with taken --id exits 3" {
  run oberon init --name "first" --id "taken-id-aaaa"
  [ "$status" -eq 0 ]
  [ "$output" = "taken-id-aaaa" ]

  run oberon init --name "second" --id "taken-id-aaaa"
  [ "$status" -eq 3 ]
}

@test "list prints TSV of active projects" {
  local id
  id="$(oberon init --name "List Me")"
  run oberon list
  [ "$status" -eq 0 ]
  [[ "$output" == *"$id"$'\t'"active"$'\t'"List Me"* ]] || [[ "$output" == *"$id	active	List Me"* ]]
}

@test "resolve finds project by remote URL" {
  local id
  id="$(oberon init --name "By Remote" --repo "$FAKE_REPO")"

  # A second clone-like path with the same origin remote should still match
  local other="${BATS_TEST_TMPDIR}/other-checkout"
  mkdir -p "$other"
  git -C "$other" init -q
  git -C "$other" remote add origin "git@github.com:example/fake-repo.git"

  run oberon resolve --repo "$other"
  [ "$status" -eq 0 ]
  [ "$output" = "$id" ]
}

@test "resolve finds project by absolute path" {
  # Repo with no remote — path match only
  local bare="${BATS_TEST_TMPDIR}/path-only-repo"
  mkdir -p "$bare"
  git -C "$bare" init -q
  git -C "$bare" config user.name "Test"
  git -C "$bare" config user.email "test@example.com"
  echo x >"$bare/f"
  git -C "$bare" add f
  git -C "$bare" commit -q -m "init"

  local id
  id="$(oberon init --name "By Path" --repo "$bare")"

  run oberon resolve --repo "$bare"
  [ "$status" -eq 0 ]
  [ "$output" = "$id" ]
}

@test "resolve exits 4 when nothing matches" {
  local orphan="${BATS_TEST_TMPDIR}/orphan-repo"
  mkdir -p "$orphan"
  git -C "$orphan" init -q
  git -C "$orphan" remote add origin "git@github.com:example/orphan.git"

  oberon init --name "Unrelated" >/dev/null

  run oberon resolve --repo "$orphan"
  [ "$status" -eq 4 ]
}

@test "path prints absolute store directory" {
  local id
  id="$(oberon init --name "Path Me")"
  run oberon path "$id"
  [ "$status" -eq 0 ]
  [ "$output" = "$OBERON_HOME/$id" ]
}

@test "path unknown id exits 5" {
  run oberon path "no-such-project-zzzz"
  [ "$status" -eq 5 ]
}

@test "repo-info reports dirty:false for a clean repo" {
  run oberon repo-info "$FAKE_REPO"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.dirty' <<<"$output")" = "false" ]
  [ "$(jq -r '.dirty | type' <<<"$output")" = "boolean" ]
  [ "$(jq -r '.branch' <<<"$output")" != "null" ]
  [ -n "$(jq -r '.sha' <<<"$output")" ]
}

@test "repo-info reports dirty:true for a dirty repo" {
  echo "change" >>"$FAKE_REPO/README"
  run oberon repo-info "$FAKE_REPO"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.dirty' <<<"$output")" = "true" ]
  [ "$(jq -r '.dirty | type' <<<"$output")" = "boolean" ]
}

@test "repo-info non-repo exits 5" {
  run oberon repo-info "${BATS_TEST_TMPDIR}/not-a-repo"
  [ "$status" -eq 5 ]
}

@test "attach is idempotent and commits" {
  local id
  id="$(oberon init --name "Attach Me")"
  local before
  before="$(git -C "$OBERON_HOME" rev-list --count HEAD)"

  run oberon attach "$id" --repo "$FAKE_REPO"
  [ "$status" -eq 0 ]
  local mid
  mid="$(git -C "$OBERON_HOME" rev-list --count HEAD)"
  [ "$mid" -gt "$before" ]

  # Second attach is idempotent (still succeeds)
  run oberon attach "$id" --repo "$FAKE_REPO"
  [ "$status" -eq 0 ]

  local n
  n="$(jq -r '.contributing_repos | length' "$OBERON_HOME/$id/project.json")"
  [ "$n" -eq 1 ]
}

@test "set updates status" {
  local id
  id="$(oberon init --name "Set Me")"
  run oberon set "$id" --status closed
  [ "$status" -eq 0 ]
  [ "$(jq -r '.project_status' "$OBERON_HOME/$id/project.json")" = "closed" ]

  run oberon list --status closed
  [ "$status" -eq 0 ]
  [[ "$output" == *"$id"* ]]
}

@test "commit with nothing staged creates no commit" {
  local id before after
  id="$(oberon init --name "Commit Noop")"
  before="$(git -C "$OBERON_HOME" rev-list --count HEAD)"

  run oberon commit "$id" -m "should be noop"
  [ "$status" -eq 0 ]
  after="$(git -C "$OBERON_HOME" rev-list --count HEAD)"
  [ "$after" -eq "$before" ]

  # Dirty tree does create a commit
  echo "note" >>"$OBERON_HOME/$id/DECISIONS.md"
  run oberon commit "$id" -m "real change"
  [ "$status" -eq 0 ]
  after="$(git -C "$OBERON_HOME" rev-list --count HEAD)"
  [ "$after" -eq $((before + 1)) ]
}

@test "delete without --yes exits 6" {
  local id
  id="$(oberon init --name "Delete Guard")"
  run oberon delete "$id"
  [ "$status" -eq 6 ]
  [ -d "$OBERON_HOME/$id" ]
}

@test "delete with --yes removes directory but keeps history" {
  local id
  id="$(oberon init --name "Delete Me")"
  [ -d "$OBERON_HOME/$id" ]

  # Capture a blob that must remain reachable via log/history
  local marker="unique-marker-for-delete-test-$$"
  echo "$marker" >>"$OBERON_HOME/$id/DECISIONS.md"
  oberon commit "$id" -m "add marker"

  run oberon delete "$id" --yes
  [ "$status" -eq 0 ]
  [ ! -d "$OBERON_HOME/$id" ]

  # History still contains the content
  run git -C "$OBERON_HOME" log --all -p
  [ "$status" -eq 0 ]
  [[ "$output" == *"$marker"* ]]
  [[ "$output" == *"Delete Me"* ]] || [[ "$output" == *"$id"* ]]
}

@test "status <id> emits JSON array of length 1" {
  local id
  id="$(oberon init --name "Status One" --repo "$FAKE_REPO")"

  run oberon status "$id"
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null
  [ "$(jq 'length' <<<"$output")" -eq 1 ]
  [ "$(jq -r '.[0].project_id' <<<"$output")" = "$id" ]
  [ "$(jq -r '.[0].store_path' <<<"$output")" = "$OBERON_HOME/$id" ]
}

@test "status with no arg reports every project claiming current repo" {
  local id1 id2
  id1="$(oberon init --name "Claim A" --repo "$FAKE_REPO")"
  id2="$(oberon init --name "Claim B" --repo "$FAKE_REPO")"

  cd "$FAKE_REPO"
  run oberon status
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null
  [ "$(jq 'length' <<<"$output")" -eq 2 ]
  # Both ids present (order not specified)
  jq -e --arg a "$id1" --arg b "$id2" '
    map(.project_id) | index($a) != null and index($b) != null
  ' <<<"$output" >/dev/null
}

@test "status exits 4 when no project claims repo; unknown id exits 5" {
  local orphan="${BATS_TEST_TMPDIR}/status-orphan"
  mkdir -p "$orphan"
  git -C "$orphan" init -q
  git -C "$orphan" remote add origin "git@github.com:example/status-orphan.git"
  oberon init --name "Elsewhere" >/dev/null

  cd "$orphan"
  run oberon status
  [ "$status" -eq 4 ]

  run oberon status "no-such-project-zzzz"
  [ "$status" -eq 5 ]
}

@test "status decisions.count and last_ids for populated and empty DECISIONS.md" {
  local id
  id="$(oberon init --name "Decisions Shape" --repo "$FAKE_REPO")"
  local dir="$OBERON_HOME/$id"

  # Seed file is empty of D-headings
  run oberon status "$id"
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null
  [ "$(jq -r '.[0].decisions.count' <<<"$output")" -eq 0 ]
  [ "$(jq -c '.[0].decisions.last_ids' <<<"$output")" = "[]" ]

  cat >"$dir/DECISIONS.md" <<'EOF'
# Decisions

### D1 — first
body

### D2 — second

### D10 — tenth (numeric sort, not lexical)

### D3 — third
EOF

  run oberon status "$id"
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null
  [ "$(jq -r '.[0].decisions.count' <<<"$output")" -eq 4 ]
  [ "$(jq -c '.[0].decisions.last_ids' <<<"$output")" = '["D2","D3","D10"]' ]
}

@test "status progress.current_state extracts block text or null" {
  local id
  id="$(oberon init --name "Progress Shape" --repo "$FAKE_REPO")"
  local dir="$OBERON_HOME/$id"

  cat >"$dir/PROGRESS.md" <<'EOF'
# Progress

## Current state

Design settled on the queue.
Code lives on feature/x.

## Journal

### 2026-09-02 — first entry

- note

### 2026-09-02 — tag bump discharged

- more
EOF

  run oberon status "$id"
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null
  local state
  state="$(jq -r '.[0].progress.current_state' <<<"$output")"
  [[ "$state" == *"Design settled on the queue."* ]]
  [[ "$state" == *"Code lives on feature/x."* ]]
  [[ "$state" != *"## Journal"* ]]
  [[ "$state" != *"first entry"* ]]
  [ "$(jq -r '.[0].progress.entry_count' <<<"$output")" -eq 2 ]
  [ "$(jq -r '.[0].progress.last_entry_heading' <<<"$output")" = "### 2026-09-02 — tag bump discharged" ]

  # No Current state header → null
  cat >"$dir/PROGRESS.md" <<'EOF'
# Progress

### 2026-09-01 — lone entry
EOF
  run oberon status "$id"
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null
  [ "$(jq -r '.[0].progress.current_state' <<<"$output")" = "null" ]
  [ "$(jq -r '.[0].progress.current_state | type' <<<"$output")" = "null" ]
}

@test "status contributing_repos dirty true/false and missing path" {
  local id
  id="$(oberon init --name "Repos Dirty" --repo "$FAKE_REPO")"

  # Clean
  run oberon status "$id"
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null
  [ "$(jq -r '.[0].contributing_repos[0].dirty' <<<"$output")" = "false" ]
  [ "$(jq -r '.[0].contributing_repos[0].dirty | type' <<<"$output")" = "boolean" ]
  [ "$(jq -r '.[0].contributing_repos[0].exists' <<<"$output")" = "true" ]

  # Dirty
  echo "dirt" >>"$FAKE_REPO/README"
  run oberon status "$id"
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null
  [ "$(jq -r '.[0].contributing_repos[0].dirty' <<<"$output")" = "true" ]
  [ "$(jq -r '.[0].contributing_repos[0].dirty | type' <<<"$output")" = "boolean" ]

  # Gone path
  local gone="${BATS_TEST_TMPDIR}/gone-repo-path"
  local tmp
  tmp="$(mktemp)"
  jq --arg p "$gone" --arg n "gone-repo" '
    .contributing_repos = [{name:$n, remote:null, path:$p}]
  ' "$OBERON_HOME/$id/project.json" >"$tmp"
  mv "$tmp" "$OBERON_HOME/$id/project.json"

  run oberon status "$id"
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null
  [ "$(jq -r '.[0].contributing_repos[0].exists' <<<"$output")" = "false" ]
  [ "$(jq -r '.[0].contributing_repos[0].branch' <<<"$output")" = "null" ]
  [ "$(jq -r '.[0].contributing_repos[0].sha' <<<"$output")" = "null" ]
  [ "$(jq -r '.[0].contributing_repos[0].dirty' <<<"$output")" = "null" ]
  [ "$(jq -r '.[0].contributing_repos[0].branch | type' <<<"$output")" = "null" ]
  [ "$(jq -r '.[0].contributing_repos[0].sha | type' <<<"$output")" = "null" ]
  [ "$(jq -r '.[0].contributing_repos[0].dirty | type' <<<"$output")" = "null" ]
}

@test "status is side-effect free: store HEAD and updated_at unchanged" {
  local id
  id="$(oberon init --name "No Side Effects" --repo "$FAKE_REPO")"
  local before_head after_head before_ts after_ts
  before_head="$(git -C "$OBERON_HOME" rev-parse HEAD)"
  before_ts="$(jq -r '.updated_at' "$OBERON_HOME/$id/project.json")"

  run oberon status "$id"
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null

  # Also from claiming cwd
  cd "$FAKE_REPO"
  run oberon status
  [ "$status" -eq 0 ]
  jq . <<<"$output" >/dev/null

  after_head="$(git -C "$OBERON_HOME" rev-parse HEAD)"
  after_ts="$(jq -r '.updated_at' "$OBERON_HOME/$id/project.json")"
  [ "$before_head" = "$after_head" ]
  [ "$before_ts" = "$after_ts" ]
}
