---
ea_id: QM5_1336
slug: chan-index-10d-low
type: strategy
source_id: fce67611-4e0f-5dce-8cff-c8b9dd84dd49
sources:
  - "[[sources/ernest-chan-blog]]"
concepts:
  - "[[concepts/index-mean-reversion]]"
  - "[[concepts/long-only]]"
  - "[[concepts/daily-swing]]"
indicators:
  - "[[indicators/rolling-low]]"
  - "[[indicators/sma]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS Chan blog URL/attribution; R2 PASS mechanical 10-day-low long entry plus SMA/time exits and ~100 trades/year/symbol; R3 PASS SP500.DWX backtest with NDX/WS30 live caveat; R4 PASS fixed non-ML one-position rules."
expected_trades_per_year_per_symbol: 100
---

# Chan Index 10-Day Low Long

## Quelle
- Source: [[sources/ernest-chan-blog]]
- Blog URL: https://epchan.blogspot.com/2007/04/hedging-isnt-always-better.html
- Article: "Hedging isn't always better", Ernest/Ernie Chan, 2007-04-07.
- Page / Timestamp: Paragraph giving a simple example of buying an index at its 10-day low and noting the short-side mirror works less well.

## Mechanik

### Entry
On each daily close for an equity index proxy:
- Source concept: long-only index mean reversion.
- DWX baseline symbol: `SP500.DWX` for backtest-only. P3/P8 can also test `NDX.DWX` and `WS30.DWX`.
- If `close <= lowest_low(10)` or `close <= min(close[1..10])`, enter long at next session open.
- Do not short 10-day highs; source says the mirror short side works less well.
- One open position per magic number.

### Exit
Use the simplest deterministic exit among Chan's multiple-exit comment:
- Exit when `close >= SMA(5)` after entry.
- Time stop after `5` trading days if SMA exit has not triggered.
- P3 can sweep alternative exits: `SMA(10)`, prior 5-day high, or fixed 3-day hold.

### Stop Loss
No explicit stop in source. Baseline catastrophic stop: `2.5 * ATR(14, D1)` from entry.

### Position Sizing
Fixed $1,000 P2 risk equivalent, one long index-CFD position per magic number.

### Zusätzliche Filter
- Long-only; skip if the symbol cannot be routed live.
- No entry on incomplete daily bar.
- Optional P3 filter: skip entries when `ATR(14) / close` exceeds its rolling 95th percentile.

## Concepts (was ist das für eine Strategie)
- [[concepts/index-mean-reversion]] - primary
- [[concepts/long-only]] - secondary
- [[concepts/daily-swing]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public Ernest Chan blog URL with named author/date and explicit 10-day-low index example. |
| R2 Mechanical | PASS | Long-only 10-day-low entry exists; exit is filled with conservative deterministic defaults under relaxed R2. |
| R3 Data Available | PASS | SP500.DWX can backtest S&P-style index behavior; NDX.DWX/WS30.DWX are live-routable validation candidates. |
| R4 ML Forbidden | PASS | Fixed daily rule; no ML, no adaptive parameters, no grid/martingale. |

## R3
SP500.DWX port caveat: "Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable."

## Pipeline-Verlauf
- G0: 2026-05-18, PENDING, drafted from Ernest Chan blog batch 3.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_1277_chan-buy-on-gap-close]] - Chan long-only intraday gap mean-reversion card.
- [[strategies/QM5_1081_chan-lo-1d-reversal]] - earlier Chan cross-sectional loser/winner mean-reversion card.

## Lessons Learned (während Pipeline-Lauf)
- TBD
