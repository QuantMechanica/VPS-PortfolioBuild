---
ea_id: QM5_10928
slug: grimes-yoyo-break
type: strategy
source_id: fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
source_citation: "Adam H. Grimes, How to Trade Support and Resistance Levels, 2020-10-16, https://www.adamhgrimes.com/how-to-trade-support-and-resistance-levels/"
sources:
  - "[[sources/adam-grimes-blog]]"
concepts:
  - "[[concepts/range-breakout]]"
  - "[[concepts/support-resistance]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/pivots]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, GER40.DWX, XAUUSD.DWX]
period: M30
expected_trade_frequency: "Breakout after repeated oscillation around a level; conservative estimate 12-30 trades/year/symbol."
expected_trades_per_year_per_symbol: 18
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS source URL cited; R2 PASS mechanical M30 compression-breakout entry/exit with plausible 12-30 trades/year/symbol; R3 PASS DWX forex/index/metal testable; R4 PASS fixed no-ML one-position rules."
---

# Grimes Yo-Yo Level Breakout

## Quelle
- Source: [[sources/adam-grimes-blog]]
- Citation: Adam H. Grimes, "How to Trade Support and Resistance Levels", 2020-10-16, https://www.adamhgrimes.com/how-to-trade-support-and-resistance-levels/
- Source location: The article treats the yo-yo state as a warning not to trade while price is stuck around a level, but says alerts near the pattern boundaries can identify a breakout likely to extend toward the next level.

## Mechanik

### Entry
- Evaluate on M30 close.
- Define central level from previous D1 high/low or a confirmed H1 pivot level.
- Yo-yo compression setup:
  - At least 8 of the last 12 M30 closes are within 0.6 * ATR(20) of the central level.
  - Price crosses the central level at least 4 times during those 12 bars.
  - The 12-bar high-low range is <= 2.2 * ATR(20).
- Long trigger:
  - Close breaks above the 12-bar compression high by 0.15 * ATR(20).
  - Enter long at next bar open.
- Short trigger mirrors the long trigger below the 12-bar compression low.

### Exit
- Target = nearest unused level in breakout direction, or 2.0R if no nearby level is available.
- Move stop to breakeven at 1.0R.
- Time exit after 16 M30 bars.
- Exit early if a close returns inside the compression range after entry.

### Stop Loss
- Long stop = compression low - 0.2 * ATR(20).
- Short stop = compression high + 0.2 * ATR(20).
- Reject if stop distance > 3.0 * ATR(20).

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default percent risk if approved.

### Zusaetzliche Filter
- One active position per symbol/magic.
- No entries during the final 3 hours of the broker day.
- Spread cap = 8% of initial stop distance.

## Concepts
- [[concepts/range-breakout]] - primary
- [[concepts/support-resistance]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Named author and full article URL are cited. |
| R2 Mechanical | PASS | Source provides yo-yo compression and breakout-to-next-level concept; card fixes measurable compression, trigger, stop, and exit rules. |
| R3 DWX-testbar | PASS | Intraday OHLC/ATR/pivot rules are testable on DWX forex, metals, and index CFDs. |
| R4 No ML | PASS | Fixed range-breakout rules; no ML/adaptive/grid/martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, GER40.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10915_grimes-range-brk]] - both trade range breakouts; this card requires repeated oscillation around one level before breakout.
- [[strategies/QM5_10914_grimes-vol-comp]] - both trade compression; this card defines compression by level crossings rather than ATR ratio.

## Lessons Learned
- TBD during pipeline run.
