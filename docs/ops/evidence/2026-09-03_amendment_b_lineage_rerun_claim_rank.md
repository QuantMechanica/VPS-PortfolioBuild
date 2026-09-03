# OWNER-DEC-PRE0803-RECOMPILE-SLOTORDER-AMENDB-20260903 §3 — Amendment B implemented

**Decision:** OWNER, 2026-09-03 ~02:08Z (Claude Code chat), recorded in
`docs/ops/evidence/2026-09-03_owner_dec_pre0803_recompile_slot_order_amendment_b.md` §3.
**Scope:** claim ORDER only. No gate criterion, hold, cap, verdict, threshold or T_Live
surface is touched; the selector's row SET is unchanged (verified below).

## Effect requested

An exact append-only lineage rerun (`payload.append_only_rerun = 1`, `priority_track = true`,
phase Q03–Q09) is claimed **before** every other priority-tracked row, instead of queuing
behind ~1,300 priority-tracked census cells (the QM5_11910 Q07 rerun waited 6–7 h while it
was the critical path to a Q10 lock).

## Change

`tools/strategy_farm/farmctl.py` (+63 lines, no deletions)

- new module constant `LINEAGE_RERUN_PRIORITY_PHASES = ("Q03".."Q09")` — the OWNER
  enumerated the span literally, so it is literal here; deriving it from the phase manifest
  would silently widen/narrow an OWNER decision the next time a phase is inserted;
- new builder `_lineage_rerun_rank_sql()` returning
  `CASE WHEN json_valid(payload)=1 AND json_extract('$.append_only_rerun')=1 AND
  json_type('$.priority_track')='true' AND phase IN (Q03..Q09) AND
  COALESCE(json_extract('$.poison_pill_priority_override'),0) <> 1 THEN 0 ELSE 1 END`.
  `json_valid` comes first for the reason Option A had to be patched post-commit: an
  unguarded `json_extract` on an empty/non-JSON payload raises `malformed JSON` and aborts
  the canonical claim-order query for **every** claimant;
- `pending_claim_order_sql()` projects it as `_lineage_rerun_rank` immediately after
  `_recovery_rank`, and the **top-down ORDER BY** consumes it between `_recovery_rank` and
  `_priority_track_rank`. The cold (`QM_TOPDOWN_GATE_PRIORITY_ENABLED` unset/`0`) ORDER BY
  is untouched — same gating as every other top-down key (`_topdown_gate_rank_sql`), so the
  pre-2026-08-28 selector still orders byte-for-byte as before. The alias is projected in
  both modes so diagnostics can read the rank without arming it.

`tools/strategy_farm/tests/test_opt_census_dispatch.py` (+306 lines, section 8): documented
order lineage rerun > sibling seed > census cell; eight near-miss payloads that must NOT earn
rank 0; malformed/empty payload neither aborts the query nor is lifted (DB-backed and
SQL-only); flag-off inertness on a fixture the amendment would otherwise invert; and the
blast-radius test below.

## Consequence of the key POSITION (stated explicitly, per the OWNER note's own wording)

The OWNER placed the key "immediately after `_recovery_rank`", i.e. **before**
`_priority_track_rank` and therefore before the top-down gate key. Two orderings follow that
the decision text does not spell out:

1. **Sibling Q02 prerequisite seeds (Option A) are outranked by a lineage rerun.** Option A's
   `-1` lives *inside* the gate key, which is evaluated after the new key. "Sibling seeds are
   unaffected" holds for their gate rank and for their precedence over census cells — the
   documented total order is now **lineage rerun > sibling seed > census cell**
   (`test_lineage_rerun_precedes_sibling_seed_and_priority_census`).
