# The store repo commits locally on every mutation; pushing is opt-in and off by default

Every Oberon skill that changes a store ends by committing it — one commit per skill
invocation, in the store repo at `~/.oberon`, touching only that project's directory. No
remote is configured by default. A project may opt in by naming a private remote in its
manifest.

Decided with Mateus, 2026-09-02.

## Consequences

- The failure actually observed — a store deleted or mangled mid-session, or lost to context
  compaction — is fully covered by local commits. A remote only adds laptop-loss survival and
  cross-machine sync.
- Push is opt-in because of what stores demonstrably contain. ALT-120's `DECISIONS.md` holds
  production figures (`total_reminders=4246`, `with_tags=260`), internal service architecture,
  and unreleased design. Defaulting to push would put employer data on a personal remote
  silently, on every `oberon-sync`.
- One commit per invocation makes the history a readable log of what each session did, and
  keeps writes isolated per project (ADR-0005) so concurrent projects never contend.
- The commit runs in a script the skills call, never in a host hook — Codex has no hook
  mechanism (ADR-0001).
