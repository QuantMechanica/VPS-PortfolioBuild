---
ea_id: QM5_11900
slug: kobasfx-4ema-macd-sentiment-h1
source_id: b8f3c4d7-9e26-5a51-8d74-c3e6f9a5b1d4
source_citation: "Obaseki O.A., 'KobasFX Strategy' (self-published PDF, ~2009), contact fxextract@yahoo.com"
title: "KobasFX 4-EMA Stack Separation + 65-EMA Trend Filter + MACD Sentiment H1"
edge_type: ema_stack_with_trend_and_momentum_confirmation
period: H1
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX]
risk_mode_backtest: RISK_FIXED
risk_fixed: 1000
risk_mode_live: RISK_PERCENT
risk_percent: 0.5
expected_trades_per_year_per_symbol: 35
status: cards_ready
r1_verdict: FAIL
r1_note: "Anonymous retail-FX guide, no credentials. Indicator stack is conventional (EMA + MACD)."
r2_verdict: UNKNOWN
r3_verdict: UNKNOWN
r4_verdict: UNKNOWN
r1_track_record: PASS
r1_reasoning: "Single source_id with citation to Obaseki KobasFX PDF; one source per card is satisfied and author credentials are not required."
r2_mechanical: PASS
r2_reasoning: "Five deterministic conditions (EMA stack separation, price vs EMA65, EMA65 slope, MACD zero line, MACD signal in cloud) with defined entry, MACD-driven exits, fixed TP cap, and timeout are all mechanically implementable."
r3_data_available: PASS
r3_reasoning: "DWX forex majors are the target universe and are directly testable in the MT5 pipeline on H1."
r4_ml_forbidden: PASS
r4_reasoning: "Standard EMA and MACD indicators with deterministic rules, no ML or PnL-adaptive logic, 1-position-per-magic compatible."
strategy_params:
  timeframe: H1
  ema_fast_periods: [5, 10, 15]
  ema_slow_period: 65
  ema_slope_lookback_bars: 5
  macd_fast: 12
  macd_slow: 26
  macd_signal: 9
  ema_separation_min_atr_mult: 0.25
  exit_method: macd_signal_zero_cross_or_cloud_exit
g0_status: APPROVED
g0_approval_reasoning: "R1 PASS one source_id/source_citation; R2 PASS mechanical H1 EMA/MACD entries/exits with plausible >=2 and ~35 trades/year/symbol; R3 PASS forex DWX symbols; R4 PASS deterministic ML-free 1-pos compatible."
last_updated: 2026-05-25
---

# QM5_11900 — KobasFX 4-EMA Stack + 65-EMA Trend + MACD Sentiment (H1)

## Setup

Five-condition confluence system requiring the fast EMA triplet (5, 10,
15) to have separated into a clean directional stack, price to trade on
the trend-aligned side of the slow 65-EMA, the 65-EMA itself to be
sloped in the trend direction, the MACD signal line to be on the
trend-aligned side of the zero line, AND the MACD signal line to be
inside its histogram cloud — only when all five align does the trade
trigger. This is a high-restriction confluence design.

## Entry Rules

Detected on H1 closed bars, all 5 conditions simultaneous:

1. **Fast EMA stack separated (long)**: `EMA5[t] > EMA10[t] > EMA15[t]`
   AND the separation (EMA5 - EMA15) is at least 0.25 × ATR(14) at t.
   This enforces "distinctly split" (not bunched together).
2. **Price above slow EMA (long)**: `close[t] > EMA65[t]`.
3. **Slow EMA sloped up (long)**: `EMA65[t] > EMA65[t-5]` over the last
   5 H1 bars.
4. **MACD above zero (long)**: `MACD_signal[t] > 0`.
5. **MACD signal inside histogram cloud (long)**: the MACD signal line
   value at t is within the [min(MACD_histogram), max(MACD_histogram)]
   envelope over the last 5 bars — i.e., the signal line is sitting
   inside the cloud area rather than detached above it.
6. **Long entry**: market buy at open of bar t+1.
7. **Short rules**: mirror — EMA5 < EMA10 < EMA15 separated, price
   below EMA65, EMA65 sloped down, MACD signal below zero, MACD signal
   inside histogram cloud below zero.

## Exit Rules

- **Initial stop loss (long)**: below the most recent swing low (lowest
  low of the last 10 H1 bars) minus 2 pips. Mirror for shorts.
- **Exit signal (short-term)**: MACD signal line exits the histogram
  cloud against trade direction → close immediately on next H1 open.
- **Exit signal (position)**: MACD signal line crosses the zero line
  against trade direction → close immediately.
- **Fixed take profit cap**: 3.0 × initial pip-risk if neither MACD
  exit triggers.
- **Hard timeout**: close at H1 bar 240 (10 days).
- **Risk**: backtest RISK_FIXED `risk_fixed = 1000`; live RISK_PERCENT
  `risk_percent = 0.5`.

## Universe

target_symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX,
AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, AUDJPY.DWX

H1 forex majors — source uses GBPJPY Daily in chart examples; the rule
set is symbol-agnostic.

## Source

source_citation: Obaseki O.A., "KobasFX Strategy" self-published PDF
(~2009). The Liberty Reserve donation account referenced in the closing
section dates the document to pre-May 2013 (when Liberty Reserve was
shut down by US authorities). URL: local/self-published PDF; no independent
author credentials.
