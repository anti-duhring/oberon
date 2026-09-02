# Oberon v2 replaces v1 in this repo, rather than extending it

v1 was a spec-driven *execution* pipeline: `/obr-init` → `/obr-spec` → `/obr-plan` →
`/obr-phase N`, with `obr-planner` and `obr-executor` subagents decomposing a PRD into
phases and running them. v2 is a different product — durable *working memory* for a feature
(init, grill, sync, handoff, delete), with no execution pipeline. Rather than bolt one onto
the other, v2 is a clean rewrite in the same repo and under the same name.

Decided with Mateus, 2026-09-02, on being shown v1 existed: "we can remove it, we have a
github repo for that."

## Consequences

- v1 is recoverable only from the remote, `git@github.com:anti-duhring/oberon.git` — verified
  at decision time to have 0 unpushed commits on `main`, with v1's tip at `e30b7dd`.
- v1's install/uninstall symlink scripts and its vendored bats harness (`tests/bats/`) are
  the parts worth keeping; ADR-0001 extends the same mechanism to Codex.
- v1's `state.json` schema is **not** v2's. It is keyed on phases and tasks, and carries no
  project id — so it cannot name the per-project branch v2 requires.
- **v1's `/obr-init` appended `.oberon/` to `.gitignore`.** That line is the direct cause of
  the ALT-120 store being gitignored and stripped from its PR, which is the pain v2 exists to
  fix. Whatever v2 does about git, it must not reintroduce it.
- v1's uncommitted `TODO.md` is carried forward as v2 design input: explore a codebase once
  per repo and inherit it, support quick tasks, use fewer tokens, prompt to clear context
  between phases.
