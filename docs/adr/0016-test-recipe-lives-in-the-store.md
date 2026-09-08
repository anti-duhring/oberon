# The test recipe lives in the store as `TEST.md`, owned by `oberon-test`

Re-deriving how to test a feature is one of the most expensive things a cold session repeats: which
suite covers the change, which service must be up, which failure was already red before we started.
That knowledge is project-scoped and must not land in the feature PR, so it belongs in the store —
as `TEST.md`, a fifth file created **lazily** by `oberon-test` rather than seeded by `oberon init`,
because a project that is never tested through Oberon should not carry an empty test doc.

`TEST.md` holds *how to run* plus the *last* results (rewritten wholesale) and a run history capped
at ten lines. The dated journal entry for a test run stays in `PROGRESS.md` and is still written by
`oberon-sync`, which `oberon-test` calls at the end.

Decided with Mateus, 2026-09-08.

## Considered Options

- **`TEST.md` in the store, results header + capped history, sync for the journal.** Taken. The
  recipe survives session death, and there is exactly one append-only history (ADR-0010) instead of
  two.
- **Results only in `PROGRESS.md`.** Rejected. The journal is append-only and dated, so "the current
  way to run the tests" would have to be reconstructed by reading backwards through entries — the
  exact rediscovery cost this skill exists to remove.
- **Test recipe in the contributing repo (`CONTRIBUTING.md`, `docs/testing.md`).** Rejected as the
  default: it leaks into the feature PR (ADR-0004), and most of the content is project-scoped
  scaffolding — which pre-existing failure to ignore, which scoped package matters this week. A
  genuinely repo-durable command is still a normal repo doc contribution, unrelated to the store.
- **Full test output in the store.** Rejected. Logs are large, stale within a commit, and
  unreadable; failing test names plus `path:line` are what a later agent acts on.
- **Model-invocable.** Rejected. Running tests has side effects (databases, services, money, time)
  and an agent that self-fires it mid-conversation converts a question into an unrequested run.
  `disable-model-invocation` is set, as for `oberon-delete` (ADR-0011, ADR-0012); the user starts it.

## Consequences

- The store's file set becomes four seeded files plus `TEST.md` on demand. Nothing in `bin/oberon`
  parses `TEST.md`, so `oberon status` does not report it; `oberon commit` picks it up because it
  stages the whole project directory.
- `oberon-test` is the only skill that composes another: it calls `oberon-sync` after committing.
  Sync's no-op guard applies unchanged, so a green re-run of an unchanged sha records nothing new in
  the journal and only refreshes `TEST.md`.
- Triage classes (`regression` / `pre-existing` / `flaky`) are part of the recorded shape, with an
  explicit **unverified** marker. A pre-existing claim that was never checked stays visibly
  unchecked instead of hardening into folklore.
- The skill is forbidden from editing tests, adding skips, or narrowing selectors to reach green.
  Test-shaped work is ordinary repo work; a runner that is allowed to rewrite its own oracle records
  nothing trustworthy.
- Install list goes from five Oberon skills to six.
