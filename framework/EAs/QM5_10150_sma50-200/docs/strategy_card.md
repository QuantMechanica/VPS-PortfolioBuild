---
ea_id: QM5_10150
slug: sma50-200
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-trade-python-backtesting]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/moving-average-crossover]]"
indicators:
  - "[[indicators/simple-moving-average]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 4
last_updated: 2026-05-19
g0_approval_reasoning: "R1 verifiable Raposa/Medium article URLs; R2 deterministic 50/200 SMA entry/exit with ~4 trades/year/symbol; R3 daily OHLC rule testable on DWX index CFDs with SP500 T6 caveat; R4 fixed-rule no ML/grid/martingale."
---

# SMA 50/200 Golden-Cross Trend Filter

## Quelle
- Source: [[sources/raposa-trade-python-backtesting]]
- Primary URL: https://raposa.trade/blog/how-to-backtest-your-first-trading-strategy-in-python/
- Accessible mirror used for rule extraction: https://medium.com/raposa-technologies/backtest-your-first-strategy-in-python-88f663aee95e
- Author / institution: Raposa.Trade / Raposa Technologies
- Date: Feb. 2/24, 2021 depending on Raposa/Medium mirror
- Page / Timestamp: "Cross of Gold" / `SMABacktest` section

## Mechanik

### Entry
- Calculate `SMA_fast = SMA(Close, 50)`.
- Calculate `SMA_slow = SMA(Close, 200)`.
- Long-only mode: enter long when `SMA_fast > SMA_slow`.
- Optional long/short mode from source: enter short when `SMA_fast <= SMA_slow`.
- Evaluate on closed daily bars and execute on the next bar/open.

### Exit
- Long-only mode: exit long when `SMA_fast <= SMA_slow`.
- Long/short mode: reverse from long to short when `SMA_fast <= SMA_slow`; reverse from short to long when `SMA_fast > SMA_slow`.

### Stop Loss
- Source explicitly notes no risk control in this basic strategy.
- Research default for build: fixed emergency stop at `3 * ATR(14)` with V5 fixed-risk sizing; P3 may test no-hard-stop versus ATR-stop behavior.

### Position Sizing
- Source vector backtest uses a full-position state, not MT5 lots.
- Use V5 baseline sizing: fixed $1,000 risk for P2, live 0.25% risk after approval.

### Zusaetzliche Filter
- Require at least 200 completed daily bars before trading.
- Skip if spread exceeds symbol default.
- Best initial DWX tests: SP500.DWX, NDX.DWX, WS30.DWX, GER40.DWX, XAUUSD.DWX; FX majors optional but lower expected trend persistence.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/moving-average-crossover]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | Verifiable Raposa/Medium article URL with named Raposa.Trade publisher and date. |
| R2 Mechanical | PASS | Entry and exit are exact 50/200 SMA state rules, with optional short mode. |
| R3 Data Available | PASS | Uses daily OHLC close data; directly testable on index CFDs and portable to FX/commodity CFDs. |
| R4 ML Forbidden | PASS | Fixed moving-average crossover; no ML, adaptive parameter update, grid, or martingale. |

## R3
The source tests equities/SPY; the closest DWX analog is SP500.DWX for backtest-only index behavior plus live-routable NDX.DWX/WS30.DWX/GER40.DWX cross-checks. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source presents the 50/200 moving-average relationship as a basic systematic trading rule.
- Source reports its sample SMA strategy avoided large losses by sitting out until a new signal.

## Parameters To Test
- `fast_sma`: 20, 50, 75
- `slow_sma`: 150, 200, 250
- `shorts_enabled`: true/false
- `atr_stop_mult`: 0, 2.0, 3.0, 4.0
- `timeframe`: D1 only for first pass; H4 only if P2 cadence is too sparse.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, Research draft from Raposa mechanical tutorial.

## Verwandte Strategien
- [[strategies/QM5_10126_carver-sma]] - Rob Carver 16/64 SMA trend system with volatility stop.
- [[strategies/QM5_10119_mad-ratio]] - ratio of fast and slow moving averages.

## Lessons Learned
- TBD

