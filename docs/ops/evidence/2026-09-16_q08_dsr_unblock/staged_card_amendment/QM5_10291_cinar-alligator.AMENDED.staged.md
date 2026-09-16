---
ea_id: QM5_10291
slug: cinar-alligator
type: strategy
source_id: 1b906e79-c619-5a61-90db-ee19ac95a19f
sources:
  - "[[sources/github-topic-algorithmic-trading]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/moving-average-stack]]"
  - "[[concepts/stop-and-reverse]]"
indicators:
  - "[[indicators/alligator]]"
  - "[[indicators/smma]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; public cinar/indicator GitHub repo with exact strategy and indicator file URLs is verifiable.
r2_mechanical: PASS
r2_reasoning: SMMA periods 5/8/13 and Lip-Teeth-Jaw stack conditions for entry and stop-and-reverse exit are deterministic in source code.
r3_data_available: PASS
r3_reasoning: Uses close-derived SMMAs on D1; portable to any DWX FX, metals, or index CFD.
r4_ml_forbidden: PASS
r4_reasoning: Fixed periods only; no ML, adaptive parameters, grid, or martingale.
pipeline_phase: G0
expected_trades_per_year_per_symbol: 20
last_updated: 2026-05-21
card_body_incomplete: true
card_body_missing: "source_citation,period"
g0_approval_reasoning: "R1 source URLs present; R2 deterministic SMMA stack stop-and-reverse with ~20 trades/year/symbol; R3 OHLC/close rules portable to DWX CFDs; R4 fixed-rule ML-free one-position design."
---

# Cinar Alligator SMMA Trend

## Source
- Source: [[sources/github-topic-algorithmic-trading]]
- Topic URL: https://github.com/topics/algorithmic-trading
- Repository: `cinar/indicator`, author/handle `cinar` / Onur Cinar
- Source citation: 2026 URL, public `cinar/indicator` repository and exact strategy file below.
- Repo URL: https://github.com/cinar/indicator
- Strategy file: https://github.com/cinar/indicator/blob/master/strategy/trend/alligator_strategy.go
- Indicator file: https://github.com/cinar/indicator/blob/master/trend/smma.go

## Mechanics

### Entry
- Timeframe: D1 daily bars for first V5 port.
- Compute three SMMAs from close using source defaults:
  - Jaw = SMMA(13).
  - Teeth = SMMA(8).
  - Lip = SMMA(5).
- Open long when `Lip > Teeth` and `Lip > Jaw`.
- Open short when `Lip < Teeth` and `Lip < Jaw`.
- Hold when the Lip is between the slower averages.

### Exit
- Stop-and-reverse:
  - Close long and open short when `Lip < Teeth` and `Lip < Jaw`.
  - Close short and open long when `Lip > Teeth` and `Lip > Jaw`.
- If the averages move into a mixed stack, keep the existing position until an opposite source action occurs.

### Stop Loss
- Source has no explicit hard stop. V5 build should add default catastrophic `2.0 * ATR(14)` stop.

### Position Sizing
- One net position at a time. V5 implementation should enforce one position per magic and no pyramiding.

### Additional filters
- Port to DWX trend instruments: XAUUSD.DWX, NDX.DWX, WS30.DWX, DAX.DWX, GBPJPY.DWX, and major FX crosses.
- If only `SP500.DWX` passes, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Concepts
- [[concepts/trend-following]] - fast smoothed average outside slower averages.
- [[concepts/moving-average-stack]] - SMMA stack defines directional bias.
- [[concepts/stop-and-reverse]] - opposite stack exits and reverses.

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|-------------|
| R1 Track Record | PASS | Verifiable GitHub topic URL plus public `cinar/indicator` repo, author handle, and exact strategy/indicator file URLs. |
| R2 Mechanical | PASS | SMMA periods and buy/sell stack conditions are deterministic in source code. |
| R3 Data Available | PASS | Uses close-derived moving averages and ports directly to DWX FX, metals, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed periods only; no ML, adaptive parameters, grid, or martingale. |

## Pipeline history
- G0: 2026-05-21, PENDING, drafted from GitHub topic catalog Batch 8.

## Related strategies
- [[strategies/QM5_10287_cinar-ichimoku]] - multi-line trend confirmation family.
- [[strategies/QM5_10285_kernc-sma-x]] - moving-average stop-and-reverse family.

## Lessons Learned
- TBD

## Approved Amendment (2026-09-14) — DSR Single Configuration

- Authority: `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`, OWNER receipt `3415f6c0…` (YES: "ABC & D freigegeben zur Umsetzung").
- This EA was never part of a sealed factory search (no DL-089 ledger); it carries exactly one configuration: the card defaults overlaid by the set file below. No optimisation search took place, research_trial_count is 0.
- This declaration locks the exact NDX.DWX/D1 configuration used by Q08 (set file `QM5_10291_cinar-alligator_NDX.DWX_D1_backtest.set`). It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_10291",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "10291",
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
    "qm_magic_slot_offset": "22",
    "qm_news_compliance": "QM_NEWS_COMPLIANCE_DXZ",
    "qm_news_min_impact": "high",
    "qm_news_mode_legacy": "QM_NEWS_OFF",
    "qm_news_stale_max_hours": "336",
    "qm_news_temporal": "QM_NEWS_TEMPORAL_PRE30_POST30",
    "qm_rng_seed": "42",
    "qm_stress_reject_probability": "0.0",
    "strategy_atr_period": "14",
    "strategy_atr_sl_mult": "2.0",
    "strategy_jaw_period": "13",
    "strategy_lip_period": "5",
    "strategy_teeth_period": "8"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "bbcbe8c825bb84fa840d2efc5ea6f72fc76ee35555c9a05889ed70f43c42a7e6",
  "symbol": "NDX.DWX",
  "timeframe": "D1"
}
```
