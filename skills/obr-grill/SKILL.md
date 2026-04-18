---
name: obr-grill
description: Terse, gap-only interview skill used by Oberon's /obr-init command to resolve a project's design tree and produce structured decisions. Reads any provided input (file or inline) first and only asks about what's missing. Output is an Overview + Decisions block ready to drop into `.oberon/PROJECT.md`.
---

# obr-grill

Interview the user to resolve every meaningful branch of a project's design tree, then emit structured output for `PROJECT.md`.

This is Oberon's forked variant of `grill-me`. It exists to keep the interview terse and suitable for non-technical or fast-moving users.

---

## Inputs

The invoking command passes one of:
- a **file path** — read the file as seed context
- an **inline description** — treat as seed context
- **nothing** — begin the grill from zero

Before asking the first question, read all seed context. Build a mental map of what's already decided. **Do not ask about anything the seed already answers.** Only grill gaps, contradictions, and under-specified branches.

---

## Grilling rules (strict)

Enforce every turn. Violations defeat the point of this fork.

1. **One question per turn.** Never bundle multiple questions.
2. **Questions are ≤ 2 sentences.** If you need more, the question is too broad — split it.
3. **Always present 2–4 labeled options** as `(a)`, `(b)`, `(c)`, `(d)`. For open-ended fact questions where options don't apply (e.g., "what's the project name?"), ask the short open question directly.
4. **Always give a recommendation** and a one-line rationale. Format: `**Recommend (b)** — <one line why>.`
5. **No preamble.** No "Great!", "Let's explore…", "That's a good point…", no restating what the user just said.
6. **No meta-commentary.** Don't describe what you're about to do — just do it.
7. **Explore the codebase instead of asking** when a question can be answered by reading files.
8. **Stop when the tree is resolved.** Don't pad with low-value questions.

---

## Question shape

```
**Q<N>: <short question>?**

- **(a)** <option> — <optional inline note>
- **(b)** <option>
- **(c)** <option>

**Recommend (a)** — <one-line rationale>.
```

Number questions Q1, Q2, … so the user can refer back.

---

## Branches to resolve (typical order)

Walk the tree depth-first. Resolve dependencies before dependents.

1. **What is it?** Project name, one-line purpose.
2. **Who is it for?** User type, scale, context of use.
3. **Packaging / form factor** — CLI, web app, library, script, command, etc.
4. **Scope boundaries** — what is explicitly in vs. out for this iteration.
5. **Core flows** — the 1–3 primary user journeys.
6. **Inputs and outputs** — what goes in, what comes out, file formats.
7. **State / persistence** — where data lives, schema, versioning.
8. **Integrations** — external services, APIs, vendored deps.
9. **Failure modes** — what to do when things go wrong (abort / prompt / silent).
10. **Distribution** — how users install/run it.
11. **Open questions** — anything the user explicitly defers.

Skip branches the seed already answers. Add branches if the project needs them.

---

## Ending the grill

When the tree is resolved, emit a single final message containing the **Output** block below (see next section). Do not pad with a closing question. Do not summarize what was discussed — the output block is the summary.

---

## Output format

When the grill ends, emit exactly this block (the invoking command will parse it):

```markdown
## Overview

<1–2 paragraph synthesis of what's being built, for whom, and why. Written in plain prose. Pull from seed context + grill answers.>

## Decisions

- **<decision topic>**: <chosen option> — <one-line rationale>
  - Alternatives considered: <comma-separated list, or "none">
- **<decision topic>**: <chosen option> — <one-line rationale>
  - Alternatives considered: <...>

## Open Questions

- <question deferred during grill>
- <question deferred during grill>
```

Rules for the output block:
- **Overview** is prose, not a bullet list.
- **Decisions** covers every resolved branch — one bullet per decision, with the alternatives considered sub-bullet.
- **Open Questions** lists anything the user explicitly deferred. Empty list is fine; write `- _none_` if so.
- Do not include the raw Q&A transcript.
- Do not wrap the block in additional markdown fences when emitting it — the invoking command expects raw markdown.

---

## Examples of acceptable vs. unacceptable phrasing

**Bad:** "Great question! There are several options we could consider here. First, we could go with approach A, which would give us X benefit but also has Y tradeoff. Alternatively…"

**Good:**
```
**Q3: State storage?**

- **(a)** JSON file
- **(b)** SQLite

**Recommend (a)** — single writer, no concurrent access.
```

**Bad:** "Now let's move on to thinking about error handling, which is an important aspect…"

**Good:**
```
**Q7: Abort or prompt on existing config?**

- **(a)** Abort with error
- **(b)** Prompt user
- **(c)** Silently overwrite

**Recommend (a)** — safest; user can delete manually.
```
