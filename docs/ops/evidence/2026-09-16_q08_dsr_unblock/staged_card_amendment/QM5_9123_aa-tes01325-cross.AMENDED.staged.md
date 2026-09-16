---
ea_id: QM5_9123
slug: aa-tes01325-cross
type: strategy
source_id: ede348b4-0fa7-5be1-baa8-09e9089b67b7
sources:
  - "[[sources/alpha-architect-blog]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/digital-filter]]"
indicators:
  - "[[indicators/exponential-smoothing]]"
  - "[[indicators/triple-exponential-smoothing]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL present; R2 fixed TES cross entry/exit; R3 DWX daily CFD/SP500.DWX backtest with T6 caveat testable; R4 fixed params one-position no ML/grid/martingale."
expected_trades_per_year_per_symbol: 100
---

# Alpha Architect Triple ES 0.1325 Cross

## Source
- Source: [[sources/alpha-architect-blog]]
- Page / Timestamp: Henry Stern, "Trend-Following Filters - Part 2/2", 2021-01-21, https://alphaarchitect.com/trend-following-filters-part-2-2/

## Mechanics

Stern's triple exponential smoothing example uses fixed smoothing constant `alpha = 0.1325` and describes trading signals in the same family as the triple moving-average cross rules. This card uses the price crossing the third smoothing stage as a fixed trend signal.

### Entry
- Evaluate on the final completed D1 bar.
- Compute nested exponential smoothers with `alpha = 0.1325`: `ES1_t = alpha*Close_t + (1-alpha)*ES1_{t-1}`, `ES2_t = alpha*ES1_t + (1-alpha)*ES2_{t-1}`, `TES_t = alpha*ES2_t + (1-alpha)*TES_{t-1}`.
- Open long when `Close > TES` and prior `Close <= TES`.
- Open short when `Close < TES` and prior `Close >= TES`.
- Baseline DWX symbols: SP500.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX, XAUUSD.DWX, USOIL.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX.

### Exit
- Close long when `Close <= TES`.
- Close short when `Close >= TES`.
- Re-evaluate once per completed D1 bar.

### Stop Loss
- Initial SL = 2.5 x ATR(20,D1).
- Time stop: opposite daily close/TES cross.

### Position Sizing
- P2-baseline: `RISK_FIXED = 1000`.
- T6-live: `RISK_PERCENT = 0.5`.

### Additional filters
- One position per symbol/magic.
- Initialize all smoothing states with the first available close; require 120 completed D1 bars before trading.
- Skip new entries when D1 spread exceeds 2.5 x 20-day median spread.

## Concepts (what kind of strategy is this)
- [[concepts/trend-following]] - primary
- [[concepts/digital-filter]] - secondary

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Track Record | PASS | Full Alpha Architect URL with named author Henry Stern and publication date. |
| R2 Mechanical | PASS | Fixed alpha and deterministic nested ES calculation with close/smoother cross entries and exits. |
| R3 Data Available | PASS | Uses only completed daily closes and ATR on DWX CFDs; SP500.DWX caveat below. |
| R4 ML Forbidden | PASS | Fixed alpha; no ML, online learning, adaptive parameters, grid, or martingale. |

## R3
Original illustration uses daily S&P 500 data. DWX port applies the same fixed daily filter to index, commodity, gold, and FX CFDs.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline history
- G0: PENDING (Batch 17 draft 2026-05-19)
- P1: -
- P2: -

## Related strategies
- [[strategies/QM5_9016_aa-msm-pes0199]] - related fixed exponential-smoothing trend filter.
- [[strategies/QM5_9121_aa-tma10-cross]] - equal-weighted third-order sibling.

## Lessons learned (during the pipeline run)
- TBD

## Approved Amendment (2026-09-14) — DSR Single Configuration

- Authority: `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`, OWNER receipt `3415f6c0…` (YES: "ABC & D freigegeben zur Umsetzung").
- This EA was never part of a sealed factory search (no DL-089 ledger); it carries exactly one configuration: the card defaults overlaid by the set file below. No optimisation search took place, research_trial_count is 0.
- This declaration locks the exact NDX.DWX/D1 configuration used by Q08 (set file `QM5_9123_aa-tes01325-cross_NDX.DWX_D1_backtest.set`). It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_9123",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "9123",
    "qm_filter_news_enabled": "1",
    "qm_filter_news_mode": "3",
    "qm_filter_regime_bear_return_pct": "2.0",
    "qm_filter_regime_bull_return_pct": "2.0",
    "qm_filter_regime_enabled": "0",
    "qm_filter_regime_lookback_bars": "100",
    "qm_filter_volatility_atr_period": "14",
    "qm_filter_volatility_compression_ratio": "0.75",
    "qm_filter_volatility_enabled": "0",
    "qm_filter_volatility_expansion_ratio": "1.25",
    "qm_filter_volatility_lookback_bars": "50",
    "qm_friday_close_enabled": "1",
    "qm_friday_close_hour_broker": "0",
    "qm_magic_slot_offset": "1",
    "qm_news_compliance": "QM_NEWS_COMPLIANCE_DXZ",
    "qm_news_min_impact": "high",
    "qm_news_mode_legacy": "QM_NEWS_OFF",
    "qm_news_stale_max_hours": "336",
    "qm_news_temporal": "QM_NEWS_TEMPORAL_PRE30_POST30",
    "qm_rng_seed": "42",
    "qm_stress_reject_probability": "0.0",
    "strategy_alpha": "0.1325",
    "strategy_atr_period": "20",
    "strategy_atr_sl_mult": "2.5",
    "strategy_spread_mult": "2.5",
    "strategy_spread_window": "20",
    "strategy_warmup_bars": "120"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "1190a36a924c973757c08659a18f858d5a9f94be9fa33cbecff556ff6a3c7b68",
  "symbol": "NDX.DWX",
  "timeframe": "D1"
}
```
