---
ea_id: QM5_10269
slug: gawd-wma30-trend
type: strategy
source_id: 1b906e79-c619-5a61-90db-ee19ac95a19f
sources:
  - "[[sources/github-gawd-backtest-indicator-strategies]]"
concepts:
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/wma]]"
period: D1
target_symbols: [AUDUSD.DWX, EURUSD.DWX, GBPUSD.DWX, GDAXI.DWX, NDX.DWX, NZDUSD.DWX, SP500.DWX, UK100.DWX, USDCAD.DWX, USDCHF.DWX, USDJPY.DWX, WS30.DWX, XAUUSD.DWX]
source_citation: "gawd-coder/Backtest-Indicator-Strategies, Simple.py class WMA, https://github.com/gawd-coder/Backtest-Indicator-Strategies/blob/master/Simple.py"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 16
last_updated: 2026-05-21
r1_track_record: PASS
r1_reasoning: "Single source_id present with verifiable GitHub URL and named author/class citation."
r2_mechanical: PASS
r2_reasoning: "WMA30 price-comparison entry and exit are explicit and fully deterministic."
r3_data_available: PASS
r3_reasoning: "NDX.DWX, WS30.DWX, SP500.DWX, XAUUSD.DWX are all available DWX instruments; SP500.DWX backtest-only caveat noted."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed WMA period, no ML, no adaptive parameters, one position per magic."
pipeline_phase: G0
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "R1 verifiable GitHub source file/class; R2 deterministic WMA30 entry/exit with 16 trades/year/symbol estimate; R3 portable to DWX indices/metals with SP500 caveat; R4 fixed-rule no ML one-position-per-magic."
---

# Gawd WMA30 Price Trend

## Source
- Source: [[sources/github-gawd-backtest-indicator-strategies]]
- Author / handle: `gawd-coder`.
- Repository: https://github.com/gawd-coder/Backtest-Indicator-Strategies
- Strategy file: `Simple.py`, class `WMA`.
- Citation detail: 2026-05-21 URL https://github.com/gawd-coder/Backtest-Indicator-Strategies/blob/master/Simple.py
- Source rule: buy when close is above weighted moving average; sell when close is below weighted moving average; default `maperiod = 30`.

## Mechanics

Period: D1.

### Entry
- Compute `WMA30 = WeightedMovingAverage(close, 30)`.
- If flat and close is above `WMA30`, open LONG at next bar open.

### Exit
- Close LONG when close is below `WMA30`.

### Stop Loss
- Catastrophic stop: `3.0 * ATR(14)` from entry.
- P3 sweep: WMA period `20 / 30 / 45`; ATR multiplier `2.0 / 3.0 / 4.0`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: `RISK_PERCENT` per HR4.
- One position per magic.

### Additional filters
- Require band-equivalent volatility: `ATR(14) > 3 * spread`.
- Standard news blackout and Friday flatten for weekend-sensitive symbols.

## Target Symbols
NDX.DWX, WS30.DWX, SP500.DWX, XAUUSD.DWX. WMA trend-following is generic and testable on DWX instruments.

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Public GitHub URL with exact source file and class. |
| R2 Mechanical | UNKNOWN | WMA period, entry, and exit are explicit; stop is V5 safety default. |
| R3 Data Available | UNKNOWN | D1 OHLC available on DWX index/metals; SP500.DWX backtest-only caveat applies. |
| R4 ML Forbidden | UNKNOWN | Fixed WMA rule, no ML, no adaptive online parameters. |

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
- This declaration locks the exact NDX.DWX/D1 configuration used by Q08 (set file `QM5_10269_gawd-wma30-trend_NDX.DWX_D1_backtest.set`). It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_10269",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "10269",
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
    "strategy_timeframe": "16408",
    "strategy_wma_period": "30"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "8ed288af94e4cde2f4a281c7e73a97d35fbbffae81a61f17ab3bab5ffd289154",
  "symbol": "NDX.DWX",
  "timeframe": "D1"
}
```
