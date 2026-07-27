# Claim-time pending-work age escalation

Date: 2026-07-27

Pending work now receives one effective-priority point per whole week of age:
`priority_track_rank * 10 + phase_rank - whole_age_weeks`. Recovery-class rank
remains first, preserving the idle-only recovery cap. The value is computed in
the existing claim SQL from `created_at`; no restamp or new hot-path I/O exists.

An ordinary Q02 row (fresh score 18) crosses a fresh priority Q08 row (score 2)
after 16 whole weeks. Malformed dates receive zero credit through
`COALESCE(julianday(...), 0)`, preserving former behavior. Health output now
reports `max_age_credit_weeks`.

Focused verification passed: 32 tests, including eventual promotion and
malformed-date fail-open behavior. Implementation commit: `a4bea4483`.

