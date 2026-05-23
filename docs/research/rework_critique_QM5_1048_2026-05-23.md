---
ea_id: QM5_1048
slug: estrada-lazy-6m-rotation
artifact_type: zero_trade_rework_critique
trigger: DL-062_zero_trade_rework_trigger
router_task_id: 34439feb-3c0b-40c1-a3a5-879cc3412a5f
parent_card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_1048_estrada-lazy-6m-rotation.md
author: claude
written_at: 2026-05-23
verdict: REWORK_ARCHITECTURAL_INCOMPATIBILITY_PARK_OR_RECAST
---

# QM5_1048 estrada-lazy-6m-rotation — zero-trade rework critique

Router flagged 18/20 zero-trade FAILs (`zero_trade_pct=0.9`). Unlike QM5_10020 / QM5_1044, this one is **not** a P2-enqueue scope bug or an infra bug. It is a deeper structural mismatch between the strategy's signal generator and V5's per-symbol P2 baseline architecture. The card itself flagged the risk; the evidence now confirms it.

## 1. Evidence sample (latest 15)

All 15 most-recent FAILs are 2026-05-19T03:02-03:13Z, P2, D1, on the wide DWX basket (XAUUSD, XTIUSD, USDJPY, XNGUSD, USDCHF, XAGUSD, NZDUSD, CHFJPY, GBPUSD, GBPNZD, GBPJPY, GBPCHF, GBPCAD, GBPAUD, EURUSD). `min_trades_required=6` over a 1-year sample. Sample summary.json from CHFJPY.DWX: deterministic, 2 runs, `total_trades=0` both runs.

Aggregate FAIL histogram:
```
MIN_TRADES_NOT_MET                          12
INVALID_REPORT;INCOMPLETE_RUNS               4
ACTIVE_TIMEOUT                               1
REPORT_MISSING;INCOMPLETE_RUNS               1
MIN_TRADES_NOT_MET;NON_DETERMINISTIC         1
REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS 1
```

12 clean `MIN_TRADES_NOT_MET` fails. The classifier here is **correct** — this EA really is producing zero trades. The question is why.

## 2. Root cause: per-symbol P2 ≠ cross-sectional rotation

The strategy is a **cross-sectional rank-and-rotate**: twice a year, rank N symbols by trailing 6-month total return, equal-weight the top half. Two structural facts make per-symbol P2 baseline meaningless:

### 2a. The signal is a relative ranking across the whole universe

A symbol's allocation is not a function of its own return — it is a function of its return **rank** among peers. Running the EA on CHFJPY.DWX in isolation gives the EA only one data series to rank, so the "top half of 4" rule degenerates to either "always long" (vacuous) or "never trades" (silent abort), depending on how the EA implementation handles a universe-of-one. Evidence says it picks the latter — 0 trades on every singleton.

This is not a strategy failure. It is the **P2 harness applying an architectural assumption (one EA = one symbol) that the strategy explicitly cannot satisfy.** The card's R3 line called this out: "thin cross-section may not survive — known degradation risk."

### 2b. Even the four target symbols ran outside their universe

Card universe: **NDX.DWX, WS30.DWX, GDAXI.DWX, UK100.DWX**. Evidence run set: XAUUSD, XTIUSD, USDJPY, XNGUSD, USDCHF, XAGUSD, NZDUSD, CHFJPY, GBPUSD, GBP*, EURUSD. **Zero overlap.** The P2 enqueue dispatched the EA on a basket that does not contain any of the four authorized rotation members. So the EA can't possibly fire even if the per-symbol model were valid — the universe array passed into the EA at init time excludes every routable rotation candidate.

This is the same enqueue-scope bug as QM5_10020 and QM5_1044, **stacked on top of** the architectural incompatibility.

## 3. The trade-frequency arithmetic was always tight

Card front-matter declares `expected_trades_per_year_per_symbol: 2` — semi-annual rebal. On a 1-year backtest with `min_trades_required=6`, the minimum is unreachable by definition: a single symbol can produce at most 2 entries + 2 exits = 4 fills in a year, and only when it's continuously in the top half. The framework's default `min_trades_required` floor was set for active strategies; for this card it is structurally unmeetable on a short sample. Even a clean run on NDX.DWX would FAIL.

## 4. Recommended change vector

Reject the router's hint to relax entry / substitute signal. Three viable paths, in order of preference:

### Option A — PARK until V5 supports portfolio-EA backtests

Recommend: hold the card in `cards_approved` with a `pipeline_phase: PARKED_ARCH_INCOMPAT` annotation. Reactivate when:
- V5 grows a multi-symbol P2 harness that loads all 4 universe members into a single EA instance (the registry+slot model the basket-EA recipe — memory `project_qm_basket_ea_build_2026-05-22` — was designed for), AND
- `min_trades_required` floor is overridable per card (or downgraded to ≥4 for semi-annual strategies).

This is the cleanest path; the strategy is published, professor-authored, with a 50-yr sample claim. Killing it on V5's per-symbol-architecture mismatch would be discarding a real edge for an infra reason.

### Option B — Recast as a single-symbol absolute-momentum EA

Strip the cross-sectional ranking; replace with absolute-momentum on a single symbol: long when trailing-6-mo return > 0, flat otherwise. This is a different strategy (Antonacci-style), not Estrada. It might fit the V5 P2 baseline as-is, but **it is not what the card describes** — would need a new card (new ea_id) per the strategy-card schema. Do not silently mutate QM5_1048 into Option B.

### Option C — DEAD now

Mark `pipeline_phase: DEAD`, lesson-learned: "V5 P2 architecture is per-symbol; cross-sectional rotation strategies require portfolio-EA harness, which V5 does not yet provide." Reactivation gated on V5 architectural change.

I lean Option A. The strategy direction is sound, the cost of parking is zero, and the V5 portfolio-EA harness is something the company will need for any future cross-sectional work anyway. Option C should be a deliberate decision, not an automatic fallback from a misclassified DL-062 trigger.

## 5. Edge Lab compliance note

The card predates the 2026-05-22 Edge Lab charter. If revived under Option A, it must also:
- Add explicit news-blackout (the card's stop-loss is ATR(D1,14)*4 — wide enough to coexist with FOMC dates if blackout is honored at the rebal day).
- Verify FTMO total-DD bound (10%) — a 4-symbol equal-weight basket of indices through a 2008/2020-style drawdown probably breaches this; needs explicit equity-curve check on the P2 baseline run before the charter clears it.
- Mechanical / no-ML: PASS (pure rank + select).
- Swing horizon D1: PASS.

## 6. Verification I ran

- 15 most-recent rows + full FAIL histogram from `farm_state.sqlite`
- `D:\QM\reports\work_items\d39f7474-…\summary.json` for CHFJPY.DWX — confirmed period=D1, year=2024, min_trades_required=6, total_trades=0 both deterministic runs
- Card front-matter and R3 thin-universe warning at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1048_estrada-lazy-6m-rotation.md`
- Cross-referenced memory: `project_qm_basket_ea_build_2026-05-22` for the multi-symbol-EA pattern Estrada would need
