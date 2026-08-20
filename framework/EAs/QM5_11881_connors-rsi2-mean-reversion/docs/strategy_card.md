---
ea_id: QM5_11881
slug: connors-rsi2-mean-reversion
source_id: 2f18abf6-a4aa-5974-8299-aa2d8913fa7d
source_citation: "Connors, L. & Alvarez, C. (2009), Short Term Trading Strategies That Work — A Quantified Guide to Trading Stocks and ETFs. URL: local PDF archive."
title: "Connors 2-period RSI mean-reversion (D1, 200-SMA regime filter)"
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
expected_trades_per_year_per_symbol: 25
r1_track_record: PASS
r1_reasoning: "Single source_id (2f18abf6) with Connors & Alvarez 2009 book citation — one canonical lineage anchor."
r2_mechanical: PASS
r2_reasoning: "Fully mechanical: SMA(200) regime, RSI(2) threshold entry at next D1 open, RSI(2) exit level, ATR(14) SL, 10-bar time stop — no discretion."
r3_data_available: PASS
r3_reasoning: "FX majors and DWX index symbols available on D1; SP500.DWX backtest-only per criteria but R3 still PASS; equity-ETF source ports cleanly to forex/CFD D1 bars."
r4_ml_forbidden: PASS
r4_reasoning: "No ML; RSI and SMA are deterministic price-history indicators; parameters are fixed; 1-position-per-magic compatible."
status: cards_ready
strategy_params:
  rsi_period: 2
  rsi_long_entry: 10
  rsi_short_entry: 90
  rsi_exit_long: 65
  rsi_exit_short: 35
  regime_sma_period: 200
  sl_atr_mult: 2.0
  atr_period: 14
  max_holding_bars: 10
card_body_incomplete: true
card_body_missing: "source_citation,target_symbols"
g0_status: APPROVED
g0_approval_reasoning: "R1 PASS single source_id/source_citation; R2 PASS mechanical D1 RSI2 entries/exits with ~25/yr plausible; R3 PASS FX/index DWX symbols testable incl SP500 backtest-only caveat; R4 PASS deterministic ML-free 1-position compatible."
last_updated: 2026-05-24
---

## Strategy

Connors's signature short-term mean-reversion setup, traded on the **D1** timeframe.
The 200-day SMA acts as the regime filter: only long mean-reversion entries are
permitted while close > SMA(200), and only short entries while close < SMA(200).
Within each regime, the 2-period RSI identifies stretched conditions for entry.

Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX,
AUDUSD.DWX, NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, NDX.DWX, WS30.DWX,
SP500.DWX.

## Entry Rules

**Long (only when D1 close > SMA(200)):**
- Enter market at next D1 open when D1 close < D1 close[prev] and RSI(2) < 10.

**Short (only when D1 close < SMA(200)):**
- Enter market at next D1 open when D1 close > D1 close[prev] and RSI(2) > 90.

## Exit Rules

- Long exit: at D1 close when RSI(2) > 65, OR hit SL/TP.
- Short exit: at D1 close when RSI(2) < 35, OR hit SL/TP.
- Hard time-stop: 10 D1 bars maximum holding window.

## Risk and Sizing

- SL: 2 × ATR(14) from entry price.
- TP: dynamic via the RSI-cross exit (no fixed TP needed; RSI-mean-reversion
  is a short-duration thesis with average hold of 2-5 D1 bars).
- Backtest sizing: RISK_FIXED = $1000 per trade.
- Live sizing: RISK_PERCENT = 0.5% of equity per trade.

## Source Provenance

Source citation: Connors, L. & Alvarez, C. (2009), Short Term Trading Strategies
That Work — A Quantified Guide to Trading Stocks and ETFs. URL: local PDF
archive.

Derived from Connors & Alvarez (2009) "Short Term Trading Strategies That Work",
which presents this as the "2-Period RSI" rule (Rule slide pp17-18, restated
as Strategies 8-9 in the summary deck). Original backtests run by the authors
on US equities and ETFs 1995-2007. QuantMechanica adaptation: applies the same
signal to FX-major and DWX-index daily bars to test whether the mean-reversion
edge transfers across asset classes. Linked sister card: [[connors-double-7s]].
