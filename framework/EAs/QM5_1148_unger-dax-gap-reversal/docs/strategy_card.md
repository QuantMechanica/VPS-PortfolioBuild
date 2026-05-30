---
ea_id: QM5_1148
slug: unger-dax-gap-reversal
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
sources:
  - "[[sources/unger-robbins-cup]]"
concepts:
  - "[[concepts/gap-reversal]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/session-gap]]"
  - "[[indicators/previous-bar-high-low]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 PASS official Unger Academy URL plus book ISBN; R2 PASS mechanical gap condition, stop trigger, cancel window and session/ATR exits; R3 PASS GDAXI.DWX testable; R4 PASS fixed rules no ML/grid/martingale one-position-per-magic."
---

# Unger DAX Gap Reversal - 30-Minute Opening Gap Fade

## Quelle
- Source: [[sources/unger-robbins-cup]] - Unger Academy DAX high-volatility article.
- Article: "High volatility on the DAX: Real performance of 2 strategies (GAP + Trend-following)" - ungeracademy.com/blog/high-volatility-on-the-dax-real-performance-of-2-strategies-gap-trend-following
- Location: transcription section describing a 30-minute DAX gap system: gap up opens short at the break of the previous bar low; gap down opens long at the break of the previous bar high.
- Supporting source: *The Unger Method - Andrea Unger's Trading Method* (Unger Academy Publishing, 2nd ed. 2021, ISBN 978-8896590164).

## Mechanik

Universe: GDAXI.DWX primary. Execution timeframe M30 with a configured DAX reference session.

### Entry
At the first M30 bar of the DAX reference session:
1. Compute previous session `SESSION_HIGH`, `SESSION_LOW`, and `SESSION_CLOSE`.
2. If current session open is above `SESSION_HIGH`, mark `GAP_UP = true`.
3. If `GAP_UP`, place a sell-stop at the low of the completed first M30 bar.
4. If current session open is below `SESSION_LOW`, mark `GAP_DOWN = true`.
5. If `GAP_DOWN`, place a buy-stop at the high of the completed first M30 bar.
6. Cancel any unfilled order after the first three M30 bars.
7. Maximum one trade per day.

### Exit
- Close at end of DAX reference session.
- Close earlier on stop loss or take profit.

### Stop Loss
- First-build stop: `SL = 1.0 * ATR(14,M30)` from entry.
- First-build take profit: `TP = 1.0 * ATR(14,M30)`.
- P3 sweep tests wider `SL_MULT` and `TP_MULT`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25%`.

### Zusaetzliche Filter
- Use a stable historical session definition, default 08:00-22:00 Europe/Berlin, because the source notes the pattern was easier to observe under the older DAX session structure.
- Skip if absolute gap size is less than `0.25 * ATR(14,D1)`; this avoids noise gaps.
- Standard V5 spread/news filters.
- One position per magic.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/gap-reversal]] - primary
- [[concepts/mean-reversion]] - secondary
- [[concepts/index-cfd]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Official Unger Academy URL plus book ISBN. |
| R2 Mechanical | UNKNOWN | Gap condition, previous-bar breakout trigger, fixed cancellation window, session close, ATR stop/target. |
| R3 Data Available | UNKNOWN | GDAXI.DWX is available; rule uses only OHLC/session data. |
| R4 ML Forbidden | UNKNOWN | Fixed rules and parameters; no ML/adaptive online parameters/grid/martingale. |

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1147_unger-dax-false-break-reversal]] - same DAX mean-reversion family, but false breakout of previous-day levels rather than opening gap.
- [[strategies/QM5_1062_unger-orb-index]] - index intraday breakout, not gap fade.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
