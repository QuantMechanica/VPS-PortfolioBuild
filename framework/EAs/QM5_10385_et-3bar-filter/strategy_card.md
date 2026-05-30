---
ea_id: QM5_10385
slug: et-3bar-filter
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "acrary, working system, needs improvement, Elite Trader, 2003-02-16, https://www.elitetrader.com/et/threads/working-system-needs-improvement.14001/page-4"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/intraday-breakout]]"
  - "[[concepts/trend-filter]]"
  - "[[concepts/range-compression]]"
indicators: [EMA, Range]
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX, GER40.DWX]
period: M15
expected_trade_frequency: "Time-windowed M15 setup requiring three directional candles, EMA(200), range compression, and prior-bar body filter; conservative estimate 90 trades/year/symbol."
expected_trades_per_year_per_symbol: 90
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 source URL/handle present; R2 mechanical 3-bar breakout, EMA/range/body filters, stops/targets/session exit with ~90 trades/year/symbol; R3 testable on SP500.DWX and live index CFD analogs; R4 fixed-rule no ML/grid/martingale."
---

# Elite Trader Three Bar Filter Breakout

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/working-system-needs-improvement.14001/page-4
- Author / handle: `acrary`.
- Date: 2003-02-16.
- Location: post #32, EasyLanguage code with filters and SP results attachment reference.

## Mechanik

### Entry
- Run on M15 index data.
- Long setup:
  - current bar and previous two bars close above open;
  - current close is below current high;
  - close is above EMA(200);
  - 3-bar high-low range is below the source threshold, ported as `0.35 * ATR(20, M15)`;
  - current time is 10:00-12:00 or 13:30-15:00 exchange time;
  - previous bar absolute body divided by previous bar range is greater than 0.65.
- Long entry: buy stop at highest high of the last 3 bars.
- Short setup mirrors long:
  - three bars close below open;
  - current close is above current low;
  - close is below EMA(200);
  - same range/time/body filters.
- Short entry: sell stop at lowest low of the last 3 bars.

### Exit
- Store `rg = highest(high,3) - lowest(low,3)` at entry.
- Long target: `entry + 0.5 * rg`.
- Long stop: `entry - rg`.
- Short target: `entry - 0.5 * rg`.
- Short stop: `entry + rg`.
- Exit at session close if still open.

### Stop Loss
- Source stop is one setup range from entry.
- V5 minimum stop distance: at least four spreads.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Do not place a new stop order after 15:00 exchange time.
- Cancel unfilled orders outside the source time windows.

## Concepts
- [[concepts/intraday-breakout]] - stop entry through a three-bar extreme.
- [[concepts/trend-filter]] - EMA(200) defines long/short regime.
- [[concepts/range-compression]] - setup requires small recent range.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL plus visible handle `acrary`. |
| R2 Mechanical | PASS | Source code defines entries, exits, time windows, trend filter, and body/range filter. |
| R3 DWX-testbar | PASS | SP index logic is testable on SP500.DWX and live index CFD analogs. |
| R4 No ML | PASS | Fixed thresholds and one-position V5 implementation; no ML, adaptive logic, grid, martingale, or pyramiding. |

## R3
Primary P2 basket: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GER40.DWX`.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- The post says the displayed results use SP data from 1997-01-01 to 2001-06-30.
- Later comments debate robustness; this is retained as pipeline risk rather than a G0 failure.

## Parameters To Test
- EMA length: 150, 200, 250.
- Range threshold: 0.25, 0.35, 0.50 ATR(20).
- Body/range threshold: 0.55, 0.65, 0.75.
- Target multiple: 0.5, 0.75, 1.0 setup range.
- Time windows: source windows, morning only, afternoon only.

## Initial Risk Profile
Intraday breakout with asymmetric reward-to-risk in the source code. It may be sensitive to index volatility regime and transaction costs.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
