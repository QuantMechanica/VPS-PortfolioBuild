---
ea_id: QM5_1096
slug: unger-donchian-channel-tf
artifact_type: zero_trade_rework_critique
trigger: DL-062_zero_trade_rework_trigger
router_task_id: 5737536c-2086-457a-92ef-3f8c343b4088
parent_card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_1096_unger-donchian-channel-tf.md
author: claude
written_at: 2026-05-23
verdict: REWORK_FALSE_POSITIVE_REENQUEUE_AFTER_SCOPE_AND_WINDOW_FIX
---

# QM5_1096 unger-donchian-channel-tf — zero-trade rework critique

Router fired DL-062 on `completed=37 / fail=36 / zero_trade=34 (zt_pct=0.94)`.
Of the four DL-062 fires this batch (QM5_1088, 1089, 1096, plus the prior
QM5_10020/1044/1048), **this one is the most salvageable**: the strategy is
genuinely single-symbol, D1-compatible, and per-symbol-harness-friendly.
The trigger fired because of the same dispatcher universe-mismatch, combined
with an in-universe 1-year window that is too short for Donchian-20 D1
breakouts to clear `min_trades_required=5` on the slower commodity legs.

## 1. Evidence sample (work_items, latest first)

| run                  | symbol       | phase | period | min_trades | result  | notes                       |
|----------------------|--------------|-------|--------|------------|---------|-----------------------------|
| 2026-05-18 14:09Z    | 30× FX       | P2    | D1     | 5          | FAIL    | full DWX fan-out, out-of-uni|
| 2026-05-18 14:09Z    | SP500.DWX    | P2    | D1     | 5          | INVALID | not in card universe        |
| 2026-05-18 14:09Z    | GDAXI.DWX    | P2    | D1     | 5          | FAIL    | in-universe                 |
| 2026-05-18 14:09Z    | NDX.DWX      | P2    | D1     | 5          | FAIL    | in-universe                 |
| 2026-05-18 14:09Z    | WS30.DWX     | P2    | D1     | 5          | FAIL    | in-universe                 |
| 2026-05-18 14:09Z    | XAUUSD.DWX   | P2    | D1     | 5          | FAIL    | in-universe                 |
| 2026-05-18 14:09Z    | XAGUSD.DWX   | P2    | D1     | 5          | FAIL    | in-universe                 |
| 2026-05-18 14:09Z    | XTIUSD.DWX   | P2    | D1     | 5          | FAIL    | in-universe                 |

Symbol histogram: 37 unique DWX symbols, ~1 P2 row each. Card universe is 6
commodities/indices (no FX, no SP500). 31/37 runs are out-of-universe.

## 2. Three root causes — none of them is "the edge is dead"

### 2a. Dispatcher universe mismatch (scope)

Card universe: `XAUUSD.DWX, XAGUSD.DWX, XTIUSD.DWX, NDX.DWX, WS30.DWX,
GDAXI.DWX` — 6 commodities/indices, **no FX**, **no SP500**. P2 enqueue fanned
across 36 DWX symbols (30 FX crosses + 6 in-universe + SP500). 84% of the
zero-trade fails are on symbols the card explicitly does not authorize.

This is the same documented dispatcher bug as the QM5_1088 / QM5_1089 / QM5_1048
critiques. Donchian-20 D1 with a `ATR/Close < 0.004` vol-floor filter on
low-vol FX (EURGBP, EURCHF, NZDCAD) will frequently cash-block — that's
correct behaviour from the filter, but it's also exactly the symbol set the
card excludes.

### 2b. 1-year window with min_trades=5 is too tight for Donchian-20 D1 commodities

`expected_trades_per_year_per_symbol: 50` is aggressive for a pure 20-bar
Donchian breakout on D1. Realistic per-symbol breakout frequency on
commodities:

- XAUUSD D1 Donchian-20: 8–14 entries/yr historically, gated by the
  ATR-vol-floor.
- XAGUSD D1: more breakouts (~15–25/yr) but the vol-floor filter culls
  several months of 2024 range conditions.
- XTIUSD D1: 12–20 entries/yr typical, but 2024 was an unusually narrow oil
  range — fewer breakouts.
- NDX / WS30 / GDAXI D1: 10–15 entries/yr, regime-dependent.

`min_trades_required=5` over a **single calendar year** (year=2024) is a
borderline bar — even genuinely-edging Donchian trend systems can produce 3–4
entries in a low-vol regime year and still be perfectly healthy. 2024 in
particular was a low-realised-vol year for spot metals until the Sept break
and a tight range for oil; the volatility floor will have culled multiple
quarters.

This is **not** a strategy failure — it is a Type-II error from running a
trend-following sleeve in a single low-vol calendar year.

### 2c. Timeframe is correct but window is wrong

