# OPT_CENSUS queue-rank code/test contradiction resolved (v4 incumbent-shift drift)

- **Task ID:** 6d0c929f-eae9-48dd-b6d2-bb282546854c (claude, ops_issue, priority 55)
- **Commissioned by:** claude-orchestrator 2026-08-24 Factory-CEO-Session
- **Source:** `docs/ops/evidence/2026-08-24_throughput_forensics.md` §8 (branch
  `rb-throughput-forensics`) — flagged 1 failed / 135 passed in this area.
- **Generated:** 2026-08-24, claude-orchestration-3 (headless single-pass cycle)

## The contradiction

`tools/strategy_farm/farmctl.py:1432` (`pending_claim_order_sql()`) hardcoded
`WHEN 'OPT_CENSUS' THEN 6`, with a comment claiming this "shares Q04's tier-6 rank"
(DL-089 §3 intent: OPT_CENSUS interleaves with the funnel at Q04's rank, never runs
ahead of it, never starves it).

`tools/strategy_farm/tests/test_opt_census_dispatch.py::test_opt_census_ranks_tier6_not_priority`
computed the expected rank **dynamically**: `farmctl.phase_rank(farmctl._INCUMBENT_PHASE)
- farmctl.phase_rank("Q04")`, with an in-file comment: "OPT_CENSUS tracks Q04's tier
under the active manifest ... (v4 inserts another upstream gate, shifting the tier to
7)." Under the live gate manifest this expression evaluates to **7**, not 6, so the
hardcoded `6` and the dynamically-computed `7` disagreed — 1 failed test.

## Which rank is correct — evidence from the v4 documents

`docs/ops/rebaseline/GATE_MANIFEST_V4_LINEAR_PROPOSAL_2026-08-23.md` §3 (the
Alt→Neu/old→new mapping table) confirms `Q04` keeps its identity ("REUSE, id
unchanged, hash-bound") — Q04 itself did not move. What moved is the **incumbent
phase**: §4 explicitly labels the frontier as "v3 Q09/Q10 = v4 Q11 incumbent" — the v4
rebaseline inserted an additional upstream gate ahead of the old Q09/Q10 pair, so the
new incumbent phase is `Q11`, not `Q10`.

`_gate_priority_rank_sql()` (and every dynamically-ranked phase in
`pending_claim_order_sql()`) derives its rank as `phase_rank(_INCUMBENT_PHASE) -
phase_rank(phase)` — a distance-from-incumbent formula. Confirmed live:

```
_INCUMBENT_PHASE = Q11        (was Q10 pre-v4)
phase_rank(_INCUMBENT_PHASE) = 11
phase_rank('Q04') = 4
Q04 effective rank = 11 - 4 = 7   (was 10 - 4 = 6 pre-v4)
```

So the v4 incumbent-phase move from Q10 to Q11 mechanically shifted every
distance-derived rank, including Q04's, by exactly +1 — from 6 to 7. **The test's `7`
is correct under the live v4 manifest; the code's hardcoded `6` was stale**, left
behind by the 2026-08-23 gate renumbering because it was a copy-pasted literal rather
than a reference to the same formula the rest of the table uses.

## Fix

`tools/strategy_farm/farmctl.py` — the `OPT_CENSUS` `CASE` arm now reads
`phase_rank(_INCUMBENT_PHASE) - phase_rank('Q04')` (computed at SQL-generation time,
same as every other dynamically-ranked phase in this table) instead of the literal
`6`. This ties OPT_CENSUS's rank to Q04's rank structurally, so a future
incumbent-phase move cannot silently drift this arm out of sync again — the exact
failure mode this ticket exists to fix. Comment updated to explain the formula and
name the 2026-08-23 v4 Q10→Q11 shift as the concrete precedent. No test was changed
(it was already correct); only the code was fixed, per the task's constraint ("code
OR test, not both freely" — the v4 documents settle which one was wrong).

## Verification

- `python -m pytest -q tools/strategy_farm/tests/test_opt_census_dispatch.py` →
  **19 passed** (was 1 failed before the fix).
- Broader adjacent sweep re-verified green:
  `test_activate_gate_manifest_v4.py`, `test_gate_manifest.py`,
  `test_ftmo_book3_q02_dispatch.py`, `test_pattern_fixture_harness_dispatch.py` →
  **60 passed, 2 skipped**.
- No gate criterion was touched — this is queue-ordering (which pending row gets
  claimed next), not a pipeline verdict rule.

## Not done

- No queue-order *policy* change was made — OPT_CENSUS still interleaves with Q04 by
  design (DL-089 §3); this only restores that design intent to match the current v4
  phase numbering. Nothing here is a GELB/priority-track decision requiring separate
  sign-off, since the effective *ordering relationship* (OPT_CENSUS ranks with Q04,
  below every downstream funnel phase and every priority row) is unchanged — only the
  numeric label moved, mechanically, with the rest of the table.
