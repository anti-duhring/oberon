---
name: obr-prd
description: "Generate a Product Requirements Document (PRD) for an Oberon project. Reads `.oberon/PROJECT.md` as input, asks targeted clarifying questions to fill gaps, and writes a single `.oberon/PRD.md`. Used by the /obr-spec command."
user-invocable: true
---

# obr-prd

Create a Product Requirements Document for an Oberon-initialized project. Input is `.oberon/PROJECT.md`; output is `.oberon/PRD.md`.

---

## The Job

1. Read `.oberon/PROJECT.md` (Overview, Decisions, Open Questions)
2. Ask 3–5 targeted clarifying questions **only about gaps** — never re-ask what PROJECT.md already answers
3. Generate a structured PRD from PROJECT.md + answers
4. Save to `.oberon/PRD.md`

**Do not start implementing. Just write the PRD.**

### Hard rule — no stopping after the questions are answered

When the user replies to your clarifying questions, that is the **trigger** to produce the PRD and write the file in the same turn. Do not summarize the answers back at the user. Do not ask follow-ups. Do not wait for acknowledgement. Generate the PRD content and call `Write .oberon/PRD.md` immediately.

If this skill is invoked by a command (e.g. `/obr-spec`), that command has state-update work to do after the PRD is written. Hand control back to the caller in the same turn — do not stop at the PRD.

---

## Step 1: Clarifying Questions

Read PROJECT.md first. Then identify what's still missing for a good PRD:

- **Success criteria** — how do we know it's done?
- **Non-goals** — explicit out-of-scope items
- **Technical constraints** — platforms, integrations, performance
- **User roles** — who uses this, permissions
- **Design direction** — UI/UX references, if applicable

Ask only about gaps. If PROJECT.md already covers a topic, skip it.

### Question format (lettered options for quick reply)

```
1. How will we measure success?
   A. Adoption (users / week)
   B. Task completion time reduction
   C. Error rate reduction
   D. Other: [specify]

2. Target users?
   A. New users
   B. Existing users
   C. All users
   D. Admins only
```

Users reply "1A, 2C" style. Indent options.

Ask all questions in a single message, then wait.

---

## Step 2: PRD Structure

Nine sections:

### 1. Introduction / Overview
Brief description and the problem it solves. Pull from PROJECT.md Overview.

### 2. Goals
Measurable objectives, bulleted.

### 3. User Stories

Each story:
- **Title** — short name
- **Description** — "As a [user], I want [feature] so that [benefit]"
- **Acceptance Criteria** — verifiable checklist

Stories must be small enough to implement in one focused session.

Format:

```markdown
### US-001: [Title]
**Description:** As a [user], I want [feature] so that [benefit].

**Acceptance Criteria:**
- [ ] Specific verifiable criterion
- [ ] Another criterion
- [ ] Typecheck / lint passes
- [ ] **[UI stories only]** Verify in a browser
```

Acceptance criteria must be verifiable. "Works correctly" is bad. "Button shows confirmation dialog before deleting" is good.

For any story with UI changes, include "Verify in a browser" as acceptance criteria.

### 4. Functional Requirements

Numbered, unambiguous:

- FR-1: The system must allow users to…
- FR-2: When a user clicks X, the system must…

### 5. Non-Goals (Out of Scope)
What this explicitly will NOT do. Pull from PROJECT.md Decisions where "alternatives considered" show rejected scope.

### 6. Design Considerations (optional)
UI/UX notes, components to reuse, mockup links.

### 7. Technical Considerations (optional)
Constraints, dependencies, integration points, performance.

### 8. Success Metrics
Concrete measures of success. Pull from Step 1 answers.

### 9. Open Questions
Remaining uncertainties. Merge PROJECT.md's Open Questions with anything that surfaced during the clarifying round.

---

## Writing for Implementers

The PRD reader may be a junior developer or an AI agent:

- Be explicit; avoid jargon (or define it)
- Number requirements for reference
- Use concrete examples
- Define acceptance criteria verifiably

---

## Output

- **File:** `.oberon/PRD.md` (single file, always this path)
- **Format:** Markdown
- Do not create `tasks/` or any other directory

---

## Checklist

Before saving:

- [ ] Read PROJECT.md
- [ ] Asked only gap-filling questions (no redundancy with PROJECT.md)
- [ ] Incorporated answers
- [ ] User stories are small and specific
- [ ] Functional requirements are numbered and unambiguous
- [ ] Non-goals are explicit
- [ ] Saved to `.oberon/PRD.md`
