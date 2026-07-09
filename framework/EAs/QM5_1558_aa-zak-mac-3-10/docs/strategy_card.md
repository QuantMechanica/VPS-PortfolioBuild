---
ea_id: QM5_1558
slug: aa-zak-mac-3-10
expected_trades_per_year_per_symbol: 12
type: strategy
source_id: ede348b4-0fa7-5be1-baa8-09e9089b67b7
sources:
  - "[[sources/alpha-architect-blog]]"
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
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL/attribution present; R2 fixed monthly SMA(3/10) crossover entry/exit; R3 DWX OHLC-testable with SP500 backtest/T6 caveat; R4 fixed non-ML one-position logic."
---

# Alpha Architect Zakamulin SMA 3/10 Monthly Crossover

## Quelle
- Source: [[sources/alpha-architect-blog]]
- Page / Timestamp: Valeriy Zakamulin, "Trend-Following with Valeriy Zakamulin: Technical Trading Rules (Part 3)", 2017-08-11, https://alphaarchitect.com/trend-following-valeriy-zakamulin-technical-trading-rules-part-3/

## Mechanik

Part 3 defines the moving-average-crossover indicator as the short moving average minus the long moving average and illustrates `MAC(3,10)` on monthly S&P 500 prices.

### Entry
- Evaluate on the final completed monthly bar.
- Compute `SMA(3)` and `SMA(10)` on monthly closes.
- Open long if `SMA(3,MN1,1) > SMA(10,MN1,1)`.
- Baseline DWX symbols: SP500.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX, XAUUSD.DWX, USOIL.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX.

### Exit
- Rebalance monthly.
- Close the long position if `SMA(3,MN1,1) <= SMA(10,MN1,1)`.
- No short baseline; risk-off state is cash.

### Stop Loss
- Initial SL = 3.0 x ATR(20,D1).
- Time stop: monthly bearish crossover.

### Position Sizing
- P2-baseline: `RISK_FIXED = 1000`.
- T6-live: `RISK_PERCENT = 0.5`.

### Zusätzliche Filter
- One position per symbol/magic.
- Minimum 11 completed monthly bars.
- Do not open if monthly ATR(6) is less than 50% of its 36-month median, to avoid dead low-range series.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/moving-average-crossover]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full Alpha Architect URL with named author Valeriy Zakamulin and dated publication. |
| R2 Mechanical | PASS | Fixed 3/10 monthly SMA crossover with deterministic rebalance and exit. |
| R3 Data Available | PASS | Uses only OHLC data available on DWX CFDs; SP500.DWX caveat below. |
| R4 ML Forbidden | PASS | Fixed parameters, one-position-per-magic compatible, no ML or adaptive logic. |

## R3
Original illustration uses S&P 500 monthly prices. DWX port applies the same crossover to index, commodity, gold, and FX CFDs.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: PENDING (Batch 4 draft 2026-05-19)
- P1: -
- P2: -

## Verwandte Strategien
- [[strategies/QM5_1557_aa-zak-psma10]] - same source, single-average timing variant.

## Lessons Learned (während Pipeline-Lauf)
- TBD
