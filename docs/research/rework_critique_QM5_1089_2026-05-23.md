---
ea_id: QM5_1089
slug: aa-raa-robust-pairs
artifact_type: zero_trade_rework_critique
trigger: DL-062_zero_trade_rework_trigger
router_task_id: a2b0e58a-ceee-4b3b-b0d0-473121398e26
parent_card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_1089_aa-raa-robust-pairs.md
author: claude
written_at: 2026-05-23
verdict: REWORK_FALSE_POSITIVE_REENQUEUE_AFTER_TIMEFRAME_AND_SCOPE_FIX
---

# QM5_1089 aa-raa-robust-pairs — zero-trade rework critique

Router fired DL-062 on `completed=42 / fail=41 / zero_trade=34 (zt_pct=0.83)`. After
reading the card, the per-asset rules are actually single-symbol-compatible
(unlike QM5_1088), so the architectural verdict is softer — but the same
**universe-mismatch + timeframe-mismatch** pair guarantees a zero-trade
false positive. Re-enqueue is the right answer, after the scope and cadence
get fixed.

## 1. Evidence sample (work_items, latest first)

| run                  | symbol       | phase | period | min_trades | result  | notes                  |
|----------------------|--------------|-------|--------|------------|---------|------------------------|
| 2026-05-18 14:09Z    | 30× FX/CFD   | P2    | H1     | 3          | FAIL    | full DWX fan-out       |
| 2026-05-18 14:09Z    | EURUSD.DWX   | P2    | H1     | 36         | FAIL    | in-universe (pair)     |
| 2026-05-18 14:09Z    | USDJPY.DWX   | P2    | H1     | 36         | FAIL    | in-universe (pair)     |
| 2026-05-18 14:09Z    | SP500.DWX    | P2    | H1     | 36         | FAIL    | in-universe (pair)     |
| 2026-05-18 14:09Z    | NDX.DWX      | P2    | H1     | 36         | FAIL    | in-universe (pair)     |
| 2026-05-18 14:09Z    | WS30.DWX     | P2    | H1     | 36         | FAIL    | in-universe (pair)     |
| 2026-05-18 14:09Z    | GDAXI.DWX    | P2    | H1     | 36         | INVALID | in-universe (pair)     |
| 2026-05-18 14:09Z    | XAUUSD.DWX   | P2    | H1     | 36         | FAIL    | in-universe (pair)     |
| 2026-05-18 14:09Z    | XTIUSD.DWX   | P2    | H1     | 36         | FAIL    | in-universe (pair)     |
| 2026-05-17 18:25Z    | EURUSD.DWX   | P2    | H1     | 5          | FAIL    | earlier seed run       |

Symbol histogram: 42 P2 rows across 36 unique DWX symbols (in-universe pair
symbols 2× each, full FX basket 1×). Card's intended pair-mapped universe is
8 symbols across 4 pairs.

## 2. Three independent root causes

### 2a. Dispatcher universe mismatch (scope)

Card §R3 explicitly enumerates the pair universe:
`SP500.DWX/GDAXI.DWX, XAUUSD.DWX/XTIUSD.DWX, EURUSD.DWX/USDJPY.DWX,
NDX.DWX/WS30.DWX` — eight symbols across four pairs. P2 enqueue ignored that
and fanned across the full ~36-symbol DWX universe (28 FX crosses + minors
out of universe). Same dispatcher bug as QM5_1088 / QM5_1048 / QM5_10020
(memory `project_qm_dispatcher_universe_mismatch_2026-05-23`).

### 2b. Timeframe mismatch — monthly TMOM+MA strategy run on H1

The mechanic is unambiguous:
- 12-month total return minus T-bill (TMOM) — monthly cadence
- close vs 12-month moving average — monthly close
- "Rebalance monthly"

`expected_trades_per_year_per_symbol: 12` = one rebalance per month per leg
(two half-legs per asset, each independently gated). Realistic max trades/yr
per leg is ~6–10 depending on regime persistence.

P2 ran every in-universe symbol on **H1** with **min_trades_required={5, 36}**
over a **1-year** window. min_trades=36/yr is unreachable for a monthly cadence
(absolute max is 24, achieved only with perfect TMOM-MA disagreement causing
re-flips every month). min_trades=5 *might* be hit if MA half flips into a
strong-trend regime, but the H1 candle granularity is wrong: the 12-month MA
and 12-month TMOM are constructed from monthly closes, not H1 closes, and
the rule evaluates "at the close" of each month.

