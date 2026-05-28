---
ea_id: QM5_1222
slug: carver-scalp-bracket
type: strategy
source_id: 2a380bee-1ec4-50d1-a348-b10fac642c7a
sources:
  - "[[sources/rob-carver-blog]]"
concepts:
  - "[[concepts/intraday-mean-reversion]]"
  - "[[concepts/bracket-order]]"
  - "[[concepts/microstructure]]"
indicators:
  - "[[indicators/intraday-range]]"
  - "[[indicators/stop-loss]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
expected_trades_per_year_per_symbol: 2000
g0_approval_reasoning: "R1 PASS linked Rob Carver qoppac URL; R2 PASS deterministic bracket entry/exit/stop/close rules; R3 PASS SP500.DWX backtest-only with NDX/WS30 T6 caveat; R4 PASS fixed params one bracket per magic no ML/martingale."
---

# QM5_1222 Carver Intraday Range Bracket Scalper

## Quelle
- Source: [[sources/rob-carver-blog]]
- Primary URL: https://qoppac.blogspot.com/2025/05/can-i-build-scalping-bot-blogpost-with.html
- Author: Rob Carver. The 2025 post specifies a state-machine bracket scalper using range-scaled symmetric limit orders, range-scaled stops, soft/hard close times, and a chosen S&P configuration `H=900`, `K=0.87`; Carver later adds that the live attempt did not work.

## Mechanik

Intraday mean-reversion scalper. Start flat, estimate a recent intraday range, place symmetric buy/sell limit brackets around current price, take profit at the opposite bracket, and use a stop beyond the entry but inside the estimated range. This card is intentionally marked as high execution-risk because the source states results are extremely sensitive to fills and the postscript says the attempted live version failed.

Suggested P2 universe: SP500.DWX custom symbol only for backtest, using OWNER-provided ticks/1-minute aggregation where available. Exploratory live-routable proxy validation, if the card survives, should use NDX.DWX or WS30.DWX before T6.

### Entry
- Intraday session setup:
  - Trade only between `SessionStart` and `SoftCloseTime`.
  - Calculate `R = High(HorizonSeconds) - Low(HorizonSeconds)` using the latest completed intraday window.
  - Default `HorizonSeconds=900`, `F=0.75`, `K=0.87`.
  - Round all prices to symbol tick size.
- When flat and no live orders:
  - Set `mid = current bid/ask midpoint` or latest bar close in backtest.
  - Place buy limit at `mid - (R/2)*F`.
  - Place sell limit at `mid + (R/2)*F`.
- If buy limit fills:
  - Keep the existing sell limit as take profit.
  - Place sell stop at `mid - (R/2)*K`.
- If sell limit fills:
  - Keep the existing buy limit as take profit.
  - Place buy stop at `mid + (R/2)*K`.

### Exit
- Profit exit:
  - Long exits at the existing upper sell limit.
  - Short exits at the existing lower buy limit.
- Stop exit:
  - Long exits at the lower sell stop.
  - Short exits at the upper buy stop.
- After any exit, cancel the leftover unbalanced order and return to flat state.
- At `HardCloseTime`, cancel all working orders and close any open position at market.

### Stop Loss
- Per-trade stop distance is range-scaled:
  - Long stop distance from entry is `(R/2) * (K - F)`.
  - Short stop distance from entry is `(R/2) * (K - F)`.
- Daily kill switch: stop opening new brackets after `DailyLossLimit = 3 * RISK_FIXED`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade, converted to the number of contracts/lots implied by the stop distance.
- Live: not eligible from SP500.DWX alone; T6 requires parallel validation on broker-routable NDX.DWX or WS30.DWX.
- One bracket state machine per symbol/magic; no pyramiding, no martingale.

### Zusätzliche Filter
- Skip if `R <= 0`, spread exceeds `0.20 * R`, or stop distance is less than `10` ticks.
- Skip during first `WarmupMinutes=30` of session.
- Skip new brackets after `SoftCloseTime`.
- Require tick or 1-minute data; do not run on D1 bars.

## Concepts
- [[concepts/intraday-mean-reversion]] - primary
- [[concepts/bracket-order]] - primary
- [[concepts/microstructure]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author and exact qoppac URL. |
| R2 Mechanical | PASS | State machine, bracket widths, stop placement, soft/hard close, and kill switch are deterministic. |
| R3 DWX-testbar | PASS | SP500.DWX custom symbol is available for backtest-only S&P edges; live requires proxy validation caveat. |
| R4 No ML | PASS | Fixed parameters and one bracket state per magic; no ML, no grid accumulation, no martingale. |

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-18 - drafted from Rob Carver blog third batch, PENDING.

## Verwandte Strategien
- [[strategies/QM5_1220_carver-mrwings]] - slower contrarian mean-reversion cousin.

## Lessons Learned (wahrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`.*
