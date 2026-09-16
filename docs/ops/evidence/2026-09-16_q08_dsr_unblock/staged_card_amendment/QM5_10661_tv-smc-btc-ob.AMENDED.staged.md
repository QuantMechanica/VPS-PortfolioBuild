---
ea_id: QM5_10661
slug: tv-smc-btc-ob
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "DOE_Trade, SMC Pro BTC - ICT Order Blocks & FVG [DOE], TradingView, published 2026-02-19, https://www.tradingview.com/script/QMvHkvdQ-SMC-Pro-BTC-ICT-Order-Blocks-FVG-DOE/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/smart-money-concepts]]"
  - "[[concepts/order-block]]"
  - "[[concepts/fair-value-gap]]"
indicators: []
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; exact TradingView URL and author handle DOE_Trade cited."
r2_mechanical: PASS
r2_reasoning: "HTF/MTF BOS/CHoCH, OB/FVG overlap, liquidity sweep, SL at OB ± buffer, and 2R TP are all mechanically specified with defaults."
r3_data_available: PASS
r3_reasoning: "OHLC-derived BOS/CHoCH/OB/FVG mechanics port directly to DWX CFDs; proposed basket (XAUUSD, GER40, NDX, EURUSD) requires no exchange-specific data."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed non-ML rules, pyramiding 0, closed-bar confirmation only, one position per magic."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 18
last_updated: 2026-05-22
g0_approval_reasoning: "R1 TradingView URL/author cited; R2 HTF/MTF BOS/CHoCH plus OB/FVG/sweep entries with RR/OB-buffer exits and ~18 trades/year/symbol; R3 OHLC rules portable to DWX XAU/index/FX CFDs; R4 fixed non-ML one-position-per-magic."
---

# TradingView SMC BTC Order Block FVG

## Source
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `SMC Pro BTC - ICT Order Blocks & FVG [DOE]`, author handle `DOE_Trade`, published 2026-02-19, https://www.tradingview.com/script/QMvHkvdQ-SMC-Pro-BTC-ICT-Order-Blocks-FVG-DOE/

## Mechanics

### Entry
Use H4/H1 structure on DWX index, gold, or FX CFDs. Source default was BTCUSDT 4H, ported for G0.

- Direction timeframe default: H4.
- Confirmation timeframe default: H1.
- Long setup:
  - H4 prints bullish BOS or CHoCH, setting bullish directional bias.
  - H1 confirms with bullish BOS or CHoCH.
  - identify the last bearish candle before the impulsive bullish move as the order block.
  - bullish FVG overlaps the order-block zone.
  - recent liquidity sweep below a prior swing low occurred inside the sweep-memory window.
  - optional Selective mode: current price is in discount zone of the HTF dealing range.
  - enter on the bar after all conditions are confirmed.
- Short setup mirrors long with bearish HTF/MTF structure, bearish OB/FVG overlap, sweep above prior swing high, and optional premium-zone filter.

### Exit
- Take profit at configured risk:reward distance; source default RR is 2.0.
- Close at stop beyond the order block plus buffer.
- Optional opposite confirmed HTF structure signal closes the position before TP/SL.

### Stop Loss
- Long stop below order-block low plus buffer.
- Short stop above order-block high plus buffer.
- Source default SL buffer is 0.3%.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic. Ignore source percent-of-equity sizing in pipeline baseline.

### Zusatzliche Filter
- Aggressive mode baseline omits premium/discount filter for trade count; Selective mode is a P3 axis.
- Use closed-bar, non-lookahead MTF values.
- Build must port crypto price/commission assumptions to DWX CFD spread/slippage.

## Concepts (what kind of strategy is this)
- [[concepts/smart-money-concepts]] - waits for structure, imbalance, order block, and liquidity confluence.
- [[concepts/liquidity-sweep]] - requires stops to be swept before entry.
- [[concepts/premium-discount-zone]] - optional stricter location filter.

## R1-R4 assessment
| Criterion | Status | Rationale |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `DOE_Trade` are cited. |
| R2 Mechanical | PASS | Source lists HTF bias, MTF confirmation, OB, FVG, sweep, optional premium/discount, SL, TP, and defaults. |
| R3 Data Available | UNKNOWN | OHLC-only mechanics port to DWX CFDs, but source was optimized for BTCUSDT and needs port validation. |
| R4 ML Forbidden | PASS | Source states pyramiding 0, confirmed bars, no lookahead, and no ML. |

## R3
Primary P2 basket: XAUUSD, GER40.DWX, NDX.DWX, EURUSD. Crypto venue data is not required for G0 because the rule mechanics port to CFDs.

## Pipeline history
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Related strategies
- QM5_10651 tv-koz-sweep
- QM5_10657 tv-fvg-retrace

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD

## Approved Amendment (2026-09-14) — DSR Single Configuration

- Authority: `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`, OWNER receipt `3415f6c0…` (YES: "ABC & D freigegeben zur Umsetzung").
- This EA was never part of a sealed factory search (no DL-089 ledger); it carries exactly one configuration: the card defaults overlaid by the set file below. No optimisation search took place, research_trial_count is 0.
- This declaration locks the exact GDAXI.DWX/H1 configuration used by Q08 (set file `QM5_10661_tv-smc-btc-ob_GDAXI.DWX_H1_backtest.set`). It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_10661",
  "locked_parameters": {
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "10661",
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
    "strategy_confirmation_tf": "PERIOD_H1",
    "strategy_direction_tf": "PERIOD_H4",
    "strategy_fvg_lookback": "24",
    "strategy_max_spread_points": "0",
    "strategy_ob_lookback": "24",
    "strategy_rr": "2.0",
    "strategy_selective_mode": "false",
    "strategy_sl_buffer_pct": "0.3",
    "strategy_structure_lookback": "48",
    "strategy_sweep_memory_bars": "12",
    "strategy_swing_strength": "2"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "aac3f0547022da2129c8a07d929f2c35a4935c7d95c86f509343e9fbfe3bca86",
  "symbol": "GDAXI.DWX",
  "timeframe": "H1"
}
```