This is **not** the architectural per-symbol incompatibility QM5_1088/QM5_1048
have. Each leg's TMOM and MA rule is independent of other legs — per-symbol
backtest CAN evaluate them. The defect is timeframe + window + min_trades, not
the harness's portfolio limitation. The pair-cash-routing logic is also
per-asset (each half independently goes to cash), so even the pair structure
is decomposable.

### 2c. INVALID for GDAXI / earlier seed runs

GDAXI.DWX in-universe shows `failed/INVALID` — likely the same H1-history
gap that hit QM5_1088 GDAXI/SP500/XAUUSD/XTIUSD. Separate build/data issue,
not zero-trade evidence.

## 3. Why the DL-062 trigger fired

Same false-positive pattern as the other three commits-`af0cc69a` critiques:
the classifier counts every `MIN_TRADES_NOT_MET` as zero-trade-evidence
regardless of (a) symbol being inside the card's target universe and (b) the
test conditions being structurally satisfiable by the strategy's own cadence.

For a monthly-rebalance strategy enqueued at H1 over 1 year with
`min_trades=36`, the trigger is **mechanically guaranteed to fire** even on a
perfect edge.

## 4. Recommended change vector

Reject the router hint to relax entry conditions / substitute signal logic.
The 12-month TMOM and 12-month MA rules are the entire Alpha-Architect Robust
Asset Allocation thesis — relaxing them is exactly the in-sample tuning the
pipeline exists to prevent. Required actions, in order:

1. **Ops (codex)**: honor `target_symbols` from card front-matter. Same fix
   shared with QM5_1088 / QM5_1048 / QM5_10020. Do NOT silently expand to
   full DWX universe.

2. **Setfile gen (codex)**: re-enqueue at **MN1** (monthly) timeframe, not H1.
   `framework/scripts/gen_setfile.ps1` should derive period from the card
   front-matter `period:` field (or from `expected_trades_per_year_per_symbol`
   ≤ 24 → MN1, ≤ 365 → D1). Card currently has no explicit `period:` token in
   front-matter — should be added; per memory
   `feedback_strategy_card_body_d1_token` the body needs an explicit
   timeframe token too.

3. **Min-trades floor**: for monthly cadence, set `min_trades_required` from
   `expected_trades_per_year_per_symbol × years × 0.5` (lower-bound on
   in-regime activity). At `12 × 5 × 0.5 = 30` for a 5y baseline.

4. **Window**: ≥7 years (12-month lookback warm-up + ≥5y test sample). DWX
   monthly history availability on each pair-leg needs to be verified before
   enqueue to avoid the `NO_HISTORY` failure mode from
   `project_qm5_1044_perf_rework_2026-05-16` /
   `project_qm_mt5_history_gap_infra_fail` siblings.

5. **Edge Lab compliance**: card pre-dates the 2026-05-22 charter. Add the
   FTMO-compliance block before any further pipeline time: ≤5% daily / ≤10%
   total DD, news-blackout filter (FOMC/CPI), no martingale/grid, mechanical,
   no-ML. Per-leg ATR stop + portfolio hard stop from V5 defaults should
   satisfy the DD bound but it has to be *declared*.

6. **Do NOT mark DEAD.** Do NOT relax the 12-month TMOM/MA gates.

## 5. Falsification — when this critique becomes wrong

If, after steps 1–4 (in-universe symbols only, MN1, ≥7y, min_trades=30), the
EA still produces fewer than 30 trades total across all 8 in-universe legs,
then the critique is wrong and either (a) the 12-month TMOM+MA filters are so
restrictive on DWX CFD-leg history that they cash-route everything most of
the time, or (b) the monthly DWX bar history is too short to support the
12-month warm-up. Either outcome is a legitimate kill verdict — current
evidence does not yet support it.

## 6. Verification I ran

- Card at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1089_aa-raa-robust-pairs.md`
  — confirmed pair-mapped 8-symbol universe, monthly TMOM+MA cadence,
  `expected_trades_per_year_per_symbol: 12`.
- Direct sqlite query against `D:\QM\strategy_farm\state\farm_state.sqlite`
  (work_items, ea_id=QM5_1089): 42 P2 rows, 36 unique symbols. In-universe
  pair symbols 2× each (one early seed at min_trades=5 + one bulk at
  min_trades=36); full DWX fan-out 1× each at min_trades=3.
- Sampled 4 out-of-universe + 8 in-universe `summary.json` files: period=H1
  throughout, year=2024, model=4.
- Cross-referenced sibling critiques (commit `af0cc69a`) — same dispatcher
  universe-mismatch + timeframe-mismatch failure class.
- Memory: `project_qm_dispatcher_universe_mismatch_2026-05-23`,
  `feedback_strategy_card_body_d1_token`.
