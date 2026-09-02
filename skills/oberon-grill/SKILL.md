---
name: oberon-grill
description: Relentless one-question design interview for an existing Oberon project, after user confirmation. Settles decisions and load-bearing facts into the store's DECISIONS.md as D1…Dn while you talk. Use when the user wants to stress-test or pin down a feature's design, or says grill / design interview in an Oberon context. Never start a full interview unbidden.
---

# oberon-grill

Interview the user until the design tree is shared understanding. Write every settled decision and load-bearing fact into the store's `DECISIONS.md` **as it crystallises** — not batched at the end. Domain language is sharpened in the same pass. All store mutations go through `oberon`; never raw `git`, never hand-edit `project.json`.

## The `oberon` CLI

Call `oberon` from `PATH`. Every store mutation goes through it. If the command is missing,
stop and tell the user to run `install.sh` from the Oberon repo — never fall back to raw
`git` on the store or to hand-editing `project.json`.

## Resolve the project

Same order every time (stop at the first that works):

1. Explicit project id argument from the user / invocation.
2. `$OBERON_PROJECT` if set and non-empty.
3. `oberon resolve --repo <abs path of current git root>` (or `--repo` the user named).

Then:

- **One id** → use it.
- **Several** → list them (`id`, status, name) and ask which.
- **None** → tell the user to run `oberon-init` first; do not invent a store.

Confirm the resolved id and store path (`oberon path <id>`) before side effects.

## Confirm before starting

Model-invocable, gated. Before the first grill question or any write:

1. Name the project id and store path.
2. Say you will run a one-question-at-a-time design interview and append settled items to `DECISIONS.md` in that store.
3. Wait for explicit yes. On no, stop.

## Read seed context first

Before Q1, read whatever already exists — do **not** re-ask settled ground:

- Store: `DECISIONS.md`, `PROGRESS.md`, `HANDOFF.md`, `project.json` (via `oberon path <id>`).
- User-supplied seed (file path or inline description).
- Contributing repos: layout, existing `CONTEXT.md` / `CONTEXT-MAP.md`, relevant code.

Build a mental map of decided vs open. Only grill gaps, contradictions, and under-specified branches. If a question is answerable by reading the codebase, **read the codebase instead of asking**.

---

## Grilling rules (strict)

1. **One question per turn.** Never bundle.
2. **≤ 2 sentences** per question. Broader → split.
3. **2–4 labeled options** as `(a)`, `(b)`, `(c)`, `(d)` when options apply. Pure fact questions (names, URLs) may be open.
4. **Always recommend**, one line: `**Recommend (b)** — <why>.`
5. **No preamble.** No "Great!", no restating the user, no meta "next we'll…".
6. **No stacked sub-questions.**
7. **Explore code instead of asking** when files answer it.
8. **Stop when the tree is resolved.** No padding.

### Question shape

```
**Q<N>: <short question>?**

- **(a)** <option>
- **(b)** <option>
- **(c)** <option>

**Recommend (a)** — <one-line rationale>.
```

Number Q1, Q2, … so the user can refer back.

### Typical branches (depth-first; skip what seed already answered)

1. What is it — one-line purpose (name usually already set at init).
2. Who for — user type, scale, context of use.
3. Scope in vs out for this iteration.
4. Core flows — 1–3 primary journeys.
5. Inputs / outputs / shapes.
6. State and persistence.
7. Integrations and boundaries across contributing repos.
8. Failure modes (abort / prompt / degrade).
9. Explicit non-goals and deferred open questions.

Add branches the project needs; drop ones it does not.

---

## Domain language (active, not optional)

While grilling, sharpen the ubiquitous language:

- **Challenge glossary drift.** If the user contradicts an existing `CONTEXT.md` term, call it out immediately and resolve which meaning wins.
- **Replace fuzzy words.** Overloaded terms ("account", "cancel", "sync") → propose one canonical term and list rejects under `_Avoid_`.
- **Concrete scenarios.** Stress-test relationships with edge cases until boundaries are precise.
- **Cross-check code.** When they state how something works, verify. On contradiction: surface path:line evidence and ask which is right.