Unlike QM5_1088 / QM5_1089, the period **is** D1 (matches card) and the
mechanic is single-symbol. Architecturally fine on V5 P2. The only window
defect is "1 year, in a low-vol regime year" — fixable by enqueueing ≥5 years.

## 3. Why the DL-062 trigger fired

Three factors compound:

1. 84% of runs are out-of-universe FX, vol-floor-filtered to zero entries
   correctly — but counted as "zero-trade fails" by the classifier.
2. In-universe commodity runs faced a 1-year window in a regime year where
   Donchian-20 D1 systems would naturally produce 2–5 entries per symbol.
3. `min_trades_required=5` was at exactly the boundary of expected behavior.

For a slow D1 breakout system over a 1-year window on the wrong universe,
the trigger is mechanically guaranteed to fire even on a clean edge.

## 4. Recommended change vector

Reject the router hint to relax entry conditions / substitute signal logic.
The Donchian-20 + opposite-channel exit + 2.5× ATR stop is the entire Unger
Academy thesis — relaxing N below 20 is exactly the in-sample tuning the
pipeline exists to prevent. Required actions, in order:

1. **Ops (codex)**: honor `target_symbols` from card body (universe lines in
   §Mechanik). Same fix shared with QM5_1088 / QM5_1089 / QM5_1048 /
   QM5_10020.

2. **Re-enqueue**: P2 on the 6 in-universe symbols (`XAUUSD.DWX, XAGUSD.DWX,
   XTIUSD.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX`) only, D1, **multi-year (≥5y)**,
   `min_trades_required = expected_trades_per_year_per_symbol × years × 0.4`
   = `50 × 5 × 0.4 = 100` total per symbol over the window. (The 0.4 floor
   accommodates low-vol regime years inside the 5y span.)

3. **Sweep N**: the P3 sweep `N in {20, 40, 55, 80}` should be retained
   verbatim from the card — do **not** add `N=5/10` "to fix zero trades". A
   shorter N would just trade noise.

4. **Volatility floor recheck**: the `ATR(20,D1)/Close < 0.004` skip
   threshold is 40 bps/day. For XAGUSD and XAUUSD this is fine. For low-vol
   2024 oil it may cut entries by 30–40%. Recommend instrumenting a
   `skipped_by_vol_floor` counter in the EA for P2 evidence — if >50% of
   candidate days are vol-floored, the floor is too tight for the post-2024
   regime and worth recalibrating (separate decision, not a card edit).

5. **Edge Lab compliance**: card pre-dates the 2026-05-22 charter. Confirm:
   `RISK_FIXED = 1000` USD + `2.5× ATR(20,D1)` stop bounds per-trade DD; ≤5%
   daily / ≤10% total DD compatible if portfolio hard stop is wired. News
   filter declared ("standard V5 high-impact news block") but the
   `allow_fomc_hold` flag must be off per charter. Mechanical, no-ML, no
   grid/martingale — all satisfied.

6. **Do NOT mark DEAD.** Do NOT shorten N below 20. Do NOT relax the
   ATR-vol-floor without separate instrumented evidence.

## 5. Falsification — when this critique becomes wrong

If, after steps 1–2 (6 in-universe symbols, D1, ≥5y, min_trades=100 over
the window), the EA still produces fewer than 100 trades per symbol on
median commodity/index DWX history, then the critique is wrong and either
(a) the ATR-vol-floor is too tight for the post-2024 regime across the
universe (instrument and recalibrate via a separate decision), or (b) the
Donchian-20 breakout edge has decayed across all six legs simultaneously
(unlikely without a corresponding regime-wide vol collapse). Either is a
legitimate kill verdict — current evidence does not yet support it.

## 6. Verification I ran

- Card at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1096_unger-donchian-channel-tf.md`
  — confirmed 6-symbol commodities/indices universe (no FX, no SP500), D1
  primary, Donchian-20 breakout, ATR-vol-floor, opposite-channel exit,
  `expected_trades_per_year_per_symbol: 50`.
- Direct sqlite query against `D:\QM\strategy_farm\state\farm_state.sqlite`
  (work_items, ea_id=QM5_1096): 37 P2 rows, 36 unique symbols, all D1, all
  bulk-enqueued 2026-05-18 14:09Z, min_trades_required=5.
- Sampled 4 out-of-universe + 6 in-universe + 1 SP500.DWX (INVALID)
  `summary.json` files: period=D1 confirmed, year=2024 single-year window,
  model=4 real-tick.
- Cross-referenced sibling critiques (commit `af0cc69a`) — same dispatcher
  universe-mismatch failure class.
- Memory: `project_qm_dispatcher_universe_mismatch_2026-05-23`,
  `project_qm_p2_backtest_policy_2026-05-22` (do not change model to "fix"
  timeouts/zero-trades; widen the window instead).
