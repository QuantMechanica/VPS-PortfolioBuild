---
ea_id: QM5_1100
slug: index-weekly-reversal-monday
artifact_type: zero_trade_rework_critique
trigger: DL-062_zero_trade_rework_trigger
router_task_id: f4082e3d-775b-46de-a1b4-1bab08555d9c
parent_card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_1100_index-weekly-reversal-monday.md
author: claude
written_at: 2026-05-23
verdict: REWORK_FALSE_POSITIVE_REENQUEUE_AFTER_SCOPE_FIX_AND_INVESTIGATE_INVALID_INDEX_RUNS
---

# QM5_1100 index-weekly-reversal-monday — zero-trade rework critique

Router fired DL-062 on `completed=37 / fail=32 / zero_trade=32 (zt_pct=1.0)`.
This card has **two problems prior to anything pipeline-related** that the
DL-062 trigger papered over:

1. The card is still `g0_status: DRAFT` per its own front-matter — should not
   have been routed to P2 builds yet.
2. The card's intended universe is 4 index CFDs (`NDX, WS30, GDAXI, UK100`),
   but **all four in-universe runs failed as INVALID** (build/data issue),
   while 33 out-of-universe FX runs failed with 0 trades exactly as the
   weekend-effect theory predicts they should.

So the 100% zero-trade ratio is a composite of "FX correctly producing zero
trades on a stock-index-only mechanic" and "in-universe indices not even
producing valid backtest reports". Neither is strategy mortality.

## 1. Evidence sample

| run                  | symbol         | phase | period | min_trades | result  | notes                       |
|----------------------|----------------|-------|--------|------------|---------|-----------------------------|
| 2026-05-18 14:09Z    | 33× FX (OOU)   | P2    | D1     | 6          | FAIL    | weekend-effect is index-only|
| 2026-05-18 14:09Z    | NDX.DWX        | P2    | D1     | 6          | INVALID | in-universe, build/data gap |
| 2026-05-18 14:09Z    | WS30.DWX       | P2    | D1     | 6          | INVALID | in-universe, build/data gap |
| 2026-05-18 14:09Z    | GDAXI.DWX      | P2    | D1     | 6          | INVALID | in-universe, build/data gap |
| 2026-05-18 14:09Z    | UK100.DWX      | P2    | D1     | 6          | INVALID | in-universe, build/data gap |

Symbol histogram: 37 unique DWX symbols. 33 FX (out-of-universe, FAIL with
0 trades); 4 in-universe indices (all `failed/INVALID`, no valid report
produced).

## 2. Multiple compounding root causes — none of them is "the edge is dead"

### 2a. Card is still DRAFT — should not be in the P2 queue

Front-matter:
```
g0_status: DRAFT
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
```

A G0/DRAFT card has not been QB-vetted and should not have been queued for
P2 builds. That this card is sitting under `cards_approved/` is itself a
process issue — APPROVED is supposed to mean `g0_status: APPROVED` per the
strategy_card_schema in the router payloads
(`frontmatter_required: [..., g0_status, ...]`).

### 2b. Dispatcher universe mismatch (scope)

Card explicitly enumerates the index universe in the body:
> "Suggested per-symbol runs: `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX`."

The weekend-effect mechanism is **specifically about equity-index cash
sessions and the Monday-bounce after a negative week**. The source theses
(French 1980, Keim & Stambaugh 1984, Jacobsen & Marquering 2008) are all
documented on US stock indices. FX weekend behavior is dominated by
position-squaring and Asian-open gaps, not by the weekend-effect — running
this rule on AUDCAD or NZDJPY is theoretically null.

33/37 zero-trade fails are on FX symbols where the rule producing zero
entries is the *correct* output of the mechanic. Same dispatcher bug as
QM5_1088 / QM5_1089 / QM5_1096 / QM5_1097 / QM5_1048 / QM5_10020.

### 2c. All 4 in-universe indices INVALID — build or data gap

The 4 symbols that *could* test the thesis (NDX, WS30, GDAXI, UK100) all
report `status: failed` with `verdict: INVALID` — meaning no clean
deterministic report was produced. Common causes per memory
`project_qm_mt5_history_gap_infra_fail`:
- D1 history gap on the DWX index symbol for 2024;
- `INIT_FAILED` due to stale news-calendar (memory
  `project_qm_news_calendar_stale_2026-05-19`);
- Build-side EX5 init failure (e.g., 5-bar return computation requesting
  bar offset before symbol history begins).

Without valid 2024 D1 reports on the intended universe, no zero-trade
inference is possible on the strategy at all. The DL-062 trigger should
not have fired on an EA whose in-universe runs all came back INVALID.

### 2d. Front-matter typo: `expected_trades_per_year_per_symbol: 2`

