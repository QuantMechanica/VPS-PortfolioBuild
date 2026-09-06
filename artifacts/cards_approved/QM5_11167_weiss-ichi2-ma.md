---
ea_id: QM5_11167
slug: weiss-ichi2-ma
type: strategy
source_id: 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
source_citation: "Richard L. Weissman, Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis, Wiley, 2005, Chapter 3, pp. 52-53, https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems"
sources:
  - "[[sources/weissman-mechanical-trading-systems]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/moving-average-crossover]]"
indicators: [SMA]
target_symbols: [EURUSD.DWX, USDJPY.DWX, XAUUSD.DWX, SP500.DWX, XTIUSD.DWX]
period: D1
expected_trade_frequency: "Daily 9/26 SMA crossover with 26-day SMA slope confirmation; Weissman reports 67-124 trades per asset over 10 years, so use 10 trades/year/symbol conservatively."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-09-06
g0_approval_reasoning: "OWNER receipt 5bf3bf5e-e3a9-40f8-8346-d2df9ca9b1e2: Q14 sweep proposal is not executed research; single XAUUSD configuration locked for DSR n=1."
---

# Weissman Ichimoku Two Moving Average Crossover

## Source
- Source: [[sources/weissman-mechanical-trading-systems]]
- Citation: Richard L. Weissman, *Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis*, Wiley, 2005, Chapter 3, "Ichimoku Two Moving Average Crossover", pp. 52-53. Web text: https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems.
- Author: Richard L. Weissman.
- Source location: Chapter 3 defines a 9/26 SMA crossover with the 26-day average required to slope in the entry direction before reversing.

## Mechanics

### Entry
- Evaluate on completed D1 bar.
- Long:
  - `SMA(9)[1] > SMA(26)[1]`.
  - `SMA(26)[1] > SMA(26)[2]`.
  - Close any short and enter long.
- Short:
  - `SMA(26)[1] < SMA(9)[1]`.
  - `SMA(26)[1] < SMA(26)[2]`.
  - Close any long and enter short.

### Exit
- Stop-and-reverse on the opposite entry condition.
- No profit target in source.
- P2 safety: Friday close and V5 max-hold controls only; no adaptive exits.

### Stop Loss
- Source system is stop-and-reverse without a fixed stop.
- V5 build fallback: protective catastrophic stop at `max(3 * ATR(20,D1), broker minimum)`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Additional filters
- One active position per symbol/magic.
- Use completed-bar signals only.
- Optional P3 sweep: fast SMA 8-12, slow SMA 24-30.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/moving-average-crossover]] - secondary

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author/book plus web text URL and chapter/page location. |
| R2 Mechanical | PASS | SMA periods, slope filter, directional entries, and reverse exits are explicit. |
| R3 DWX-testbar | PASS | Uses only D1 OHLC-derived moving averages on DWX FX, metals, oil, and index symbols. |
| R4 No ML | PASS | Fixed parameters, no ML, no online adaptation, one position per magic. |

## R3
Primary P2 basket: EURUSD.DWX, USDJPY.DWX, XAUUSD.DWX, XTIUSD.DWX, SP500.DWX.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Framework Alignment
- Strategy_NoTrade: no new entry if same-symbol/magic position is open except reverse-close sequence; obey V5 calendar controls.
- Strategy_EntrySignal: completed-bar SMA(9)/SMA(26) alignment plus SMA(26) slope filter.
- Strategy_ManageOpenPosition: maintain until opposite entry condition; maintain protective catastrophic stop.
- Strategy_ExitSignal: opposite qualified signal closes/reverses.

## Pipeline history
- G0: 2026-05-23, PENDING.

## Related strategies
- QM5_11162_weiss-ma2-cross.

## Lessons Learned
- TBD during pipeline run.
+## Approved Amendment (2026-09-06) — DSR Single Configuration

- Authority: OWNER receipt `5bf3bf5e-e3a9-40f8-8346-d2df9ca9b1e2`, YES / Option A.
- The earlier optional P3 sweep is a **Q14 proposal**, not executed research. It contributes zero research trials unless a complete loser-inclusive ledger is declared.
- This declaration locks the exact XAUUSD.DWX/D1 configuration used by Q08. It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_11167",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "11167",
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
    "qm_magic_slot_offset": "2",
    "qm_news_compliance": "QM_NEWS_COMPLIANCE_DXZ",
    "qm_news_min_impact": "high",
    "qm_news_mode_legacy": "QM_NEWS_OFF",
    "qm_news_stale_max_hours": "336",
    "qm_news_temporal": "QM_NEWS_TEMPORAL_PRE30_POST30",
    "qm_rng_seed": "42",
    "qm_stress_reject_probability": "0.0",
    "strategy_atr_period": "20",
    "strategy_atr_sl_mult": "2.523967",
    "strategy_fast_sma_period": "8",
    "strategy_slow_sma_period": "29"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "df4b72137c45e7a6c2af1de7728a26ed90b5e525b5aea29435c021378b877aff",
  "symbol": "XAUUSD.DWX",
  "timeframe": "D1"
}
```
