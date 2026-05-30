---
ea_id: QM5_1215
slug: papailias-ma-trail
type: strategy
source_id: afab7a6f-c3c8-51ae-a609-f376744beb8e
sources:
  - "[[sources/ssrn-financial-economics-network]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/moving-average-crossover]]"
indicators:
  - "[[indicators/simple-moving-average]]"
  - "[[indicators/trailing-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 SSRN URL/authors; R2 SMA/ATR entry-exit trail is mechanical; R3 DWX indices/FX testable with SP500 caveat; R4 fixed params no ML/grid/martingale."
---

# Papailias-Thomakos MA Crossover With Dynamic Trail

## Quelle
- Source: [[sources/ssrn-financial-economics-network]]
- URL: ssrn abstract 1926376
- Named source authors: Fotis Papailias and Dimitrios Thomakos, "An Improved Moving Average Technical Trading Rule" (Quantf Research Working Paper Series No. WP01/2014, 2014).
- Location: SSRN abstract describes a long-only price/moving-average crossover rule combined with a dynamic threshold value that acts as a dynamic trailing stop.

## Mechanik

### Entry
1. On each D1 close, compute `SMA(Close, 200)` on each target symbol.
2. If flat and `Close[D1] > SMA200[D1]`, open LONG at the next D1 open.
3. Initialize `trail_high = entry_price` and `dynamic_threshold = trail_high - 2.0 * ATR(20)`.
4. Trade target set for P2: `SP500.DWX`, `NDX.DWX`, `GER40.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`.

### Exit
- Update `trail_high = max(trail_high, Close[D1])` while in position.
- Close LONG at next D1 open if `Close[D1] < dynamic_threshold`.
- Close LONG at next D1 open if `Close[D1] < SMA200[D1]`.

### Stop Loss
- The dynamic threshold is the primary stop.
- Catastrophic stop at 3.0x D1 ATR(20) from entry if intraday price gaps below the trailing threshold.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per symbol.
- Live: `RISK_PERCENT = 0.25`.
- One position per magic number; no pyramiding.

### Zusätzliche Filter
- Require at least 220 daily bars before first trade.
- P3 sweep: MA length `{100, 150, 200}`, threshold `{1.5, 2.0, 2.5} * ATR(20)`.
- Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/moving-average-crossover]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | SSRN URL is verifiable and names Papailias/Thomakos. |
| R2 Mechanical | UNKNOWN | Price-over-MA entry and trailing threshold exit are closed-form. |
| R3 Data Available | UNKNOWN | Uses DWX index and FX prices only. |
| R4 ML Forbidden | UNKNOWN | Fixed MA/ATR parameters; no ML, adaptive PnL parameters, grid, or martingale. |

## Pipeline-Verlauf
- G0: 2026-05-18, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1206_lento-sp500-csa-ma]] - combined two-MA signal on SP500.DWX.

## Lessons Learned
- (noch keine)
