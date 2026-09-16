---
ea_id: QM5_10211
slug: tv-williams-r-spy
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/oscillator-reversal]]"
indicators:
  - "[[indicators/williams-r]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 10
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL/author cited; R2 mechanical Williams %R entry/exit with ~55 trades/year/symbol; R3 OHLC oscillator testable on SP500.DWX backtest with NDX/WS30 T6 live caveat; R4 fixed non-ML one-position rules."
---

# TradingView Williams Percent R SPY Reversal

## Source
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Williams %R Strategy`, author handle `EdgeTools`, published 2024-10-15, https://www.tradingview.com/script/WgrZZgCZ/

## Mechanics

### Entry
Use D1 bars for the baseline. Compute Williams %R with configurable lookback between 2 and 25 bars; start P2 with length 2 and compare length 5/10 in P3 only if G0/P1 survives. Enter long when Williams %R falls below -90.

### Exit
Exit long when either current close is higher than the previous day's high, or Williams %R rises above -30.

### Stop Loss
Source does not define a stop. Add V5 protective stop at 2.5 * ATR(14) below entry or a 5% price stop, whichever is tighter on SP500.DWX-equivalent price scale.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
Target symbols: SP500.DWX as SPY analog, NDX.DWX and WS30.DWX as live-routable index-CFD cross-checks. Long-only baseline to preserve the source's SPY reversal design. No entry on the same bar as an exit.

## Concepts (what kind of strategy is this)
- [[concepts/mean-reversion]] - buys short-term oversold index conditions.
- [[concepts/oscillator-reversal]] - Williams %R threshold drives entry and exit.

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `EdgeTools` are cited. |
| R2 Mechanical | PASS | Source gives explicit Williams %R entry below -90 and two exit conditions. |
| R3 Data Available | PASS | Williams %R uses OHLC only and ports from SPY to SP500.DWX / NDX.DWX / WS30.DWX. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. |
| R4 ML Forbidden | PASS | Fixed oscillator thresholds and protective stop; no ML, grid, martingale, pyramiding, or adaptive online parameters. |

## Pipeline history
- G0: 2026-05-19, PENDING, drafted from TradingView popular Pine strategy page.

## Related strategies
- [[strategies/QM5_10171_tv-vwap-rsi-dip]] - index-style oscillator pullback family.
- [[strategies/QM5_9948_bandy-d1-setup-h1-trigger-mr-index]] - index mean-reversion family.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD

## Approved Amendment (2026-09-14) — DSR Single Configuration

- Authority: `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`, OWNER receipt `3415f6c0…` (YES: "ABC & D freigegeben zur Umsetzung").
- This EA was never part of a sealed factory search (no DL-089 ledger); it carries exactly one configuration: the card defaults overlaid by the set file below. No optimisation search took place, research_trial_count is 0.
- This declaration locks the exact NDX.DWX/D1 configuration used by Q08 (set file `QM5_10211_tv-williams-r-spy_NDX.DWX_D1_backtest.set`). It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_10211",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "10211",
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
    "qm_magic_slot_offset": "1",
    "qm_news_compliance": "QM_NEWS_COMPLIANCE_DXZ",
    "qm_news_min_impact": "high",
    "qm_news_mode_legacy": "QM_NEWS_OFF",
    "qm_news_stale_max_hours": "336",
    "qm_news_temporal": "QM_NEWS_TEMPORAL_PRE30_POST30",
    "qm_rng_seed": "42",
    "qm_stress_reject_probability": "0.0",
    "strategy_atr_period": "14",
    "strategy_atr_sl_mult": "2.5",
    "strategy_entry_wpr": "-90.0",
    "strategy_exit_wpr": "-30.0",
    "strategy_price_sl_pct": "5.0",
    "strategy_wpr_length": "2"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "2f194256f76064b3bc6acce7ea04fc92937fb52de8d4c36c292a0d1b6f80ec5a",
  "symbol": "NDX.DWX",
  "timeframe": "D1"
}
```
