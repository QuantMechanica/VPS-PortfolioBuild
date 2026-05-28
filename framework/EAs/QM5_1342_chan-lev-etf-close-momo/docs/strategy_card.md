---
ea_id: QM5_1342
slug: chan-lev-etf-close-momo
type: strategy
source_id: fce67611-4e0f-5dce-8cff-c8b9dd84dd49
sources:
  - "[[sources/ernest-chan-blog]]"
concepts:
  - "[[concepts/intraday-momentum]]"
  - "[[concepts/index-rebalance-flow]]"
indicators:
  - "[[indicators/session-return]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL to Ernest Chan post; R2 explicit threshold entry and same-session close exit; R3 SP500.DWX backtest-only with NDX/WS30 live-promotion caveat; R4 fixed-rule no ML one-position-per-magic."
---

# Leveraged ETF Close Momentum

## Quelle
- Source: [[sources/ernest-chan-blog]]
- URL: https://epchan.blogspot.com/2012/10/a-leveraged-etfs-strategy.html
- Page / Timestamp: "A leveraged ETFs strategy", Ernest Chan, 2012-10-25.

## Mechanik

### Entry
- Trade the index proxy `SP500.DWX` first; optional live-validation port to `NDX.DWX` or `WS30.DWX`.
- At 14:15 New York time, compute return from the previous session close to current price.
- If return >= +2.0%, enter long immediately.
- If return <= -2.0%, enter short immediately.
- If absolute return is below 2.0%, do not trade.

### Exit
- Exit at the same session close using the nearest deterministic close execution supported by MT5.

### Stop Loss
- Initial default: 1.0 ATR(14, M5) from entry or forced close at session end, whichever comes first.
- P3 sweep candidates: 0.5, 1.0, 1.5 ATR.

### Position Sizing
- P2 baseline: Fixed Risk $1,000.
- One position per magic number.

### Zusätzliche Filter
- Trade only on regular US index session days.
- Spread filter: skip if spread > 1.5x rolling 20-day median at entry time.
- Optional P3 sweep: threshold 1.5%, 2.0%, 2.5%; entry time 14:00, 14:15, 14:30 NY.

## Concepts (was ist das für eine Strategie)
- [[concepts/intraday-momentum]] - primary
- [[concepts/index-rebalance-flow]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public Ernest Chan blog post with full URL, named author, title, and date. |
| R2 Mechanical | PASS | Directional entry threshold and same-day close exit are explicit. |
| R3 Data Available | PASS | SP500.DWX is available for backtest-only; live promotion requires the standard parallel-validation on NDX.DWX or WS30.DWX. |
| R4 ML Forbidden | PASS | Fixed threshold intraday rule; no ML, adaptive learning, martingale, or grid. |

## R3
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-18, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1336_chan-index-10d-low]] - same source family, index mean-reversion rather than close momentum.

## Lessons Learned (während Pipeline-Lauf)
- TBD
