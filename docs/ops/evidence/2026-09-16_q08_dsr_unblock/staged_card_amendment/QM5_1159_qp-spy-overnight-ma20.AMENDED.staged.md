---
ea_id: QM5_1159
slug: qp-spy-overnight-ma20
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/overnight-effect]]"
  - "[[concepts/equity-index-timing]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/moving-average]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id (7ede58dd) with Quantpedia URL and named author Daniela Hanicova."
r2_mechanical: PASS
r2_reasoning: "Deterministic close > SMA(20) overnight-long entry with mandatory next-open exit; no discretionary steps."
r3_data_available: PASS
r3_reasoning: "SP500.DWX backtest-only available on T1-T5; card notes T6 NDX/WS30 live-promotion caveat."
r4_ml_forbidden: PASS
r4_reasoning: "Price-only SMA rule; BMS sentiment input explicitly excluded; one position; no ML or martingale."
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 PASS Quantpedia URL/author cited; R2 PASS deterministic close>SMA20 overnight long with next-open exit; R3 PASS SP500.DWX backtest-only with execution-alignment check and T6 NDX/WS30 caveat; R4 PASS price-only fixed rules, one position, no ML/grid/martingale."
expected_trades_per_year_per_symbol: 500
---

# Quantpedia SPY Overnight MA20 Filter - SP500.DWX

## Source
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Market Sentiment and an Overnight Anomaly"
- 2026 access URL: https://quantpedia.com/market-sentiment-and-an-overnight-anomaly/
- Named source author: Daniela Hanicova, Quant Analyst, Quantpedia.
- Location: sections "An Overnight Anomaly" and the 20-day moving-average signal table.

## Mechanics

### Entry
On each completed SP500.DWX cash-session close:
1. Compute SMA(20) on SP500.DWX D1 closes.
2. If SP500.DWX close > SMA(20), open LONG SP500.DWX for the overnight session at the close or nearest broker-supported equivalent.
3. Do not use the Brain Market Sentiment input from the article; this V5 draft uses only the source's price-only SPY>MA signal to avoid ML/alternative-data dependency.
4. Do not add to an existing position.

### Exit
- Close the position at the next regular cash-session open or nearest broker-supported equivalent.
- If open execution cannot be represented reliably in MT5 data, P1 should test the conservative next-bar-open approximation and flag execution assumptions.

### Stop Loss
- Hard stop at 1.0x D1 ATR(20) from entry.
- Time stop at next cash-session open is mandatory.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Additional filters
- Require 40 valid D1 closes before first signal.
- Optional P3 variants: SMA length 10/20/50; VIX<MA overlay only if a versioned deterministic VIX CSV is approved.
- Explicitly forbidden in V5 baseline: BMS/news-sentiment input, NLP sentiment, web calls, or live alternative-data API calls.

## Concepts (what kind of strategy is this)
- [[concepts/overnight-effect]] - primary
- [[concepts/equity-index-timing]] - secondary
- [[concepts/trend-following]] - secondary

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia article URL is verifiable and names Daniela Hanicova / Quantpedia; related literature is listed in the article. |
| R2 Mechanical | UNKNOWN | Price-only close>SMA(20) overnight entry and next-open exit are deterministic. |
| R3 Data Available | UNKNOWN | Source uses SPY; SP500.DWX is available for T1-T5 backtest-only, but overnight open/close alignment needs verification. |
| R4 ML Forbidden | UNKNOWN | Draft deliberately excludes the Brain Market Sentiment input; no ML, adaptive parameters, grid, or martingale. |

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline history
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Related strategies
- [[strategies/QM5_1115_qp-lunch-sp500]] - intraday session timing from Quantpedia, not overnight.
- [[strategies/QM5_1140_qp-sp500-ma10-breakout]] - D1 MA breakout, not close-to-open overnight holding.

## Lessons Learned (waehrend Pipeline-Lauf)
- (none yet)

---

*Node maintenance: update `pipeline_phase` + `last_updated` on every pipeline-phase change. On FAIL: `pipeline_phase: DEAD` + a lessons-learned entry.*

## Approved Amendment (2026-09-14) — DSR Single Configuration

- Authority: `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`, OWNER receipt `3415f6c0…` (YES: "ABC & D freigegeben zur Umsetzung").
- This EA was never part of a sealed factory search (no DL-089 ledger); it carries exactly one configuration: the card defaults overlaid by the set file below. No optimisation search took place, research_trial_count is 0.
- This declaration locks the exact NDX.DWX/D1 configuration used by Q08 (set file `QM5_1159_qp-spy-overnight-ma20_NDX.DWX_D1_backtest.set`). It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_1159",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "1159",
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
    "strategy_atr_period": "20",
    "strategy_atr_stop_mult": "1.0",
    "strategy_min_d1_closes": "40",
    "strategy_sma_period": "20"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "e2753137bc21095c00c8b42b51fa3bfbbc43c083aa9ded8bd2248e2786e1ca60",
  "symbol": "NDX.DWX",
  "timeframe": "D1"
}
```
