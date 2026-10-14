# `project_id` is a slug with a short random suffix, not a UUID

`project_id` is `<slug-of-project-name>-<4 hex>`, e.g. `alt-120-reminders-7f3a`. The field
name stays `project_id`; only the format is legible.

Decided with Mateus, 2026-09-02, revising the original "random UUID" request.

## Consequences

- The id changed jobs when the store went central (ADR-0004): it is now a directory name you
  `cd` into, a key you read in a manifest, and an argument you type to disambiguate two
  projects in one repo. `~/.oberon/3f9c1a72-8b4e-4d1f-9a02-77bd3e5c1140/` is hostile to all
  three.
- Uniqueness does not rest on entropy. `oberon init` scans existing stores and bumps the
  suffix on collision, which is a stronger guarantee than trusting a UUID not to repeat.
- The suffix is still required: two projects legitimately share a name (a second attempt at
  the same feature), and the slug alone would collide.
- The name feeding the slug is settled inside `oberon-grill`, at the first decision that
  settles (ADR-0015), so a legible id does not require the user to name a feature before
  designing it.
