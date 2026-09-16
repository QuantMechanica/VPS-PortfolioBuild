---
ea_id: QM5_10287
slug: cinar-ichimoku
type: strategy
source_id: 1b906e79-c619-5a61-90db-ee19ac95a19f
sources:
  - "[[sources/github-topic-algorithmic-trading]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/momentum]]"
  - "[[concepts/ichimoku-cloud]]"
indicators:
  - "[[indicators/ichimoku]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: Single source_id present; public cinar/indicator GitHub repo with exact strategy and indicator file URLs is verifiable.
r2_mechanical: PASS
r2_reasoning: Ichimoku periods 9/26/52 and all four long/short entry conditions with opposite-signal exit are fully specified in source code.
r3_data_available: PASS
r3_reasoning: Uses OHLC-derived cloud lines on D1; directly portable to DWX FX, metals, and index CFDs.
r4_ml_forbidden: PASS
r4_reasoning: Fixed periods only; no ML, adaptive parameters, grid, or martingale.
pipeline_phase: G0
expected_trades_per_year_per_symbol: 12
last_updated: 2026-05-21
card_body_incomplete: true
card_body_missing: "source_citation,period"
g0_approval_reasoning: "R1 source URLs present; R2 mechanical Ichimoku entry/opposite-signal exit with ~12 trades/year/symbol; R3 OHLC-derived rules portable to DWX CFDs; R4 fixed-parameter non-ML one-position logic."
---

# Cinar Ichimoku Cloud Trend

## Source
- Source: [[sources/github-topic-algorithmic-trading]]
- 2026 Topic URL: https://github.com/topics/algorithmic-trading
- Repository: `cinar/indicator`, author/handle `cinar` / Onur Cinar
- Repo URL: https://github.com/cinar/indicator
- Strategy file: https://github.com/cinar/indicator/blob/master/strategy/momentum/ichimoku_cloud_strategy.go
- Indicator file: https://github.com/cinar/indicator/blob/master/momentum/ichimoku_cloud.go

## Mechanics

### Entry
- Timeframe: D1 daily bars for first V5 port.
- Compute Ichimoku Cloud with source defaults:
  - Conversion/Tenkan period 9.
  - Base/Kijun period 26.
  - Leading Span B period 52.
  - Lagging period 26. The strategy code drains lagging line and does not use it in entry/exit logic.
- Open long when all conditions hold:
  - `Close > LeadingSpanA`.
  - `Close > LeadingSpanB`.
  - `ConversionLine > BaseLine`.
  - `LeadingSpanA > LeadingSpanB`.
- Open short when all conditions hold:
  - `Close < LeadingSpanA`.
  - `Close < LeadingSpanB`.
  - `ConversionLine < BaseLine`.
  - `LeadingSpanA < LeadingSpanB`.

### Exit
- Stop-and-reverse by opposite source signal:
  - Close long when the short condition appears.
  - Close short when the long condition appears.
- If neither side has full confirmation, hold the current position unless V5 catastrophic stop is hit.

### Stop Loss
- Source has no explicit hard stop. V5 build should add default catastrophic `2.0 * ATR(14)` stop.

### Position Sizing
- One net position at a time. V5 implementation should enforce one position per magic and no pyramiding.

### Additional filters
- Port to DWX trend instruments: XAUUSD.DWX, NDX.DWX, WS30.DWX, DAX.DWX, GBPJPY.DWX, and major FX crosses.
- If only `SP500.DWX` passes, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Concepts
- [[concepts/trend-following]] - price must be outside the cloud.
- [[concepts/momentum]] - conversion/base alignment confirms direction.
- [[concepts/ichimoku-cloud]] - cloud polarity filters entries.

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|-------------|
| R1 Track Record | PASS | Verifiable GitHub topic URL plus public `cinar/indicator` repo, author handle, and exact strategy/indicator file URLs. |
| R2 Mechanical | PASS | Cloud periods and long/short conditions are explicit in source code. |
| R3 Data Available | PASS | Uses OHLC-derived daily indicator values and ports to DWX FX, metals, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed periods and thresholds; no ML, adaptive parameters, grid, or martingale. |

## Pipeline history
- G0: 2026-05-21, PENDING, drafted from GitHub topic catalog Batch 7.

## Related strategies
- [[strategies/QM5_10284_kernc-mtf-rsi]] - multi-condition long momentum filter.

## Lessons Learned
- TBD

## Approved Amendment (2026-09-14) — DSR Single Configuration

- Authority: `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`, OWNER receipt `3415f6c0…` (YES: "ABC & D freigegeben zur Umsetzung").
- This EA was never part of a sealed factory search (no DL-089 ledger); it carries exactly one configuration: the card defaults overlaid by the set file below. No optimisation search took place, research_trial_count is 0.
- This declaration locks the exact NDX.DWX/D1 configuration used by Q08 (set file `QM5_10287_cinar-ichimoku_NDX.DWX_D1_backtest.set`). It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_10287",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "10287",
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
    "strategy_kijun_period": "26",
    "strategy_senkou_b_period": "52",
    "strategy_signal_shift": "1",
    "strategy_tenkan_period": "9"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "ab3c15b3d7e8195a594dd0a5ddbd937236d91e34495d5fbf9e0e969c35b26cfd",
  "symbol": "NDX.DWX",
  "timeframe": "D1"
}
```
