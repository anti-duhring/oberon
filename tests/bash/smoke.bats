#!/usr/bin/env bats

# Smoke test — proves the bats harness itself runs.
# Intentionally trivial. Delete only when a real bash-tier test replaces it.

@test "bats harness is wired up" {
  [ 1 -eq 1 ]
}
