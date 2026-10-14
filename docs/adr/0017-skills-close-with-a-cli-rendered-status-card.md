# Every skill closes with one status card, rendered by `oberon card`

A session that ends with "committed the handoff" leaves the user holding nothing: not the project id
they need to pass to the next invocation, not the store path, not whether a contributing repo is
still dirty. `oberon-status` already computes all of that, but each skill closed in its own prose
shape, so the same facts appeared in five different layouts — or not at all.

Every Oberon skill therefore ends by printing the same card, and the card is rendered by the CLI
(`oberon card [ID]`) rather than described in each `SKILL.md`. The skills carry one instruction —
run it, paste stdout verbatim, add at most one line either side — so there is exactly one layout to
change and no prose for a model to improvise around.

Decided with Mateus, 2026-09-10.

## Considered Options

- **`oberon card` renders; skills paste it.** Taken. One implementation, byte-identical output from
  `oberon-grill`, `oberon-sync`, `oberon-test`, `oberon-handoff`, `oberon-status` and the
  `oberon-delete` confirmation. A layout fix ships in `bin/oberon` and every skill inherits it.
- **Describe the card in each `SKILL.md`.** Rejected. Five copies of a layout spec drift within a
  week, and a model asked to "render roughly six lines" produces six different cards.
- **One shared card spec file referenced by the other skills.** Rejected. Skill directories are
  symlinked independently into three roots (ADR-0014), so a cross-skill file reference resolves to a
  different path per harness — or to nothing.
- **Make `oberon status` print text and drop the JSON.** Rejected. The JSON is the machine contract
  the skills already read for no-op checks and staleness; `card` is an additive second view over the
  same `status_project_json` payload, and `status` stays a JSON array.

## Consequences

- `oberon card [ID]` shares `status`'s resolution and exit codes exactly: explicit id, else every
  project claiming the current repo; exit 4 when nothing claims it, exit 5 for an unknown id. Both
  commands are read-only and route through `resolve_report_ids`.
- The card is fixed-shape: project, id, status + age, current state, decisions, last journal entry,
  one line per contributing repo (`branch@sha` + `clean` / `DIRTY` / `MISSING`), handoff freshness,
  store path. Long values are clipped to one line — the card is a pointer to the store, not a
  replacement for reading it.
- Two call-outs that skills used to have to remember are now computed: a `!` line whenever any repo
  is dirty (ADR-0013), and a `STALE` marker on the handoff row whenever `PROGRESS.md` changed after
  `HANDOFF.md`. That rule required adding `progress.updated_at` to the `status` payload — additive.
- Both `progress.updated_at` and `handoff.updated_at` are **content** times: the commit that last
  touched the file in the store repo, falling back to the working-tree mtime only while the file is
  uncommitted. Pure mtime would have been wrong the moment the store is cloned onto a second machine
  (ADR-0004, ADR-0008) — checkout sets every mtime to clone time, erasing the ordering staleness is
  derived from — and would also let a bare `touch` flip the verdict. Cost: two extra `git` calls per
  store file per project, on a command that already shells out per contributing repo.
- Rendering switches to a UTF-8 locale when the current one cannot represent a multibyte character,
  because the rules and the clipping are character-based; under `LC_ALL=C` they emit split
  sequences. The check **measures** the shell (`x='─'; [ ${#x} -eq 1 ]`) before and after exporting
  a candidate rather than trusting a name from `locale -a`, and restores the original environment
  when no candidate works — a locale can be listed and still not drive bash's multibyte handling.
- `oberon-delete` shows the card in its **confirmation**, never after: the id is gone once the
  delete lands and `oberon card` would exit 5.
- **One card per invocation.** `oberon-test` composes `oberon-sync`, and sync renders the card on
  every path including its no-op, so test renders none of its own. The verdict stays in `TEST.md`
  (ADR-0016) and in test's one-line report.
- The canonical rendering rules live in `oberon-status` alone; the other skills carry a three-line
  pointer plus whatever is specific to them (grill: the `decisions` row is the interview's receipt;
  handoff: the `handoff` row must not read `STALE`). Copying the full rules into five files would
  have recreated the drift this ADR exists to remove.
