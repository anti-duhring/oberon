<!-- Source: skills/oberon-sync/SKILL.md § File shape + Entry sketch -->
# Progress

## Current state

Design settled on the queue.
Code lives on feature/x; next is the handoff.

### 2026-09-02 18:40Z — list route + 403 gate

- **repo** `/Users/…/spa-alt-120` · branch `feature/alt-120-reminders-list` · sha `12cf14c…` · dirty `false`
- stat: 4 files changed, 220 insertions(+)
- `GET /reminders` at `reminders/api.go:29` with `.With(aiInternal)`; 27/27 package tests pass.
- Gate test mutation-checked: drop middleware → fail, restore → pass.

### 2026-09-02 19:15Z — tag bump discharged

- **repo** `/Users/…/spa-alt-120` · branch `feature/alt-120-reminders-list` · sha `a1b2c3d…` · dirty `false`
- stat: clean
- Follow-up entry after the list route landed.