The body §Rationale says "~50 trades/year per symbol" and §"proposed_after_audit"
says "Annual trade count ~20-30/year". Front-matter says `2` — which is
wrong. With the entry rule "Friday close if prior 5-day return < 0", and
~50% of weeks being net-negative, expected ≈ 52 × 0.5 = 26 entries/yr/symbol.

The `2` value is the wrong order of magnitude. `min_trades_required=6`
that was used in this enqueue happens to be sensible for the *correct*
expected count (26 × 1 year × 0.25 = 6), so the bug did not propagate
into the wrapper threshold — but the front-matter still needs fixing or
future auto-derivation will be off.

## 3. Why the DL-062 trigger fired

Compound false positive:
- 33/37 fails are on FX (out-of-universe, correct zero-trade behavior).
- 4/37 fails are INVALID (no valid report on the indices the strategy
  is actually for).
- Classifier counts all of them as zero-trade evidence.

100% zero-trade ratio is therefore mechanically guaranteed regardless of
whether the strategy has any edge.

## 4. Recommended change vector

Reject the router hint to relax entry conditions / substitute signal logic.
The 5-day-negative-return + Friday-close-entry + Monday-close-exit rule IS
the entire weekend-effect mechanic. Relaxing it (e.g., removing the
"week was negative" gate) would convert it into a different strategy
entirely. Required actions:

1. **Process (claude/codex)**: route card back to G0 review. `g0_status:
   DRAFT` should not be in `cards_approved/`. Run R1–R4 vetting per
   `processes/qb_reputable_source_criteria.md` (memory
   `project_qb_reputable_source_binding`). Promote to APPROVED only if
   it clears.

2. **Front-matter fix**: change `expected_trades_per_year_per_symbol: 2`
   → `~25` (the value derived from the entry rule).

3. **Ops (codex)**: honor card body's enumerated symbols. Do NOT fan
   weekend-effect strategies across FX universe.

4. **Investigate INVALID (codex)**: triage the NDX/WS30/GDAXI/UK100 D1
   2024 INVALID runs. Per memory `project_qm_mt5_history_gap_infra_fail`,
   first check whether DWX D1 history exists for these symbols over the
   enqueued window; second, check news-calendar freshness; third, check
   build-side init for the 5-bar return computation.

5. **Re-enqueue (after #1–#4)**: P2 on `NDX.DWX, WS30.DWX, GDAXI.DWX,
   UK100.DWX` only, D1, **≥10y window** (the weekend-effect's reported
   persistence has weakened post-2000 per Jacobsen & Marquering — needs
   a long window to detect whether the effect still clears costs). At
   ~25 trades/yr/symbol × 10y = 250 expected, set `min_trades_required = 100`.

6. **Edge Lab compliance**: card pre-dates the 2026-05-22 charter. Add
   FTMO-compliance block: `max_stop_pct = 2.0%` per trade is borderline
   — for the 10% total DD bound, 5 simultaneous max-loss positions would
   trip the floor. Recommend tightening to 1.0% per trade OR documenting
   the multi-symbol concurrency cap. News blackout: not declared in the
   card — add the standard V5 high-impact news skip per charter.
   Mechanical, no-ML, no grid/martingale, long-only — all satisfied.

7. **Do NOT mark DEAD.** Do NOT relax the negative-week gate (turning it
   into a Monday-buy-the-dip mechanic would be a different strategy).

## 5. Falsification — when this critique becomes wrong

If, after #1 (G0 re-vetting) clears, #4 (INVALID triage) produces valid
backtests on the 4 in-universe indices, and #5 (re-enqueue ≥10y) still
shows the entries do clear `min_trades=100` but fail at the P2 cost-gate
(commissions/swap > edge), then the critique is wrong and the
weekend-effect is no longer tradable on DWX indices net of costs. That
would be a legitimate kill verdict — current evidence does not yet
support it.

If the in-universe INVALID runs turn out to be a permanent D1 history gap
on DWX indices for the required ≥10y window, that is an infrastructure
limitation that should be flagged separately rather than ascribed to the
strategy.

## 6. Verification I ran

- Card at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1100_index-weekly-reversal-monday.md`
  — confirmed `g0_status: DRAFT`, R1–R4 all `UNKNOWN`, 4-index universe in body,
  ~50 trades/yr/symbol in body but `expected_trades_per_year_per_symbol: 2`
  in front-matter (inconsistent).
- Direct sqlite query against `D:\QM\strategy_farm\state\farm_state.sqlite`
  (work_items, ea_id=QM5_1100): 37 P2 rows. 33 FX out-of-universe (status=done,
  verdict=FAIL); 4 in-universe indices (status=failed, verdict=INVALID).
- Confirmed all 4 indices INVALID before any zero-trade attribution is
  meaningful — see `2c`.
- Memory: `project_qm_dispatcher_universe_mismatch_2026-05-23`,
  `project_qm_mt5_history_gap_infra_fail`,
  `project_qm_news_calendar_stale_2026-05-19`,
  `project_qb_reputable_source_binding`.
