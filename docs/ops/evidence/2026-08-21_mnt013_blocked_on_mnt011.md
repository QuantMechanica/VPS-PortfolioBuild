# MNT-013 — blocked on MNT-011, not yet actionable

**Date:** 2026-08-21
**Router task:** 875bd3b0-057d-4105-be79-af78a182b0d1 (priority 78, ops_issue)
**Recorder:** Claude (agents/board-advisor)

## Instructed work

Materialize the READY / NEEDS_SOURCE / DATA_BLOCKED buckets for the 365
unbuilt approved cards so the count means something, and keep the bounded
drain running. The ticket itself sequences this behind MNT-011
(`df0cfed8-cc0c-431d-a13b-be914eee3bc3`): "Blocked behind MNT-011 -- do that
first."

## Finding: MNT-011 is not done; dependency unmet

MNT-011 is still `IN_PROGRESS`, assigned to `codex`, verdict as of this
check: "IMPLEMENTED_TESTED; 204 generated paths disposed (115 committed, 89
retained+ignored); awaiting scheduler-owned generated-only build spawn and
codex_zero_activity recovery; foreign CLAUDE.md correctly blocks."

Reproduced live:

```powershell
python -c "import json,sys; sys.path.insert(0,r'C:\QM\repo\tools\strategy_farm'); import farmctl; print(json.dumps(farmctl._repo_dirty_status(farmctl.REPO_ROOT),indent=2))"
```

```json
{
  "blocked": true,
  "count": 1,
  "total_count": 2,
  "generated_count": 1,
  "blocking_by_class": {"other": 1},
  "entries": [" M CLAUDE.md"]
}
```

`repo_dirty_build_guard` is still blocked by a modified `CLAUDE.md` — a human
edit MNT-011's own evidence explicitly says not to consume ("Allow the owner
of CLAUDE.md to commit or otherwise resolve that edit"; "do NOT recompile in
the active inventory"). Per MNT-013's own constraints, this is someone else's
in-flight edit and out of scope to resolve here.

## What was and wasn't done

- No bucket materialization, no drain changes, no card builds triggered.
- Confirmed the blocking condition still holds at the time of this cycle.
- No files modified except this evidence doc.

## Disposition

Setting router state to `BLOCKED` (not `REVIEW` — there is no work product
to review; the sequencing precondition is unmet). Re-check in a future cycle
once MNT-011 closes and `repo_dirty_build_guard.blocked=false` with a
genuine generated-only pump cycle observed.
