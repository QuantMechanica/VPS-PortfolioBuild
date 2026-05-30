---
ea_id: QM5_1125
slug: unger-sp500-eom-pullback
type: strategy
source_id: eb97a148-0af9-5b9c-878c-25fb5dfa34f9
sources:
  - "[[sources/unger-robbins-cup]]"
concepts:
  - "[[concepts/seasonality]]"
  - "[[concepts/month-end-rally]]"
indicators:
  - "[[indicators/monthly-range]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "Unger Academy end-of-month-rally SP500/NDX/WS30 calendar pullback (Unger Academy book ISBN 978-8896590164 + 2 blog URLs) R1-R4 all PASS: R1 verifiable URLs + ISBN; R2 trading-day-to-month-end + prior-month-midpoint pullback + first-day-next-month exit + ATR(5)*2 stop fully deterministic; R3 SP500.DW"
---

# Unger SP500 End-of-Month Pullback - US Index Month-End Rally

## Quelle
- Source: [[sources/unger-robbins-cup]] - Unger Academy end-of-month rally article.
- Article: "The End-of-Month Rally" - https://ungeracademy.com/blog/end-of-the-month-rally
- Supporting article: "Trading the End-of-Month Rally" - https://ungeracademy.com/posts/trading-the-end-of-the-month-rally
- Location: transcription sections describing entry N trading days before month end, exit on first day of following month, pullback filter below half of prior monthly range, and ATR(5) x2 stop.
- Supporting source: *The Unger Method - Andrea Unger's Trading Method* (Unger Academy Publishing, 2nd ed. 2021, ISBN 978-8896590164).

## Mechanik

Universe: SP500.DWX backtest-only primary for S&P replication; NDX.DWX and WS30.DWX live-routable US-index ports. Execution timeframe D1.

### Entry
On each trading day:
1. Compute `TRADING_DAYS_TO_MONTH_END`.
2. If `TRADING_DAYS_TO_MONTH_END == 4`, evaluate setup. Source found this shorter-hold variant attractive versus the longer 13/16/21-day variants.
3. Compute previous calendar month's `MONTH_HIGH` and `MONTH_LOW`.
4. Compute `MIDPOINT = MONTH_LOW + 0.5 * (MONTH_HIGH - MONTH_LOW)`.
5. LONG at next open only if `Close[1] < MIDPOINT`, i.e. an end-of-month pullback exists.
6. No short trades.

### Exit
- Close on the first trading day of the following month.
- Close on stop loss first.
- Cancel setup if entry would occur after month end due to market holiday.

### Stop Loss
- Source safety stop: `SL = 2.0 * ATR(5,D1)` measured before entry.
- No default take profit; bias target is the month-end/turn-of-month window.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD per trade.
- Live: `RISK_PERCENT = 0.25%`.

### Zusaetzliche Filter
- Trade only US equity-index proxies; source explicitly says the effect works best on US stock markets and not on EuroFX/DAX tests.
- Skip if the next session's opening gap exceeds 1.5x the planned stop distance.
- Standard V5 spread/news filters.
- One position per magic.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/seasonality]] - primary
- [[concepts/month-end-rally]] - primary
- [[concepts/index-cfd]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Official Unger Academy URLs plus book ISBN. |
| R2 Mechanical | UNKNOWN | Calendar-day entry, prior-month midpoint pullback filter, first-day-next-month exit, ATR stop. |
| R3 Data Available | UNKNOWN | SP500.DWX is available for backtest-only S&P replication; NDX.DWX/WS30.DWX are live-routable ports. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. |
| R4 ML Forbidden | UNKNOWN | Fixed calendar/price rules, no ML/adaptive online parameters, no grid/martingale, one position per magic. |

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, awaiting QB verdict.

## Verwandte Strategien
- [[strategies/QM5_1124_unger-index-holiday-long]] - calendar-bias family with holiday rather than month-end timing.
- [[strategies/QM5_1098_unger-sp500-pivot-trend]] - US index intraday trend breakout, not calendar bias.

## Lessons Learned (waehrend Pipeline-Lauf)
- (noch keine)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Aenderung `pipeline_phase` aktualisieren + `last_updated`.*
