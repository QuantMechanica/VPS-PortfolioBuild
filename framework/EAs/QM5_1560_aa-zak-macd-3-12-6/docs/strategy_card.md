---
ea_id: QM5_1560
slug: aa-zak-macd-3-12-6
expected_trades_per_year_per_symbol: 12
type: strategy
source_id: ede348b4-0fa7-5be1-baa8-09e9089b67b7
sources:
  - "[[sources/alpha-architect-blog]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/macd]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/macd]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 cited Alpha Architect URL; R2 monthly MACD entry/exit mechanical; R3 OHLC rules testable on DWX incl SP500 backtest caveat; R4 fixed-parameter no ML one-position compatible."
---

# Alpha Architect Zakamulin Monthly MACD 3/12/6 Timing

## Quelle
- Source: [[sources/alpha-architect-blog]]
- Page / Timestamp: Valeriy Zakamulin, "Trend-Following with Valeriy Zakamulin: Technical Trading Rules (Part 3)", 2017-08-11, https://alphaarchitect.com/trend-following-valeriy-zakamulin-technical-trading-rules-part-3/

## Mechanik

Part 3 defines MACD as the difference between a short/long EMA spread and a smoothed EMA of that spread, and illustrates `MACD(3,12,6)` on monthly S&P 500 prices.

### Entry
- Evaluate on the final completed monthly bar.
- Compute `EMA(3)` and `EMA(12)` on monthly closes.
- `MAC = EMA(3) - EMA(12)`.
- `Signal = EMA(6)` of `MAC`.
- Open long if `MAC > Signal`.
- Baseline DWX symbols: SP500.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX, XAUUSD.DWX, USOIL.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX.

### Exit
- Rebalance monthly.
- Close the long position if `MAC <= Signal`.
- No short baseline; risk-off state is cash.

### Stop Loss
- Initial SL = 3.0 x ATR(20,D1).
- Time stop: monthly MACD bearish signal.

### Position Sizing
- P2-baseline: `RISK_FIXED = 1000`.
- T6-live: `RISK_PERCENT = 0.5`.

### Zusätzliche Filter
- One position per symbol/magic.
- Minimum 18 completed monthly bars for stable EMA warmup.
- Do not open if absolute monthly MACD is below 0.25 x ATR(20,MN1), to suppress near-zero crossover noise.

## Concepts (was ist das für eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/macd]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full Alpha Architect URL with named author Valeriy Zakamulin and dated publication. |
| R2 Mechanical | PASS | Fixed EMA lengths and deterministic MAC-vs-signal entry/exit. |
| R3 Data Available | PASS | Uses only OHLC-derived EMA/MACD calculations on DWX CFDs; SP500.DWX caveat below. |
| R4 ML Forbidden | PASS | Fixed parameters, one-position-per-magic compatible, no ML, no adaptive logic. |

## R3
Original illustration uses S&P 500 monthly prices. DWX port applies the same monthly MACD timing rule to index, commodity, gold, and FX CFDs.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: PENDING (Batch 4 draft 2026-05-19)
- P1: -
- P2: -

## Verwandte Strategien
- [[strategies/QM5_1558_aa-zak-mac-3-10]] - same source, simpler two-average crossover.

## Lessons Learned (während Pipeline-Lauf)
- TBD