2. **The two seconds-cheap prerequisites at `_priority_track_rank = -1` are also outranked**
   — an authorized append-only source-repair `COMPILE_EA` row and an exact Q01 smoke row.
   Those exist precisely so a seconds-long prerequisite never sits behind an unbounded
   measurement programme; an hours-long lineage rerun now precedes them
   (`test_amendment_b_moves_lineage_rerun_ahead_of_the_cheap_prerequisites` pins this so it is
   visible rather than discovered in production). **No live victim today:** 0 pending rows
   currently hold the `-1` rank (read-only check below). Moving the `_lineage_rerun_rank` term
   one position later (after `_priority_track_rank`) would restore their precedence and still
   deliver Amendment B against the priority-tracked census, because census cells and lineage
   reruns both sit at `_priority_track_rank = 0`. That is an OWNER call, not an implementation
   detail — implemented as decided.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_opt_census_dispatch.py -q` → **40 passed**.
- Every test file that executes `pending_claim_order_sql()` plus the claim path
  (`test_ultracode_wsa_claim`, `test_terminal_worker_atomic_claim`,
  `test_pending_superseded_claim_filter`, `test_universe_expansion`,
  `test_activate_gate_manifest_v4`, `test_factory_off_build_interlock`,
  `test_news_gate_service`, `test_q09_news_farmctl_integration`,
  `test_recover_legacy_opt_census`, `test_claim_spacing`, `test_priority_track_new_q02`,
  `test_opt_census`, `test_opt_census_select`, `test_set_priority_track`) →
  **309 passed, 5 failed**. All five failures are in `test_set_priority_track.py`
  (`canonical claim-order query failed: no such table: work_item_supersedes` — the fixture DB
  lacks a table the selector has referenced since before this change) and were **reproduced on
  the unmodified HEAD** in this worktree: pre-existing, unrelated, not introduced here.
- **Read-only live-effect check** (`sqlite3` URI `mode=ro`, `PRAGMA query_only=ON`, real
  `pending_claim_order_sql()` with `QM_TOPDOWN_GATE_PRIORITY_ENABLED=1`, no writes) against
  `D:/QM/strategy_farm/state/farm_state.sqlite`, 2026-09-03:
  - 4 pending rows carry the exact marker set; 3 are claimable, and they move
    **1278→1, 1279→2, 1280→3** (QM5_1556/XAUUSD Q07, QM5_20085/XAUUSD Q07,
    QM5_11129/SP500 Q07). Positions 4+ are the OPT_CENSUS cells, in their previous relative
    order;
  - the claimable row SET is identical with and without the term (10,656 rows both ways) —
    only order changes; 1,280 rows shift position (the 3 reruns plus the census cells they
    pass);
  - 0 pending rows currently hold the `-1` prerequisite rank;
  - the 4th candidate (`3815515b…`, QM5_10700/XAUUSD Q07) is not claimable because of the
    active hold `AWAITING_OWNER_RECOMPILE_DECISION` (CEO 2026-09-03 01:30Z) — the amendment
    does not release holds.

## Rollback

Delete the `"_lineage_rerun_rank ASC, "` line from the top-down ORDER BY (one line) — the
projected alias then becomes inert. Full revert = drop the three farmctl hunks; the section-8
tests cover both the amended and the pre-amendment order.

## Rollout note

Resident terminal workers cache the selector at start, so the amendment reaches the fleet only
through the staggered idle-worker reload (one terminal at a time, never an active claim), the
same path Option A used.

## CEO merge note (2026-09-03 02:47Z, commit ea1bbb5e86)

The key was merged one position LATER than drafted above: the ORDER BY is now
`_universe_expansion_rank, _recovery_rank, _priority_track_rank, _lineage_rerun_rank, <gate rank>, …`.
Reason: `_priority_track_rank` ranks two seconds-cheap prerequisites at -1 (an authorized
append-only source-repair COMPILE_EA row and an exact Q01 smoke row); they keep precedence
over an hours-long lineage rerun. Inside the priority tier the OWNER-documented order
lineage rerun > sibling seed > census cell is unchanged. The test
`test_amendment_b_keeps_cheap_prerequisites_ahead_of_lineage_rerun` pins this placement;
any statement above that puts the lineage key before `_priority_track_rank` describes the
draft, not the shipped code. Live check 02:47Z: the QM5_11129 Q07 rerun sits at claim
position 2 (behind two other lineage reruns), previously ~1,285.