### Store vs repo artefacts (two destinations)

| Artefact | Where | When you write |
|---|---|---|
| `DECISIONS.md` | **store only** | Always, as items settle |
| `CONTEXT.md` glossary entry | **contributing repo root** | Only if user accepts an offer |
| `docs/adr/NNNN-slug.md` | **contributing repo** | Only if user accepts an offer |

State plainly when offering: **repo `CONTEXT.md` / ADR files land in the feature PR; the store does not merge anywhere and is invisible to repo readers.**

**Offer — never auto-write — repo artefacts.** Criteria for an ADR offer (all three):

1. Hard to reverse later.
2. Surprising without recorded context.
3. Real trade-off with rejected alternatives worth remembering.

Skip the ADR if any criterion fails. Glossary offers are for terms that should outlive this feature in the codebase's vocabulary. `CONTEXT.md` is glossary only — no implementation detail, no specs.

### CONTEXT.md entry shape (when user accepts)

```md
**Term**:
One or two sentences: what it IS.
_Avoid_: OtherWord, Synonym
```

Opinionated: pick one word, list the rest under `_Avoid_`. Only project-specific domain terms. Create root `CONTEXT.md` (or the mapped context file) lazily on first accepted term. If `CONTEXT-MAP.md` exists, place the term in the right context.

### ADR shape (when user accepts)

`docs/adr/NNNN-slug.md` — scan for highest N, increment. Body can be one short paragraph: context, decision, why. Optional: considered options, consequences, status. Create `docs/adr/` lazily.

---

## Writing `DECISIONS.md` (as you go)

Path: `$(oberon path <id>)/DECISIONS.md`.

**Append settled items immediately** after each resolved branch (or small cluster that is truly one decision). Do not wait for the end of the interview.

### Decisions — `D1…Dn`

- Numbered, append-only. Scan the file for the highest `D#` and continue.
- Density: one row/section per decision with **what** and **why**. Cite `path:line`, ticket ids, or commands when evidence exists — match the habit of real project stores, not empty claims.
- **Reversal** = new number that **names the superseded id** (e.g. "Supersedes D7"). Never edit or delete the old entry; the trail stays.
- Record alternatives considered when they matter.

Suggested shape (table or headings; stay consistent with whatever the file already uses):

```md
| **D12** | **Band → tone clamps to nearest.** | Figma pins Overdue⇒Firm; smooth mapping. Default, not a constraint. |
```

or

```md
### D12 — Band → tone clamps to nearest
Figma pins only Overdue⇒Firm; this is the smooth mapping. A default, never a constraint.
Evidence: …
```

### Facts — load-bearing knowledge

Not every settled item is a decision. Capture **facts the design rests on** (how a PUT treats omission, what a unique index actually covers, production counts, inert provenance chains). Use a parallel series (`K1…Kn` or a clear "Knowledge" section) so they are citable from later decisions.

- Give **sources** (`path:line`, migration name, query, commit) so a later agent can re-check.
- Mark unverified claims explicitly.
- These belong in the store's `DECISIONS.md`, not in ADRs — they often fit no ADR template and still carry the design.

### After each store edit

```bash
oberon commit <id> -m "grill: D12 band-tone clamp"
```

Commit messages stay short and name what landed. The CLI stages only that project directory and is a no-op when nothing changed.

If you also edited a contributing repo's `CONTEXT.md` or ADR (user-approved), that is ordinary repo work for the feature PR — do not put those files in the store.

---

## Ending

When the tree is resolved:

1. Skim `DECISIONS.md` for holes or contradictions; fix only by appending new D/K numbers.
2. Final `oberon commit <id> -m "grill: session complete"` if anything is still uncommitted.
3. Brief close: count of new decisions/facts, store path, any deferred open questions. No Q&A transcript dump.
4. Optionally offer `oberon-sync` or `oberon-handoff` — do not auto-run them.