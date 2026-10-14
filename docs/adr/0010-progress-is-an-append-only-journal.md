# `PROGRESS.md` is an append-only journal with a bounded rewritten header

`oberon-sync` appends one dated entry per invocation — date, contributing repo path, what
changed, and whatever context the agent judges worth keeping — and never edits a previous
entry. Above the entries sits one short "Current state" block that sync rewrites wholesale
each time.

Decided 2026-09-02 (delegated to me by Mateus after the trade-off was laid out).

## Considered Options

- **Maintained tracker**, status rows edited in place. Rejected. This is what ALT-120's
  `PROGRESS.md` actually was, and it rotted in a documented way: 453 lines in which
  `DONE (verified)` rows had to be annotated *"that status is historical"*, correction
  paragraphs stacked on top of stale tables, and a "⚠️ Verification debt" note explaining
  that the tests certifying three of the items could no longer even run. A status row is a
  claim that decays silently; a dated entry is a fact that cannot.
- **Append-only journal.** Taken. Also what was originally asked for.

## Consequences

- Every entry carries a repo path, because a project spans repos (ADR-0002) and an
  unattributed entry is uninterpretable.
- The header exists only because a pure journal cannot answer "where are we now?" without a
  full read. It is hard-bounded to a few lines and rewritten, never appended to, and must not
  become a status table — that is precisely the artefact this ADR rejects.
- Sync never rewrites history, so two syncs from different sessions cannot conflict beyond a
  trivial append.
