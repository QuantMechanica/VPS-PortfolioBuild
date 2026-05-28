---
ea_id: QM5_10130
slug: tv-sma40-scaleout
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
source_citation: "TradingView user script, 40 SMA Scaling Strategy, TradingView, https://www.tradingview.com/script/c5VbhJaL-40-SMA-Scaling-Strategy/"
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/scale-out-management]]"
indicators:
  - "[[indicators/sma]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, SP500.DWX]
period: H4
expected_trade_frequency: "40-bar SMA continuation with scale-out exits; H4 estimate 25-55 trades/year/symbol."
expected_trades_per_year_per_symbol: 35
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView source URL cited; R2 deterministic SMA40 cross entries with ATR stop and R-multiple/SMA exits, ~35 trades/year/symbol; R3 ports to DWX FX/gold/SP500 backtest with T6 caveat; R4 fixed rules, one position, no ML/grid/martingale."
---

# TradingView 40 SMA Scale-Out Continuation

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Citation: "40 SMA Scaling Strategy", TradingView, 2026 access URL https://www.tradingview.com/script/c5VbhJaL-40-SMA-Scaling-Strategy/.
- Source location: public script page describes 40-period SMA-based entries, multiple scaled take-profit levels, and a protective stop.

## Mechanik

### Entry
- Baseline parameters:
  - SMA length 40.
  - Initial stop distance 2.0 * ATR(14) if the Pine source does not expose a fixed stop.
- Long entry when close crosses above SMA(40).
- Short entry when close crosses below SMA(40).

### Exit
- Scale-out variant:
  - Close 33% of position at +1R.
  - Close another 33% at +2R.
  - Close remainder when close crosses back through SMA(40) or at +3R.
- Single-position fallback for strict one-ticket implementations:
  - Exit full long when close crosses below SMA(40) or at +2R.
  - Exit full short when close crosses above SMA(40) or at +2R.

### Stop Loss
- Long stop: entry price - 2.0 * ATR(14).
- Short stop: entry price + 2.0 * ATR(14).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- If partial close is unsupported by the pipeline harness, use the single-position fallback.

### Zusaetzliche Filter
- H4 primary to avoid low-cadence D1 behavior while preserving the 40-bar trend horizon.
- Skip if spread > 10% of initial stop distance.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/scale-out-management]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full TradingView URL to the public script page. |
| R2 Mechanical | PASS | SMA cross direction, protective stop, and scale-out exits are deterministic. |
| R3 DWX-testbar | PASS | SMA/ATR logic ports to DWX FX, gold, and index CFDs; SP500.DWX can test broad-index behavior. |
| R4 No ML | PASS | Fixed moving-average and fixed R-multiple exits; no ML, grid, martingale, or performance-adaptive parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, SP500.DWX.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10116_tv-multi-ma-exit]] - related MA continuation family; this card uses one SMA and staged R exits.

## Lessons Learned
- TBD during pipeline run.
