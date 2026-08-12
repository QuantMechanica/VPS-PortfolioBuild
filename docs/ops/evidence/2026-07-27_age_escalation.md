# Claim-time pending-work age escalation

Date: 2026-07-27

## Result

Pending work now receives one effective-priority point per whole week of age,
computed in the existing claim SQL from `created_at`. The inspectable score is:

`priority_track_rank * 10 + phase_rank - whole_age_weeks`

Recovery-class rank remains the first ordering key, so Operating Rule 22's
idle-only recovery cap is unchanged. No rows are restamped and no new hot-path
query or filesystem I/O was added.

The documented crossover example is an ordinary Q02 row (fresh score 18)
against a fresh priority-track Q08 row (score 2): the Q02 row reaches parity
after 16 whole weeks and then wins through the existing tie-breaks. Malformed
`created_at` values receive zero age credit because SQLite `julianday` returns
NULL and the expression uses `COALESCE(..., 0)`; this fails open to the former
priority behavior.

`chk_pending_tail_age` now reports `max_age_credit_weeks` and explains the
claim-time escalation instead of describing age as visibility-only.

## Verification

Focused tests:

`python -m pytest tools/strategy_farm/tests/test_priority_track_new_q02.py tools/strategy_farm/tests/test_summary_missing_classification.py -q`

Result: `32 passed in 1.43s`. The regression set covers eventual old-row
promotion and malformed-date fail-open behavior.

