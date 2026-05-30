---
ea_id: QM5_1131
slug: qp-payday-sp500
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/calendar-effect]]"
  - "[[concepts/equity-index-timing]]"
indicators:
  - "[[indicators/trading-day-calendar]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "Quantpedia Payday Anomaly Ma+Pratt 2014 SSRN 2501931 / IJFE 2017 SP500 mid-month 16th-day-long calendar effect intraday entry/exit + ATR(D1,20)*1.5 stop R1-R4 all PASS: R1 verifiable Quantpedia URL + named source authors + SSRN DOI + year-tagged; R2 fixed calendar-day entry + same-day cash-close exi"
---

# Quantpedia Payday Anomaly - SP500.DWX

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Payday Anomaly" (Quantpedia encyclopedia entry, 2024 review).
- URL: https://quantpedia.com/strategies/payday-anomaly
- Named source authors: Ma, Aixin and Pratt, William Robert, 2014, "Payday Anomaly", SSRN 2501931 (working-paper version published as "The Payday Effect on Stock Indices", *International Journal of Finance and Economics*, 2017). DOI: https://doi.org/10.2139/ssrn.2501931 — also accessible via Quantpedia summary URL above.

## Mechanik

### Entry
On each calendar month:
1. If the 16th calendar day is a regular US equity trading day, open LONG SP500.DWX at the first valid cash-session bar on the 16th.
2. If the 16th is a weekend or full exchange holiday, use the next regular US equity trading day.
3. Hold only one active long slot.

### Exit
- Close the position at the regular cash-session close of the entry day.
- Safety exit: close at the next available bar if the scheduled close fails.

### Stop Loss
- Intraday hard stop at 1.5x D1 ATR(20) from entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter
- Skip US full holidays and early-close sessions unless the validated session calendar provides an executable close.
- Skip if spread is greater than 3x median M30 spread over the prior 20 trading days.
- Broker time must be converted to New York cash-session time via the validated DST calendar.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/calendar-effect]] - primary
- [[concepts/equity-index-timing]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia URL is verifiable and names Ma and Pratt as source-paper authors. |
| R2 Mechanical | UNKNOWN | Fixed calendar-day entry and same-day exit are deterministic. |
| R3 Data Available | UNKNOWN | Source trades S&P 500; SP500.DWX is available for T1-T5 backtest-only. |
| R4 ML Forbidden | UNKNOWN | Calendar rule with fixed stop; no ML, adaptive parameters, grid, or martingale. |

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1049_mcconnell-turn-of-month]] - same broad calendar family, but this card trades the mid-month payday effect rather than turn-of-month.
- [[strategies/QM5_1093_qp-preholiday-sp500]] - same SP500.DWX route, different calendar trigger.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
