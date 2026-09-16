---
ea_id: QM5_11882
slug: connors-double-7s
source_id: 2f18abf6-a4aa-5974-8299-aa2d8913fa7d
source_citation: "Connors, L. & Alvarez, C. (2009), Short Term Trading Strategies That Work — A Quantified Guide to Trading Stocks and ETFs. URL: local PDF archive."
title: "Connors Double 7's (D1, close-at-7-day-extreme mean-reversion)"
edge_type: mean-reversion
period: D1
target_symbols:
  - EURUSD.DWX
  - GBPUSD.DWX
  - USDJPY.DWX
  - USDCAD.DWX
  - USDCHF.DWX
  - AUDUSD.DWX
  - NZDUSD.DWX
  - EURJPY.DWX
  - GBPJPY.DWX
  - NDX.DWX
  - WS30.DWX
  - SP500.DWX
risk_mode_backtest: RISK_FIXED
risk_fixed: 1000
risk_mode_live: RISK_PERCENT
risk_percent: 0.5
expected_trades_per_year_per_symbol: 18
r1_track_record: PASS
r1_reasoning: "Single source_id (2f18abf6) with Connors & Alvarez 2009 book citation — one canonical lineage anchor per card."
r2_mechanical: PASS
r2_reasoning: "Fully mechanical: SMA(200) regime, close = rolling-7-day MIN/MAX entry at next open, opposite 7-day extreme exit, ATR(14) SL, 14-bar time stop."
r3_data_available: PASS
r3_reasoning: "FX majors and DWX index symbols (SP500.DWX backtest-only) all available on D1."
r4_ml_forbidden: PASS
r4_reasoning: "No ML; rolling min/max and SMA are deterministic price-history computations; 1-position-per-magic compatible."
status: cards_ready
strategy_params:
  lookback: 7
  regime_sma_period: 200
  sl_atr_mult: 2.0
  atr_period: 14
  max_holding_bars: 14
card_body_incomplete: true
card_body_missing: "source_citation,target_symbols"
g0_status: APPROVED
g0_approval_reasoning: "R1 PASS single source_id/source_citation; R2 PASS mechanical D1 7-day-extreme entries/exits with ~18/yr plausible; R3 PASS FX/index DWX symbols testable incl SP500 backtest-only caveat; R4 PASS deterministic ML-free 1-position compatible."
last_updated: 2026-05-24
---

## Strategy

The Connors "Double 7's" strategy, traded on the **D1** timeframe. The setup
asks two questions per side: (a) what regime are we in, judged by the 200-day
SMA, and (b) is today's close a fresh 7-day low (long) or 7-day high (short).
Exits mirror the entry condition on the opposite extreme.

Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX,
AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, NDX.DWX, WS30.DWX,
SP500.DWX.

## Entry Rules

**Long (only when D1 close > SMA(200)):**
- Enter market at next D1 open when today's D1 close = lowest D1 close of the
  last 7 sessions (close == MIN(close, 7)).

**Short (only when D1 close < SMA(200)):**
- Enter market at next D1 open when today's D1 close = highest D1 close of the
  last 7 sessions (close == MAX(close, 7)).

## Exit Rules

- Long exit: at D1 close when D1 close = highest D1 close of last 7 sessions, or
  SL/time-stop.
- Short exit: at D1 close when D1 close = lowest D1 close of last 7 sessions, or
  SL/time-stop.
- Hard time-stop: 14 D1 bars maximum holding window.

## Risk and Sizing

- SL: 2 × ATR(14) from entry price.
- TP: dynamic via the 7-day-extreme exit (no fixed TP).
- Backtest sizing: RISK_FIXED = $1000 per trade.
- Live sizing: RISK_PERCENT = 0.5% of equity per trade.

## Source Provenance

Source citation: Connors, L. & Alvarez, C. (2009), Short Term Trading Strategies
That Work — A Quantified Guide to Trading Stocks and ETFs. URL: local PDF
archive.

Derived from Connors & Alvarez (2009) "Short Term Trading Strategies That Work",
Double 7's chapter (deck slides p19, restated as Strategy 11). Original Connors
backtest universe was SPY / world-index ETFs 1995-2007. QuantMechanica adaptation
applies the same close-relative-to-7-day-extreme signal to FX-major and DWX-index
D1 bars. Linked sister card: [[connors-rsi2-mean-reversion]].

## Approved Amendment (2026-09-14) — DSR Single Configuration

- Authority: `OWNER-DEC-Q08-CONTEXT-REPAIR-V2-20260914`, OWNER receipt `3415f6c0…` (YES: "ABC & D freigegeben zur Umsetzung").
- This EA was never part of a sealed factory search (no DL-089 ledger); it carries exactly one configuration: the card defaults overlaid by the set file below. No optimisation search took place, research_trial_count is 0.
- This declaration locks the exact NDX.DWX/D1 configuration used by Q08 (set file `QM5_11882_connors-double-7s_NDX.DWX_D1_backtest.set`). It changes no strategy mechanics, threshold, or stored verdict.

```qm-dsr-single-configuration
{
  "complete": true,
  "ea_id": "QM5_11882",
  "locked_parameters": {
    "InpQMSimCommissionPerLot": "0.0",
    "PORTFOLIO_WEIGHT": "1",
    "RISK_FIXED": "1000",
    "RISK_PERCENT": "0",
    "qm_ea_id": "11882",
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
    "qm_friday_close_enabled": "1",
    "qm_friday_close_hour_broker": "21",
    "qm_magic_slot_offset": "9",
    "qm_news_compliance": "0",
    "qm_news_min_impact": "high",
    "qm_news_mode_legacy": "0",
    "qm_news_stale_max_hours": "336",
    "qm_news_temporal": "0",
    "qm_rng_seed": "42",
    "qm_stress_reject_probability": "0.0",
    "strategy_atr_period": "14",
    "strategy_lookback": "7",
    "strategy_max_holding_bars": "14",
    "strategy_regime_sma_period": "200",
    "strategy_sl_atr_mult": "2.0"
  },
  "no_optimization_search": true,
  "research_trial_count": 0,
  "schema": "qm.dsr-single-configuration-declaration/v1",
  "spec_sha256": "b32bb1e4baca58c55deae3a25392554893199812af0010c9af1df3dabf54d928",
  "symbol": "NDX.DWX",
  "timeframe": "D1"
}
```
