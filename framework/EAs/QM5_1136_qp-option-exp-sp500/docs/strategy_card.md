---
ea_id: QM5_1136
slug: qp-option-exp-sp500
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/calendar-effect]]"
  - "[[concepts/equity-index-timing]]"
indicators:
  - "[[indicators/options-expiration-calendar]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
card_body_incomplete: true
card_body_missing: "source_citation"
g0_approval_reasoning: "Quantpedia Option-Expiration Week (Stivers+Sun 2013 JBF 37(10) DOI 10.1016/j.jbankfin.2013.06.001) R1 named + R2 third-Friday calendar mechanical + R3 SP500.DWX backtest-only (T6 caveat NDX/WS30 parallel validation) + R4 no ML PASS"
---

# Quantpedia Option-Expiration Week Effect - SP500.DWX

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Option-Expiration Week Effect"
- URL: https://quantpedia.com/strategies/option-expiration-week-effect
- Named source authors: Stivers, Chris and Sun, Licheng (2013) "Returns and Option Activity over the Option-Expiration Week for S&P 100 Stocks", Journal of Banking & Finance 37(10), DOI:10.1016/j.jbankfin.2013.06.001 — Quantpedia summary page builds on this paper.
- Replication URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2014286

## Mechanik

### Entry
On each calendar month:
1. Compute the US equity option-expiration Friday as the third Friday of the month.
2. Open LONG SP500.DWX at the regular cash-session open on the Monday of the same week, or the next regular session if Monday is a full holiday.
3. Hold one active long slot only.

### Exit
- Close at the regular cash-session close on option-expiration Friday.
- If the Friday session is a full holiday, close at the prior regular session close.
- Safety exit: close at the next available bar if the scheduled close fails.

### Stop Loss
- Hard stop at 2.0x D1 ATR(20) from entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter
- Skip early-close sessions unless the validated US session calendar provides an executable close.
- Skip if spread is greater than 3x median M30 spread over the prior 20 trading days.
- Broker time must be converted to New York cash-session time via the validated DST calendar.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/calendar-effect]] - primary
- [[concepts/equity-index-timing]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia URL is verifiable and names Stivers and Sun as source-paper authors. |
| R2 Mechanical | UNKNOWN | Third-Friday option-expiration week entry and Friday close exit are deterministic calendar rules. |
| R3 Data Available | UNKNOWN | Source trades S&P 100/S&P equity exposure; SP500.DWX is available for T1-T5 backtest-only as broad US equity-index proxy. |
| R4 ML Forbidden | UNKNOWN | Fixed calendar rule with fixed stop; no ML, adaptive parameters, grid, or martingale. |

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1094_qp-fomc-sp500]] - same SP500.DWX event-calendar family, different event trigger.
- [[strategies/QM5_1131_qp-payday-sp500]] - same SP500.DWX calendar family, different month-day trigger.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
