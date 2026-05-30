---
ea_id: QM5_10148
slug: tii-signal
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-trade-python-backtesting]]"
concepts:
  - "[[concepts/signal-line-cross]]"
  - "[[concepts/momentum]]"
indicators:
  - "[[indicators/trend-intensity-index]]"
  - "[[indicators/exponential-moving-average]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 18
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL present; R2 fixed TII-vs-EMA signal crossover entry/exit with ~18 trades/year/symbol; R3 OHLC-close rule portable to DWX CFDs/SP500.DWX caveat; R4 fixed-parameter non-ML single-position logic."
---

# TII EMA Signal-Line Crossover

## Quelle
- Source: [[sources/raposa-trade-python-backtesting]]
- Primary URL: https://raposa.trade/blog/4-ways-to-trade-the-trend-intensity-indicator/
- Author / institution: Raposa / Raposa Technologies
- Date: Aug. 26, 2021
- Page / Timestamp: "Adding a Signal Line" section

## Mechanik

### Entry
- Calculate `TII` from `SMA(Close, P)`; source default `P = 60`.
- Calculate `SignalLine = EMA(TII, N)`; source default `N = 9`.
- Enter long when `TII >= SignalLine`.
- Optional short mode: enter short when `TII < SignalLine`.
- Evaluate on closed bars and execute on the next bar/open.

### Exit
- Exit long when `TII < SignalLine`.
- Exit short when `TII >= SignalLine`.
- If short mode is enabled, reverse on the opposite crossover; otherwise go flat.

### Stop Loss
- Source does not define a hard stop.
- Research default for build: fixed emergency stop at `3 * ATR(14)` with V5 fixed-risk sizing; refine in P3.

### Position Sizing
- Source examples use full-position vector backtests.
- Use V5 baseline sizing: fixed $1,000 risk for P2, live 0.25% risk after approval.

### Zusaetzliche Filter
- Require enough bars for both `TII(P)` and `EMA(TII, N)`.
- Closed-bar crossover confirmation only.
- Skip if spread exceeds symbol default.

## Concepts
- [[concepts/signal-line-cross]] - primary
- [[concepts/momentum]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Verifiable Raposa.Trade article URL with author/publisher and date. |
| R2 Mechanical | PASS | Entry and exit are explicit TII-versus-EMA signal-line comparisons. |
| R3 Data Available | PASS | Uses OHLC close-derived indicators only; portable to Darwinex CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator parameters; no ML, adaptive params, grid, or martingale. |

## R3
The equity/ETF example ports to DWX CFDs by applying the same closed-bar signal-line crossover rule to each symbol. For SP500.DWX backtest-only use: Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source describes the TII signal line as the EMA of TII and tests buying when TII crosses above it.
- Source reports volatile performance and poor risk-adjusted metrics in the example.

## Parameters To Test
- `P`: 30, 45, 60, 90
- `signal_ema`: 5, 9, 13, 21
- `shorts_enabled`: true/false
- `atr_stop_mult`: 2.0, 3.0, 4.0
- `timeframe`: D1, H4

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, Research draft from Raposa mechanical tutorial.

## Verwandte Strategien
- [[strategies/QM5_10147_tii-momentum]] - centerline TII momentum.
- [[strategies/QM5_10143_rsi-momentum]] - RSI momentum threshold variant.

## Lessons Learned
- TBD

