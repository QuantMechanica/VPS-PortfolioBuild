---
ea_id: QM5_10804
slug: tv-st-long
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "holdon_to_profits, SuperTrend STRATEGY, TradingView open-source strategy, updated 2026-02-11, https://www.tradingview.com/script/VLRj2sG9-SuperTrend-STRATEGY/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/volatility-trailing-stop]]"
indicators:
  - "[[indicators/supertrend]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 45
last_updated: 2026-05-22
g0_approval_reasoning: "R1 exact TradingView URL cited; R2 SuperTrend flip long entry/exit is deterministic with ~45 trades/year/symbol; R3 ATR/OHLC SuperTrend testable on DWX CFDs; R4 fixed non-ML one-position rules."
---

# TradingView SuperTrend Long-Only Flip

## Source
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `SuperTrend STRATEGY`, author handle `holdon_to_profits`, open-source strategy, updated 2026-02-11, accessed 2026-05-22, https://www.tradingview.com/script/VLRj2sG9-SuperTrend-STRATEGY/

## Mechanics

### Entry
Use H4/D1 baseline.

- Compute SuperTrend from hl2 using ATR period 10 and multiplier 3.0 as the source default.
- Long entry when SuperTrend flips from bearish to bullish.
- Enter on bar close; source release notes explicitly use close-synchronized execution.
- No short entries.
- One open position per symbol/magic.

### Exit
- Close the long when SuperTrend flips back from bullish to bearish.
- Optional V5 max-bars exit for stale trades: 120 H4 bars or 60 D1 bars.

### Stop Loss
- Source-pure stop is the SuperTrend bearish flip.
- V5 safety stop:
  - Initial hard stop at min(SuperTrend lower band, entry - 2.0 * ATR(14)).
  - Trail to the active SuperTrend band after entry.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic.

### Zusatzliche Filter
- Source includes a customizable backtest date range; ignore for live logic.
- Optional V5 spread/session/news filters only.

## Concepts (what kind of strategy is this)
- [[concepts/trend-following]] - follows a volatility-adjusted trend flip.
- [[concepts/volatility-trailing-stop]] - exit is tied to SuperTrend/ATR state.

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `holdon_to_profits` are cited. |
| R2 Mechanical | PASS | Source gives explicit long entry and exit on SuperTrend flips with fixed defaults. |
| R3 Data Available | PASS | SuperTrend, ATR, hl2, and OHLC are available on DWX symbols. |
| R4 ML Forbidden | PASS | Fixed indicator rule; no ML, grid, martingale, or adaptive online parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD, GER40.DWX, NDX.DWX, WS30.DWX.

If this is later tested primarily on SP500.DWX, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says long entries occur when SuperTrend flips from bearish to bullish.
- Source says the position is closed when SuperTrend flips back to bearish.
- Source default settings are ATR period 10, multiplier 3.0, and hl2 source.

## Parameters To Test
- ATR period: 7, 10, 14.
- SuperTrend multiplier: 2.0, 3.0, 4.0, 8.5.
- Timeframe: H1, H4, D1.
- Safety stop: SuperTrend only, ATR(14) * 2.0 hard floor.

## Initial Risk Profile
Low-complexity trend follower. Expected weakness is whipsaw in sideways regimes; pipeline should test with and without an ADX no-trade filter.

## Pipeline history
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Related strategies
- QM5_10794 tv-atr-st
- QM5_10791 tv-stc-tt

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD

## Approved Amendment (2026-09-14) — DSR Single Configuration

- Authority: `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`, OWNER receipt `3415f6c0…` (YES: "ABC & D freigegeben zur Umsetzung").
- This EA was never part of a sealed factory search (no DL-089 ledger); it carries exactly one configuration: the card defaults overlaid by the set file below. No optimisation search took place, research_trial_count is 0.
- This declaration locks the exact GDAXI.DWX/H1 configuration used by Q08 (set file `QM5_10804_tv-st-long_GDAXI.DWX_H1_backtest_ablation_00.set`). It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_10804",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "10804",
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
    "qm_friday_close_enabled": "true",
    "qm_friday_close_hour_broker": "21",
    "qm_magic_slot_offset": "4",
    "qm_news_compliance": "QM_NEWS_COMPLIANCE_DXZ",
    "qm_news_min_impact": "high",
    "qm_news_mode_legacy": "QM_NEWS_OFF",
    "qm_news_stale_max_hours": "336",
    "qm_news_temporal": "QM_NEWS_TEMPORAL_PRE30_POST30",
    "qm_rng_seed": "42",
    "qm_stress_reject_probability": "0.0",
    "strategy_enable_max_bars_exit": "true",
    "strategy_max_bars_d1": "69",
    "strategy_max_bars_h4": "146",
    "strategy_safety_atr_mult": "2.157803",
    "strategy_safety_atr_period": "14",
    "strategy_st_atr_period": "10",
    "strategy_st_multiplier": "2.858247",
    "strategy_st_warmup_bars": "168"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "004a4f6d0fd885a092f92ff60fc17290f9e787d755d1324cbf643bdcf0982e05",
  "symbol": "GDAXI.DWX",
  "timeframe": "H1"
}
```
