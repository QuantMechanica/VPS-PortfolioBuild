---
ea_id: QM5_10933
slug: grimes-cup-hndl
type: strategy
source_id: fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
source_citation: "Adam H. Grimes, Failure is NOT always an option, 2020-07-31, https://www.adamhgrimes.com/failure-is-not-always-an-option/"
sources:
  - "[[sources/adam-grimes-blog]]"
concepts:
  - "[[concepts/cup-and-handle]]"
  - "[[concepts/breakout]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/atr]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, NDX.DWX, GER40.DWX]
period: D1
expected_trade_frequency: "D1 cup/handle or flag below visible resistance after higher-timeframe trend shift; conservative estimate 8-20 trades/year/symbol."
expected_trades_per_year_per_symbol: 12
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 named Grimes article URL cited; R2 fixed D1/W1 cup-handle breakout entries, exits, stops and basket cadence >=2/year/symbol plausible after porting; R3 DWX forex/index OHLC testable; R4 fixed non-ML one-position logic."
---

# Grimes Cup Handle Breakout

## Quelle
- Source: [[sources/adam-grimes-blog]]
- Citation: Adam H. Grimes, "Failure is NOT always an option", 2020-07-31, https://www.adamhgrimes.com/failure-is-not-always-an-option/
- Source location: Grimes describes a higher-timeframe trend change, a daily textbook cup-and-handle pattern that can also be read as a flag below visible resistance, and a breakout where failure after momentum starts becomes unacceptable.

## Mechanik

### Entry
- Evaluate on D1 close.
- Long setup:
  - W1 EMA(20) slope is positive over the last 5 W1 bars.
  - D1 price forms a 15-60 bar rounded base: lowest low occurs at least 5 bars after the left rim and at least 5 bars before the right rim.
  - Left and right rim highs are within 1.0 * ATR(20) of each other.
  - Handle forms over 3-15 D1 bars with a pullback <= 50% of the base depth.
  - Enter long when D1 closes above the right-rim high by 0.1 * ATR(20).
- Short setup mirrors the long setup using W1 downtrend, inverted base, support, and downside handle break.

### Exit
- Target = 2.0R.
- Move stop to breakeven at 1.0R.
- After breakout reaches 0.75R, exit if the next 3 D1 bars fail to close beyond the rim in the trade direction.
- Time exit after 20 D1 bars.

### Stop Loss
- Long stop = handle low - 0.25 * ATR(20).
- Short stop = handle high + 0.25 * ATR(20).
- Reject if stop distance > 3.5 * ATR(20).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default percent risk if approved.

### Zusaetzliche Filter
- One active position per symbol/magic.
- Skip if breakout close is more than 3.0 * ATR(20) from EMA(20), to avoid terminal overextension.
- Skip if spread exceeds 10% of stop distance.

## Concepts
- [[concepts/cup-and-handle]] - primary
- [[concepts/breakout]] - execution trigger

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author and full article URL are cited. |
| R2 Mechanical | PASS | Source gives cup/handle, flag-under-resistance, higher-timeframe trend-change, and breakout-failure management; card fixes geometry. |
| R3 DWX-testbar | PASS | D1/W1 OHLC/EMA/ATR rules are testable on DWX forex and index CFDs. |
| R4 No ML | PASS | Fixed chart-geometry rules; no ML/adaptive/grid/martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, NDX.DWX, GER40.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10921_grimes-bearflag]] - both trade flag-like continuation; this card requires a rounded cup/handle near visible resistance/support and explicit breakout-failure management.

## Lessons Learned
- TBD during pipeline run.

