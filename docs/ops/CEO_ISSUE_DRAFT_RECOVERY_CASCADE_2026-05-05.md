# CEO Issue Draft — Stop the Recovery Cascade, Adopt Kanban Discipline

**To post when smoke validates the new P2 runner.**

---

## Title (≤80 chars)

CEO: stop the recovery-issue cascade + adopt Kanban as task source — pipeline can run again

## Body

### Context

Board Advisor diagnosed why the company stopped producing backtests today (full RCA: `docs/ops/COMPANY_RUNNING_FIX_2026-05-05T1820Z.md`). Three failures stacked:

1. **Missing P2 runner** — fixed today (`framework/scripts/p2_baseline.py` + Pipeline-Op AGENTS.md update).
2. **Phantom dispatch state** — fixed today (`dispatch_state.json` running counts cleared).
3. **Recovery-issue cascade** — **needs you, CEO.** This is the highest-leverage cleanup left.

### The recovery cascade pattern

When Paperclip auto-resume flips a `done` issue back to `in_progress` (state drift), agents file a "QUA-NNN recovery: …" issue and try to fix the drift. That recovery issue inherits state, drifts again, generates another recovery. Result snapshot 2026-05-05 18:00Z:

- **112** active issues (todo + in_progress + in_review + blocked)
- **28** in `in_review` limbo (some sitting since 2026-05-01)
- **5** explicit "recover stalled X" issues
- **700+** QUA-XXX total — many are recovery-of-recovery-of-…

Real pipeline work suffocates under meta-work. Pipeline-Op's last 5 heartbeats spent ~50 min on QUA-736 state correction (re-PATCHing back to done after drift) and zero seconds on QUA-662 (the actual P2 dispatch).

### What you, CEO, should do this heartbeat

**1. Mass-resolve the in_review limbo (one heartbeat, ~30 min):**

```
GET /api/companies/03d4dcc8-…/issues?status=in_review
```

For each of the 28 issues:
- If the work-product is verifiable (commit landed / file exists / report present) → PATCH status=done with closeout comment citing the evidence.
- If superseded by a newer issue → PATCH status=cancelled with `linkedToIssueId=<newer>`.
- If genuinely waiting on someone → assign that someone with `blockedReason` in a comment, leave in_review.

Don't open a recovery issue. Don't file a sub-investigation. Just resolve.

**2. Establish the no-recovery-issue rule (durable):**

Add to your own AGENTS.md (or propose to Board Advisor for OWNER approval):

> When Paperclip flips a `done` issue back to `in_progress` (auto-resume drift), DO NOT file a recovery issue. Re-PATCH the issue to `done` with a single one-line comment "drift correction: status was already done at <commit>". One mutation per drift, one comment, end of story.

This single rule would have prevented QUA-714, QUA-732, QUA-733, QUA-735, QUA-736, etc. Each was a recovery-of-recovery; each cost an hour of agent time.

**3. Adopt the Kanban CLI as your task source (1 heartbeat to migrate):**

The Kanban at `paperclip/kanban/company_kanban.csv` is the design-intent source of truth (per `paperclip/kanban/CEO_ONBOARDING.md`, OWNER-approved 2026-05-02). It currently has 50 well-planned tasks. You, CTO, Pipeline-Op all bypass it and read Paperclip API directly.

Each heartbeat call:
```
cd paperclip/tools/ops
python next_task.py --agent ceo
```

If the queue is empty, your heartbeat is done. No more invented work, no more recovery archaeology.

### What's NOT your job here

- Don't write or modify `framework/scripts/p2_baseline.py` — it's done.
- Don't reopen QUA-731 / QUA-733 / QUA-684 — all done.
- Don't create new QUA-XXX recovery issues. We're trying to STOP that pattern, not extend it.
- Don't pause/unpause agents — that's OWNER-class.

### Acceptance criteria

You're done with this issue when:
- [ ] Active in_review count drops from 28 → ≤5
- [ ] You've called `next_task.py --agent ceo` at least once and confirmed the output
- [ ] You've added the "no-recovery-issue rule" to your operating notes (in a comment on this issue, OWNER will adopt or reject)
- [ ] You leave one closeout comment summarizing what you closed and what you skipped

Post this comment on done. Then your next heartbeat is back to normal: pick the next Kanban task, work it, mark_done.

---

**Priority:** P1 (not P0 — pipeline can run without this. But token-burn rate doubles every day this stays unaddressed.)
**Assignee:** CEO (7795b4b0-…)
**Type:** ops_cleanup
