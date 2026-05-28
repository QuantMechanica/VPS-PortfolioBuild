---
ea_id: QM5_1155
slug: unger-nasdaq-atr-spike-short
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
sources:
  - "[[sources/unger-robbins-cup]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/downside-momentum]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/candlestick-range]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 PASS official Unger URL and book ISBN; R2 PASS mechanical M5 downside body/ATR spike short with fixed exits/stops; R3 PASS NDX.DWX/WS30.DWX testable with SP500.DWX T6 caveat; R4 PASS fixed rules no ML/grid/martingale."
expected_trades_per_year_per_symbol: 12
---

# Unger Nasdaq ATR Spike Short - Downside Volatility Momentum

## Quelle
- Source: [[sources/unger-robbins-cup]] - Unger Academy May 2025 Strategy of the Month article.
- Article: "Strategy of the Month (May 2025): A Trend Following System on Platinum Futures Wins" - external source URL removed in local EA copy for build-check compliance.
- Location: "Trend Following Strategy on the Nasdaq (NQ)" section; source describes a Nasdaq 5-minute short-only trend-following system that enters after strong downward spikes, uses ATR to identify increased volatility, and requires the candlestick size to exceed previous bars.
- Supporting source: The Unger Method - Andrea Unger's Trading Method, Unger Academy Publishing, 2nd ed. 2021, ISBN 978-8896590164.

## Mechanik

Universe: NDX.DWX primary, optional WS30.DWX and SP500.DWX backtest-only robustness ports. Execution timeframe M5.

### Entry
1. Compute `ATR14 = ATR(14,M5)`.
2. Compute current bar real body: `BODY = abs(close - open)`.
3. Compute `AVG_BODY20 = average(abs(close - open), 20 completed M5 bars)`.
4. Short setup requires:
   - current completed M5 bar closes below its open,
   - `BODY > BODY_MULT * AVG_BODY20`, default `BODY_MULT = 1.8`,
   - `BODY > ATR_MULT * ATR14`, default `ATR_MULT = 0.8`,
   - close is below the low of the prior completed M5 bar.
5. Enter short at market on the signal bar close, inside the US cash-session entry window.
6. Short-only first build.

### Exit
- Close on stop loss or take profit.
- Flatten at the US index session close.
- Optional momentum exit: close if an M5 bar closes above EMA(20,M5).

### Stop Loss
- `SL = 1.5 * ATR(14,M5)`.
- `TP = 2.5 * ATR(14,M5)`.
- P3 sweep body multiplier, ATR multiplier, and EMA exit.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25%`.

### Zusaetzliche Filter
- Trade only during 09:45-15:15 New York time.
- Skip if D1 ATR percentile is below the 30th percentile of the last 252 sessions.
- Standard V5 spread/news filters.
- One position per magic.

## R3
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.
