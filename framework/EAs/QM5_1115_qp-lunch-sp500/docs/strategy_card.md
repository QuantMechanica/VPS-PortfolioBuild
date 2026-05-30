---
ea_id: QM5_1115
slug: qp-lunch-sp500
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/intraday-seasonality]]"
  - "[[concepts/equity-index-timing]]"
indicators:
  - "[[indicators/new-york-session-clock]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 PASS Quantpedia URL and named author; R2 PASS fixed NY-time short/long schedule with time exits; R3 PASS SP500.DWX backtest-only with T6 NDX/WS30 caveat; R4 PASS fixed clock rules no ML/grid/martingale."
---

# Quantpedia Lunch Effect - SP500.DWX

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Lunch Effect in the U.S. Stock Market Indices"
- URL: https://quantpedia.com/lunch-effect-in-the-u-s-stock-market-indices/
- Citation verified 2026: Quantpedia URL above; source article names Cyril Dujava and references Cooper/Cliff/Gulen, Branch/Ma, and Parness.
- Named source author: Cyril Dujava, Quant Analyst, Quantpedia. The article references Cooper/Cliff/Gulen, Branch/Ma, and Michael Parness for related overnight/lunch-session context.

## Mechanik

### Entry
On each regular US equity trading day on SP500.DWX M60 or M15 bars:
1. At 11:00 New York time, open SHORT SP500.DWX.
2. At 12:00 New York time, close the short and immediately open LONG SP500.DWX.
3. At 14:00 New York time, close the long.
4. Do not hold outside the 11:00-14:00 New York window.

### Exit
- Time exit: close short at 12:00 New York time; close long at 14:00 New York time.
- Safety exit: close any still-open leg at 14:05 New York time if the scheduled close failed.

### Stop Loss
- Intraday ATR(14) hard stop at 1.5x M60 ATR from each leg entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per leg.
- Live: `RISK_PERCENT = 0.25` per leg.

### Zusaetzliche Filter
- Trade only regular US cash-session days; skip full holidays and early-close days unless the session calendar confirms the 14:00 close is valid.
- Skip if current spread is greater than 3x median M60 spread over the prior 20 trading days.
- Use broker time to New York time conversion from the validated DST calendar.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/intraday-seasonality]] - primary
- [[concepts/equity-index-timing]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia article URL is verifiable and names Cyril Dujava / Quantpedia. |
| R2 Mechanical | UNKNOWN | Fixed clock-time short, flip-to-long, and close schedule is deterministic. |
| R3 Data Available | UNKNOWN | Original article uses SPY/SPX and notes applicability to CFDs; SP500.DWX is available for T1-T5 backtest-only, with live caveat. |
| R4 ML Forbidden | UNKNOWN | Pure clock/session rule; no ML, no adaptive parameters, no grid/martingale. |

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1093_qp-preholiday-sp500]] - same SP500.DWX custom-symbol route, but calendar-day effect rather than intraday lunch pattern.
- [[strategies/QM5_1094_qp-fomc-sp500]] - same index timing family, but event-calendar driven.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
