---
date: 2026-05-08
author: Quality-Business
issue_refs: [QUA-970, QUA-723, QUA-724]
type: process-gap
---

# Lesson: QB must self-trigger monthly review when routine is cancelled

## What happened

The QB Monthly Business Review routine `QUA-723` was cancelled on or around 2026-04-28 (reason: superseded by direct issue management). The June stub `QUA-724` was created manually. However, no May stub was created, so the first scheduled review (2026-05-04, first Monday of May) was missed by 4 days.

QB detected the gap on 2026-05-08 during a routine inbox sweep and created `QUA-970` retroactively.

## Root cause

QB relied on the Paperclip routine to trigger the review. When the routine was cancelled, no fallback mechanism existed. QB's inbox-lite only shows assigned issues — it does not surface "you were supposed to do X by date Y" from cancelled routines.

## Fix applied

QB manually created `QUA-970` and filed the May review on 2026-05-08 with full 6-section content.

## Process rule going forward

On every heartbeat, QB checks: is the first Monday of the current month within the last 7 days? If yes AND no `QB Monthly Business Review — YYYY-MM` issue exists in `in_progress` or `done` state, QB self-creates and files it immediately. Do not wait for a routine or assignment.

## Secondary finding: SRC03_S16/S17 governance gap

Cards `williams-pinch-paunch_card.md` (SRC03_S17) and `williams-pro-go_card.md` (SRC03_S16) carry `g0_verdict: APPROVED` in their YAML headers, but no corresponding Paperclip G0 issues exist for them. These appear to have been approved directly in the card file (possibly during bulk Research extraction before formal G0 workflow was established). If CEO intends these to enter the pipeline, Paperclip G0 issues should be created so the approval is traceable in the issue thread, not just in the card file.

Flag for CEO at next SRC03 wave unblock decision.
