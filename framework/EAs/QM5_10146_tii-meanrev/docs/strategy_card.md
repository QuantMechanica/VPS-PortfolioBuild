---
ea_id: QM5_10146
slug: tii-meanrev
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-trade-python-backtesting]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/oscillator-threshold]]"
indicators:
  - "[[indicators/trend-intensity-index]]"
  - "[[indicators/simple-moving-average]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 12
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL present; R2 fixed TII threshold entry/centerline exit with ~12 trades/year/symbol; R3 OHLC-close rule portable to DWX CFDs/SP500.DWX caveat; R4 fixed-parameter non-ML single-position logic."
---

# TII Extreme Mean Reversion

## Quelle
- Source: [[sources/raposa-trade-python-backtesting]]
- Primary URL: https://raposa.trade/blog/4-ways-to-trade-the-trend-intensity-indicator/
- Author / institution: Raposa / Raposa Technologies
- Date: Aug. 26, 2021
- Page / Timestamp: "Buy Low and Sell High" section

## Mechanik

### Entry
- Calculate `SMA_P = SMA(Close, P)`.
- Calculate `TII = 200 * rolling_count(Close > SMA_P, P/2) / P`.
- Source default: `P = 60`.
- Enter long when `TII <= enter_long`; source default `enter_long = 20`.
- Optional short mode: enter short when `TII >= enter_short`; source default `enter_short = 80`.
- Evaluate on closed bars and execute on the next bar/open.

### Exit
- Exit long when `TII` crosses the exit centerline; source default `exit_long = 50`.
- Exit short when `TII` crosses the exit centerline; source default `exit_short = 50`.
- If opposite-side entries are enabled, reverse only after the current position exits or on a confirmed opposite signal.

### Stop Loss
- Source does not define a hard stop.
- Research default for build: fixed emergency stop at `3 * ATR(14)` with V5 fixed-risk sizing; refine in P3.

### Position Sizing
- Source examples use full-position vector backtests, not MT5 lot sizing.
- Use V5 baseline sizing: fixed $1,000 risk for P2, live 0.25% risk after approval.

### Zusaetzliche Filter
- Require at least `P` completed bars before trading.
- Skip if spread exceeds symbol default.
- Daily bars are closest to the source examples; H4 may be tested as a cadence extension.

## Concepts
- [[concepts/mean-reversion]] - primary
- [[concepts/oscillator-threshold]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Verifiable Raposa.Trade article URL with author/publisher and date. |
| R2 Mechanical | PASS | Entry and exit are explicit fixed thresholds on a computed indicator. |
| R3 Data Available | PASS | Uses OHLC close data only; portable to FX, metals, oil, indices, and SP500.DWX backtest-only. |
| R4 ML Forbidden | PASS | Fixed-parameter oscillator rule; no ML, no adaptive parameters, no martingale/grid. |

## R3
The GDX equity/ETF example ports to Darwinex CFDs by applying the same closed-bar TII rule to each symbol independently. For SP500.DWX backtest-only use: Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says the model buys low TII readings and sells/shorts high TII readings, then waits for reversion toward the centerline.
- Source reports the mean-reversion model improved returns versus buy-and-hold on its example, but with weak risk-adjusted metrics.

## Parameters To Test
- `P`: 30, 45, 60, 90
- `enter_long`: 10, 20, 30
- `enter_short`: 70, 80, 90
- `exit_centerline`: 45, 50, 55
- `shorts_enabled`: true/false
- `atr_stop_mult`: 2.0, 3.0, 4.0

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, Research draft from Raposa mechanical tutorial.

## Verwandte Strategien
- [[strategies/QM5_10141_rsi-meanrev]] - RSI threshold mean reversion.
- [[strategies/QM5_10127_bb-meanrev]] - Bollinger Band mean reversion.

## Lessons Learned
- TBD

