---
ea_id: QM5_1147
slug: unger-dax-false-break-reversal
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
sources:
  - "[[sources/unger-robbins-cup]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/false-breakout]]"
indicators:
  - "[[indicators/previous-day-high-low]]"
  - "[[indicators/session-window]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 PASS official Unger Academy URL plus book ISBN; R2 PASS mechanical false-break recross entry and session/ATR exits; R3 PASS GDAXI.DWX testable; R4 PASS fixed rules no ML/grid/martingale one-position-per-magic."
---

# Unger DAX False-Break Reversal - Previous-Day Level Fade

## Quelle
- Source: [[sources/unger-robbins-cup]] - Unger Academy DAX bias/reversal article.
- Article: "Two Strategies on DAX with Remarkable Performance Since 2017 - Bias and Reversal" - https://ungeracademy.com/blog/two-strategies-on-dax-with-remarkable-performance-since-2017-bias-and-reversal
- Location: transcription section describing a 15-minute DAX reversal strategy that enters long after a close below the previous day's low and recovery above it, and short after a false breakout of the previous day's high.
- Supporting source: *The Unger Method - Andrea Unger's Trading Method* (Unger Academy Publishing, 2nd ed. 2021, ISBN 978-8896590164).

## Mechanik

Universe: GDAXI.DWX primary. Execution timeframe M15.

### Entry
At the start of the regular DAX trading day:
1. Compute `PDH = previous session high` and `PDL = previous session low`.
2. Mark `LOW_BROKEN = true` after any M15 close below `PDL`.
3. If `LOW_BROKEN` and a later M15 bar closes back above `PDL`, enter LONG at market.
4. Mark `HIGH_BROKEN = true` after any M15 close above `PDH`.
5. If `HIGH_BROKEN` and a later M15 bar closes back below `PDH`, enter SHORT at market.
6. Maximum one entry per day.

### Exit
- Close at end of the DAX session.
- Close earlier on stop loss or take profit.

### Stop Loss
- First-build stop: `SL = 1.5 * ATR(14,M15)` from entry.
- First-build take profit: `TP = 1.0 * ATR(14,M15)`.
- P3 sweep `SL_MULT in {1.0, 1.5, 2.0}` and `TP_MULT in {0.75, 1.0, 1.5}`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25%`.

### Zusaetzliche Filter
- Trade only inside a configured regular-session window; source examples use the DAX daytime session.
- Skip days with abnormal opening gap above 1.5x ATR(14,D1).
- Standard V5 spread/news filters.
- One position per magic.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/mean-reversion]] - primary
- [[concepts/false-breakout]] - primary
- [[concepts/index-cfd]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Official Unger Academy URL plus book ISBN. |
| R2 Mechanical | UNKNOWN | Previous-day levels, close-through and recross triggers, fixed session exit and ATR stop/target. |
| R3 Data Available | UNKNOWN | GDAXI.DWX is available and directly maps the DAX-futures source market to a DWX index CFD. |
| R4 ML Forbidden | UNKNOWN | Fixed rules and fixed parameters; no ML/adaptive online tuning/grid/martingale. |

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1123_unger-crude-prevday-meanrev]] - previous-day level fade on crude oil.
- [[strategies/QM5_1146_unger-dax-overnight-bias]] - same source article, but pure time-bias logic.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
