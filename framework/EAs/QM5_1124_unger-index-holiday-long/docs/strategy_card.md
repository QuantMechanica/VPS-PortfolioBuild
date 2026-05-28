---
ea_id: QM5_1124
slug: unger-index-holiday-long
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
sources:
  - "[[sources/unger-robbins-cup]]"
concepts:
  - "[[concepts/seasonality]]"
  - "[[concepts/calendar-bias]]"
indicators:
  - "[[indicators/holiday-calendar]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Unger Academy pre-holiday index-long bias (Unger blog Long-on-Holidays + Unger Method book 2021 ISBN 978-8896590164): R1 verifiable ungeracademy.com URL + named-book ISBN; R2 calendar-driven entry (T-2 holiday) + SMA(180) trend filter + 5-bar time exit + 1x ATR(10) SL / 3x ATR(10) TP fully determini"
---

# Unger Index Holiday Long - Pre-Holiday Bias

## Quelle
- Source: [[sources/unger-robbins-cup]] - Unger Academy holiday-bias article.
- Article: "Long on Holidays" - https://ungeracademy.com/blog/long-on-holidays
- Location: transcription lines describing entry two days before a holiday, optional moving-average filter, five-bar time exit, ATR stop, and ATR take profit.
- Supporting source: *The Unger Method - Andrea Unger's Trading Method* (Unger Academy Publishing, 2nd ed. 2021, ISBN 978-8896590164).
- Unger presents a long-only pre-holiday setup on index futures, with strongest examples around Easter/Christmas and DAX, but warns the trade carries gap risk while markets are closed.

## Mechanik

Universe: GDAXI.DWX primary for DAX-port; optional SP500.DWX backtest-only plus NDX.DWX/WS30.DWX live-routable US-index ports. Execution timeframe D1.

### Entry
For each configured exchange holiday set:
1. If `DAYS_BEFORE_HOLIDAY == 2`, set a long signal.
2. Enter long at the next trading day's open.
3. Optional trend filter: trade only if `Close[1] > SMA(Close, 180)`; default enabled for risk reduction.
4. Optional month filter: default months `{3,4,12}` for Easter/Christmas families; P3 may test all months.

### Exit
- Default source exit: close after 5 daily bars in trade.
- Short-hold variant: close at the first session close after the holiday; P3 should compare this against the five-bar hold.
- Close on stop loss or take profit first.

### Stop Loss
- `SL = 1.0 * ATR(10,D1)` from entry.
- `TP = 3.0 * ATR(10,D1)` from entry, matching the source's 1x stop / 3x take-profit example.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25%`.

### Zusaetzliche Filter
- Calendar source must be deterministic and versioned per symbol/exchange.
- Skip holidays where the next session opens with a gap beyond 1.5x planned stop distance.
- Standard V5 spread/news filters.
- One position per magic.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/seasonality]] - primary
- [[concepts/calendar-bias]] - primary
- [[concepts/index-cfd]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Official Unger Academy URL plus book ISBN. |
| R2 Mechanical | UNKNOWN | Calendar-based entry, fixed MA filter, fixed time exit, ATR stop/take-profit. |
| R3 Data Available | UNKNOWN | GDAXI.DWX/NDX.DWX/WS30.DWX are available; optional SP500.DWX is backtest-only. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. |
| R4 ML Forbidden | UNKNOWN | Fixed rules, no ML/adaptive parameters, no grid/martingale, one position per magic. |

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1097_unger-gold-intraday-bias]] - bias-system family with intraday time slot rather than holiday calendar.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
