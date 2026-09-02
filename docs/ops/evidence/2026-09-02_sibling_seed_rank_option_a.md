# OWNER-DEC-SIBLING-SEED-RANK-20260902 — Option A executed

**Decision:** OWNER, 2026-09-02 (~17:45Z, Claude Code chat): "Option A".
**Receipt:** `owner_decision_receipts.jsonl`, request_id
`chat-20260902-oq-sibling-seed-rank-option-a`, decided_at 2026-09-02T17:48:57Z, notes state
the chat provenance. Decision card in the Mission Control feed (revision 31); execution
contract entry `QM-TODO-20260902-SIBLINGSEED`; bound Claude-lane task `152a35bc-ddc7-5c7f-8d66-f4105d3ad34c`.
Config commit `df8a94e6ff`.

## Effect requested

Q02 seeds of the `_opt` measurement siblings of authenticated DL-089 programs are claimed
**before** optimisation-census cells of equal priority, so the programs that were "deferred"
for a missing sibling Q02 receive their census. Nothing else changes (holds, caps, gate
criteria, every other rank).

## Change

`tools/strategy_farm/farmctl.py`

- new module constant `DL089_Q02_PREREQUISITE_SCHEMA = "qm.dl089-measurement-q02-prerequisite/v1"`
  (the payload schema the matrix-service seed path stamps on these rows; the rows also carry
  `priority_reason = OWNER_P0_DL089_MATRIX_PREREQUISITE`, `subject_ea_id`, `q12_work_item_id`,
  `priority_track = true`);
- `_topdown_gate_rank_sql()` now returns
  `CASE WHEN w.phase='Q02' AND json_extract(w.payload_json,'$.schema')='<schema>' THEN -1 ELSE (<previous CASE, byte-identical>) END`.

**Deviation from the card's literal wording ("Rang 0 wie OPT_CENSUS") — documented:** a
literal 0 does not deliver the requested effect. At a tie on the top-down rank the order falls
through to `(_phase_rank - _age_weeks)`, where OPT_CENSUS sits at Q04's tier ahead of any Q02
row, so an equal-priority seed would still lose. `-1` is the minimal value that places the
seeds ahead of the tier-0 optimisation rows; every other row keeps its previous rank exactly.
The effect the OWNER selected ("werden vor Zensus-Zellen gleicher Priorität geclaimt") is what
is implemented.

`tools/strategy_farm/tests/test_opt_census_dispatch.py`: regression tests — with the env
enabled, a Q02 row carrying the schema sorts before an OPT_CENSUS row of equal
priority_track/age; an ordinary Q02 row still sorts after OPT_CENSUS; the disabled-env order
is unchanged.

## Verification

- Tests (CEO re-run): `test_opt_census_dispatch.py` + `test_pending_superseded_claim_filter.py`
  28 passed; `test_terminal_worker_atomic_claim.py` 93 passed.
- Adversarial live-effect verifier (read-only against the live DB, real
  `pending_claim_order_sql()` with `QM_TOPDOWN_GATE_PRIORITY_ENABLED=1`): the seven seeds
  QM5_41301..41307 are positions 1–7 (rank −1), OPT_CENSUS from position 8; no non-Q02 pending
  row carries the schema; cold path (env unset) unchanged (seeds at ~1343–1353).
- Resident workers cache the selector at start: the amendment reaches the fleet through the
  staggered idle-worker reload (one terminal at a time, ≥150 s spacing, never an active claim).

## Rollback

Single revert of the first CASE arm (or of the commit); tests cover the previous order.

## Adversarial correctness review (post-commit) and fix

The correctness verifier refuted the first commit: the new arm called `json_extract(w.payload_json,'$.schema')` guarded only by `w.phase='Q02'`; an empty or non-JSON payload makes SQLite raise `malformed JSON` and abort the whole canonical claim-order query for every claimant (every other `json_extract` in the selector is `json_valid`-guarded). Fix in `89272cc676`: `AND json_valid(w.payload_json)=1` added to the arm; regression test `test_dl089_q02_prerequisite_arm_tolerates_malformed_payload` proves a malformed Q02 row neither aborts nor is lifted (27 + 93 tests green). No pending row carried invalid JSON at the time; workers reloaded before the fix are reloaded again at the next idle pass.
