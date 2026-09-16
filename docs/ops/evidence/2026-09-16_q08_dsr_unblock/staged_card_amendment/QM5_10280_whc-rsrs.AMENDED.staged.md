---
ea_id: QM5_10280
slug: whc-rsrs
type: strategy
source_id: 1b906e79-c619-5a61-90db-ee19ac95a19f
sources:
  - "[[sources/github-topic-algorithmic-trading]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/support-resistance]]"
indicators:
  - "[[indicators/rsrs]]"
  - "[[indicators/linear-regression]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present with verifiable GitHub strategy and indicator file URLs."
r2_mechanical: PASS
r2_reasoning: "Rolling OLS regression of High on Low over 20 bars yields a deterministic beta coefficient; fixed RSRS entry and exit thresholds."
r3_data_available: PASS
r3_reasoning: "OHLC-only calculation ports to DWX index, metal, and FX symbols; SP500.DWX backtest-only caveat noted."
r4_ml_forbidden: PASS
r4_reasoning: "RSRS is a fixed rolling regression coefficient, not ML training; fixed thresholds, no online adaptation, no martingale, one position per magic."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 12
last_updated: 2026-05-21
card_body_incomplete: true
card_body_missing: "source_citation,period"
g0_approval_reasoning: "R1 PASS verifiable GitHub strategy/indicator URLs; R2 PASS deterministic D1 RSRS high/low regression entry RSRS>0.8 exit RSRS<0.5 with ~12 trades/year/symbol; R3 PASS OHLC-only portable to DWX; R4 PASS fixed rules no ML/grid/martingale."
---

# Whchien RSRS Support Resistance Trend

## Source
- Source citation: 2026 GitHub URL https://github.com/whchien/ai-trader/blob/main/ai_trader/backtesting/strategies/classic/rsrs.py
- Source: [[sources/github-topic-algorithmic-trading]]
- Topic URL: https://github.com/topics/algorithmic-trading
- Repository: `whchien/ai-trader`, author/handle `whchien`
- Repo URL: https://github.com/whchien/ai-trader
- Strategy README: https://github.com/whchien/ai-trader/blob/main/ai_trader/backtesting/strategies/README.md
- Strategy file: https://github.com/whchien/ai-trader/blob/main/ai_trader/backtesting/strategies/classic/rsrs.py
- Indicator file: https://github.com/whchien/ai-trader/blob/main/ai_trader/backtesting/strategies/indicators.py
- Class: `RSRSStrategy`, indicator `RSRS`

## Mechanics

### Entry
- Period: D1 daily bars for initial port.
- Over the last 20 bars, run linear regression `High = alpha + beta * Low`.
- Define `RSRS = beta`.
- Open long when flat and `RSRS > 0.8`.

### Exit
- Close long when `RSRS < 0.5`.

### Stop Loss
- Source has no explicit stop. V5 build should add default catastrophic `2.0 * ATR(14)` stop.

### Position Sizing
- Source is long-only. V5 baseline uses fixed $1,000 risk and one position per magic.

### Additional filters
- Source references RSRS as a trend-strength/support-resistance slope signal and does not require volume or market breadth.
- Port to DWX daily OHLC symbols. `NDX.DWX`, `WS30.DWX`, `SP500.DWX` backtest-only, `XAUUSD.DWX`, and major FX are valid candidates. If `SP500.DWX` is the only passing substrate, live promotion requires parallel validation on `NDX.DWX` or `WS30.DWX`.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/support-resistance]] - high/low regression slope

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|-------------|
| R1 Track Record | PASS | Verifiable GitHub topic URL plus `whchien/ai-trader` RSRS strategy and indicator file URLs. |
| R2 Mechanical | PASS | Entry/exit thresholds are fixed; RSRS calculation is deterministic OLS on recent high/low bars. |
| R3 Data Available | PASS | Requires only OHLC bars and ports to DWX index, metal, and FX symbols; SP500.DWX caveat applies if used. |
| R4 ML Forbidden | PASS | Linear regression is a fixed indicator calculation, not prediction training or online adaptation; no ML, grid, or martingale. |

## Pipeline history
- G0: 2026-05-21, PENDING, drafted from GitHub topic catalog Batch 5.

## Related strategies
- [[strategies/QM5_10279_whc-roc-ma]] - trend confirmation via momentum and moving averages rather than high/low regression slope.

## Lessons Learned
- TBD

## Approved Amendment (2026-09-14) — DSR Single Configuration

- Authority: `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`, OWNER receipt `3415f6c0…` (YES: "ABC & D freigegeben zur Umsetzung").
- This EA was never part of a sealed factory search (no DL-089 ledger); it carries exactly one configuration: the card defaults overlaid by the set file below. No optimisation search took place, research_trial_count is 0.
- This declaration locks the exact NDX.DWX/D1 configuration used by Q08 (set file `QM5_10280_whc-rsrs_NDX.DWX_D1_backtest.set`). It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_10280",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "10280",
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
    "strategy_atr_sl_mult": "2.00",
    "strategy_entry_threshold": "0.80",
    "strategy_exit_threshold": "0.50",
    "strategy_rsrs_period": "20",
    "strategy_signal_tf": "PERIOD_D1"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "6d9f9bbddf4a02b7351c7a67006631bfbff644235ca97c5f896d34c33252a07f",
  "symbol": "NDX.DWX",
  "timeframe": "D1"
}
```
