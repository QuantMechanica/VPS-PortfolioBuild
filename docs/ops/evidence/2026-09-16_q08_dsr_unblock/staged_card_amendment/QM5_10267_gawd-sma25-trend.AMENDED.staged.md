---
ea_id: QM5_10267
slug: gawd-sma25-trend
type: strategy
source_id: 1b906e79-c619-5a61-90db-ee19ac95a19f
sources:
  - "[[sources/github-gawd-backtest-indicator-strategies]]"
concepts:
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/sma]]"
period: D1
target_symbols: [NDX.DWX, WS30.DWX, SP500.DWX, XAUUSD.DWX]
source_citation: "gawd-coder/Backtest-Indicator-Strategies, Simple.py class Conventional_MA, https://github.com/gawd-coder/Backtest-Indicator-Strategies/blob/master/Simple.py"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 14
last_updated: 2026-05-21
r1_track_record: PASS
r1_reasoning: "Single source_id present with GitHub file URL pointing to exact source class and named author handle gawd-coder."
r2_mechanical: PASS
r2_reasoning: "Close vs SMA25 entry and exit rules are explicit and minimal; ATR stop is a V5 safety default."
r3_data_available: PASS
r3_reasoning: "D1 OHLC is available on NDX.DWX, WS30.DWX, XAUUSD.DWX, and SP500.DWX (backtest-only) on the DWX MT5 feed."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed SMA period with no ML/adaptive/grid/martingale and one position per magic."
pipeline_phase: G0
g0_approval_reasoning: "R1 PASS GitHub source file URL; R2 PASS mechanical SMA25 entry/exit with 14 trades/year/symbol; R3 PASS DWX indices/metals testable with SP500 T6 caveat; R4 PASS fixed params no ML one-position-per-magic."
---

# Gawd SMA25 Price Trend

## Source
- Source: [[sources/github-gawd-backtest-indicator-strategies]]
- Author / handle: `gawd-coder`.
- Repository: https://github.com/gawd-coder/Backtest-Indicator-Strategies
- Strategy file: `Simple.py`, class `Conventional_MA`.
- Citation URL: gawd-coder, "Backtest-Indicator-Strategies", GitHub repository, 2026, https://github.com/gawd-coder/Backtest-Indicator-Strategies/blob/master/Simple.py.
- Source rule: buy when `dataclose[0] > sma[0]`; sell when `dataclose[0] < sma[0]`; default `maperiod = 25`.

## Mechanics

Period: D1.

### Entry
- Compute `SMA25 = SMA(close, 25)`.
- If flat and close is above `SMA25`, open LONG at next bar open.
- Short side disabled in baseline; this is the source's long-only implementation.

### Exit
- Close LONG when close is below `SMA25`.

### Stop Loss
- Catastrophic stop: `3.0 * ATR(14)` from entry.
- P3 sweep: SMA period `20 / 25 / 35 / 50`; ATR multiplier `2.0 / 3.0 / 4.0`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: `RISK_PERCENT` per HR4.
- One position per magic.

### Additional filters
- Skip if `ATR(14) < 3 * spread`.
- Standard news blackout and Friday flatten for weekend-sensitive symbols.

## Target Symbols
NDX.DWX, WS30.DWX, SP500.DWX, XAUUSD.DWX. The source tests AAPL, but the rule is a generic D1 trend-following filter and ports to DWX trend instruments.

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Public GitHub URL with exact source file and author handle. |
| R2 Mechanical | UNKNOWN | Entry, exit, and SMA period are explicit; stop is V5 safety default. |
| R3 Data Available | UNKNOWN | D1 OHLC available on DWX indices/metals; SP500.DWX is backtest-only. |
| R4 ML Forbidden | UNKNOWN | Fixed SMA rule, no ML, no pyramiding, one position per magic. |

## R3
SP500.DWX is backtest-only on the Darwinex CFD feed. Live promotion T_Live gate: if the EA passes P0-P9 on SP500.DWX only, T_Live deploy requires parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline history
- G0: PENDING (Batch 2 draft 2026-05-21 from GitHub topic catalog).

## Related strategies
- TBD

## Lessons learned (during the pipeline run)
- TBD

## Approved Amendment (2026-09-14) — DSR Single Configuration

- Authority: `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`, OWNER receipt `3415f6c0…` (YES: "ABC & D freigegeben zur Umsetzung").
- This EA was never part of a sealed factory search (no DL-089 ledger); it carries exactly one configuration: the card defaults overlaid by the set file below. No optimisation search took place, research_trial_count is 0.
- This declaration locks the exact NDX.DWX/D1 configuration used by Q08 (set file `QM5_10267_gawd-sma25-trend_NDX.DWX_D1_backtest.set`). It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_10267",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "10267",
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
    "qm_magic_slot_offset": "0",
    "qm_news_compliance": "QM_NEWS_COMPLIANCE_DXZ",
    "qm_news_min_impact": "high",
    "qm_news_mode_legacy": "QM_NEWS_OFF",
    "qm_news_stale_max_hours": "336",
    "qm_news_temporal": "QM_NEWS_TEMPORAL_PRE30_POST30",
    "qm_rng_seed": "42",
    "qm_stress_reject_probability": "0.0",
    "strategy_atr_period": "14",
    "strategy_atr_sl_mult": "3.0",
    "strategy_min_atr_spread_mult": "3.0",
    "strategy_sma_period": "25",
    "strategy_timeframe": "PERIOD_D1"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "f600c0b08938bae5efa1133006349766d009e3bcdf4700f462efdfd6657e0702",
  "symbol": "NDX.DWX",
  "timeframe": "D1"
}
```
