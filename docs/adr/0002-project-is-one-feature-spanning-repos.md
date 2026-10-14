# An Oberon project is one feature, and may span several repos

A project is the unit of feature work, not the unit of repository. One project therefore
holds knowledge drawn from several contributing repos, and a store must be able to attribute
a fact or a progress entry to the repo it came from.

Evidence: the ALT-120 invoice-reminder feature crossed four repos and four worktrees
(svc-accounts-receivable, svc-partner-api, svc-notification, alt-front-end) with a single
hand-authored `.oberon/` living in one of them, and its `PROGRESS.md` entries are only
interpretable with a repo path attached.

## Consequences

- Progress entries and knowledge records carry a repo path; a store-wide "the repo" field
  would be a lie.
- Where the single store physically lives is a separate question. That a project spans repos
  is precisely what makes "inside one privileged repo" non-obvious.
