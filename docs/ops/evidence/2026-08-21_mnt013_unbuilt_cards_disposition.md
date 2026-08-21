# MNT-013: unbuilt-card backlog now buckets into READY / DATA_BLOCKED / NEEDS_SOURCE

**Date:** 2026-08-21
**Router task:** `875bd3b0-057d-4105-be79-af78a182b0d1`
**Disposition:** bucketing tool built and run; no cards built (GRÜN reporting only)

## Context

`chk_unbuilt_cards_count` has reported a single flat number for weeks: 813 on
2026-08-16, ~445 in the 2026-07-28 maintenance ledger, **365 now** (2026-08-21).
The backlog is genuinely draining, but the number alone doesn't say *why* the
remaining cards haven't built or whether any of them ever will without further
work — MNT-013 asked for a named disposition instead of one undifferentiated
count.

## What was built

`tools/strategy_farm/unbuilt_cards_disposition.py` — a read-only classifier that:

1. Re-runs the **exact same enumeration** as `health.chk_unbuilt_cards_count`
   (R-gate-ready approved cards with no `.ex5` and no pending/active build
   task), so its total always matches the health WARN count.
2. For each card, re-checks `custom_history_archive_admission` against the
   **current** Custom-history isolation manifest (the live runtime authority,
   which can drift after a card's R3 `PASS` was asserted at approval time) and
   the card's R1 source-lineage strength.
3. Buckets each card:
   - **READY** — R-gates pass and the current archive manifest still admits
     it; nothing blocking except build-lane throughput (Codex slot / pump
     cadence).
   - **DATA_BLOCKED** — the live archive manifest can no longer satisfy the
     card's declared symbol(s); its R3 `PASS` is stale relative to runtime
     state.
   - **NEEDS_SOURCE** — buildable per R-gates, but R1 source lineage is weak
     (missing `source_id`, or `r1_track_record` UNKNOWN/FAIL/TIER_C).
4. Writes a timestamped JSON snapshot to
   `D:/QM/reports/state/unbuilt_cards_disposition/` so re-running the script on
   later cycles makes the drain rate — and how the bucket mix shifts — visible
   over time, not just the aggregate count.

Covered by `tools/strategy_farm/tests/test_unbuilt_cards_disposition.py` (5
cases: DATA_BLOCKED on admission failure, NEEDS_SOURCE on missing source_id,
NEEDS_SOURCE on weak track record, READY on the clean path, and a
CLASSIFY_ERROR bucket so a classifier exception is never silently folded into
DATA_BLOCKED). All 5 pass.

## This run's snapshot (2026-08-21T10:26:50Z)

```
total_unbuilt = 365
READY          = 324  (88.8%) — waiting on build-lane throughput only
DATA_BLOCKED   =   8  ( 2.2%) — QM5_1157, 12840, 12856, 12865, 20053, 20171, 30006, 38007
NEEDS_SOURCE   =  33  ( 9.0%) — missing/weak R1 lineage, still technically buildable
CLASSIFY_ERROR =   0
```

Full row-level detail (ea_id, reason, card path) is in
`D:/QM/reports/state/unbuilt_cards_disposition/snapshot_20260821T102650Z.json`.

## Reading the number now

The 365 is not a monolithic backlog: **89% (324) is pure throughput** — it will
drain as soon as build-lane capacity (currently blocked by
`repo_dirty_build_guard` on another agent's in-flight `CLAUDE.md` edit in the
canonical repo, and by Codex slot saturation) frees up, with no further
decision required. The 8 `DATA_BLOCKED` cards need an owner decision (repair
the archive coverage or re-open R3 for those EAs) before they can ever build,
regardless of queue depth. The 33 `NEEDS_SOURCE` cards can build today but
carry weak provenance worth a lightweight source pass.

## What was not done

- No card was built, re-approved, or edited.
- No work item, task, or manifest was changed.
- The `repo_dirty_build_guard` blocker itself was not touched — the dirty
  `CLAUDE.md`/`.mq5` files belong to another agent's in-progress edit in the
  shared `agents/board-advisor` checkout and were left alone.

## Next step

Re-run `python tools/strategy_farm/unbuilt_cards_disposition.py` on a later
cycle and diff the bucket counts against this snapshot to confirm the drain is
real and to see whether `DATA_BLOCKED`/`NEEDS_SOURCE` shrink or just sit while
`READY` cycles through.
