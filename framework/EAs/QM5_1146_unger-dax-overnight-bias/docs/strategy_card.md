---
ea_id: QM5_1146
slug: unger-dax-overnight-bias
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
sources:
  - "[[sources/unger-robbins-cup]]"
concepts:
  - "[[concepts/session-bias]]"
  - "[[concepts/index-cfd]]"
indicators:
  - "[[indicators/time-window]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Unger Academy DAX bias article (URL+ISBN) R1 PASS; deterministic 17:15/09:00 Europe/Berlin entry/exit + ATR(14,M15)*1.5 SL R2 PASS; GDAXI.DWX primary live-tradable R3 PASS; no ML/adaptive/grid R4 PASS"
---

# Unger DAX Overnight Bias - Long Afternoon-to-Cash-Open

## Quelle
- Source: [[sources/unger-robbins-cup]] - Unger Academy DAX bias/reversal article.
- Article: "Two Strategies on DAX with Remarkable Performance Since 2017 - Bias and Reversal" - Unger Academy DAX bias/reversal article.
- Location: transcription lines describing a DAX bias strategy that opens long at 5:15 p.m. and closes at 9:00 a.m. when the DAX cash session opens.
- Supporting source: *The Unger Method - Andrea Unger's Trading Method* (Unger Academy Publishing, 2nd ed. 2021, ISBN 978-8896590164).

## Mechanik

Universe: GDAXI.DWX primary. Optional robustness ports: NDX.DWX, WS30.DWX. Execution timeframe M5/M15 with Europe/Berlin session clock.

### Entry
1. On each trading day, if no position is open for this magic, evaluate at 17:15 Europe/Berlin.
2. Enter LONG at market at 17:15.
3. No short entries.

### Exit
- Close the long position at 09:00 Europe/Berlin on the next trading session.
- Close earlier if stop loss is hit.
- Skip entry if the next 09:00 cash-open close would fall on a market holiday.

### Stop Loss
- Source gives the timed entry/exit but no exact stop.
- First-build stop: `SL = 1.5 * ATR(14,M15)` measured before entry.
- No take profit by default; thesis is the overnight/session-bias hold.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25%`.

### Zusaetzliche Filter
- Trade only Sunday-Thursday evening sessions whose next morning has a regular DAX cash open.
- Skip if spread exceeds 2x the 20-day median spread for the same minute of week.
- Optional P3 sweep: `ENTRY_TIME in {16:45, 17:00, 17:15, 17:30}` and `EXIT_TIME in {08:45, 09:00, 09:15}`.
- One position per magic.

## Concepts
- [[concepts/session-bias]] - primary
- [[concepts/index-cfd]] - secondary
- [[concepts/calendar-time-edge]] - secondary

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.
