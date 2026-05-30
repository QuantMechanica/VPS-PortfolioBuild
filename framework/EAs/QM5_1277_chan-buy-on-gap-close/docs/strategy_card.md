---
ea_id: QM5_1277
slug: chan-buy-on-gap-close
type: strategy
source_id: fce67611-4e0f-5dce-8cff-c8b9dd84dd49
sources:
  - "[[sources/ernest-chan-blog]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/gap-fade]]"
  - "[[concepts/intraday-close-exit]]"
indicators:
  - "[[indicators/open-gap-return]]"
  - "[[indicators/rolling-standard-deviation]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: UNKNOWN
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "Ernie Chan 2012-04-20 epchan.blogspot.com 'Life and death of a strategy' buy-on-gap SD90-mean-reversion - R1 named-author public-blog URL + 2012 timestamp; R2 fully explicit (gap_return < -1*SD90 entry / same-day close exit / 2*SD90 catastrophic stop default); R3 ports to SP500.DWX directional proxy"
---

# Chan Buy-On-Gap Close Exit

## Quelle
- Source: [[sources/ernest-chan-blog]]
- Blog URL: https://epchan.blogspot.com/2012/04/life-and-death-of-strategy.html
- Archive URL containing the full visible post: https://epchan.blogspot.com/2012/
- Article: "The life and death of a strategy", Ernest/Ernie Chan, 2012-04-20.
- Page / Timestamp: Section defining "buy-on-gap" using previous day's low to current day's open, 90-day standard deviation, and same-day close exit.

## Mechanik

### Entry
At each session open:
- Source universe: S&P 500 stocks. DWX port: index CFDs only, or an approved CFD cross-section if G0 allows multi-instrument ranking.
- Compute gap return: `(today_open - prior_day_low) / prior_day_low`.
- Compute `SD90`: 90-day moving standard deviation of close-to-close returns.
- Select instruments where `gap_return < -1.0 * SD90`.
- Source simple version buys the 100 S&P 500 stocks with the lowest qualifying gap returns. DWX baseline can trade the single most negative qualifying instrument per EA instance, or SP500.DWX as a directional proxy when the aggregate index opens below its prior low by more than `SD90`.
- Enter long at/near the open.

### Exit
- Exit all positions at the same trading day's close.

### Stop Loss
No explicit stop in source. P1 default: intraday catastrophic stop at `2 * SD90` adverse move from entry, swept in P3 if baseline survives.

### Position Sizing
Source was long-only basket. V5 P2 uses fixed $1,000 risk equivalent; for index-proxy port, one position per magic number.

### Zusätzliche Filter
- Trade only when valid open, prior low, and 90-day return history exist.
- No overnight holding; force flat before the session close.
- DWX index-CFD implementation must define session open/close deterministically per broker/server time.

### Period / Timeframe
- D1 bars for the open/low/close levels and 90-day rolling SD calculation.
- Execution-frame implementation note: the EA may run on a lower MT5 timeframe (e.g. M5) for precise session-open entry and session-close exit, but all signal inputs (gap_return, SD90, prior_day_low) are derived from D1 closes.

## Concepts (was ist das für eine Strategie)
- [[concepts/mean-reversion]] - primary
- [[concepts/gap-fade]] - secondary
- [[concepts/intraday-close-exit]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public Ernest Chan blog post with visible author/date and exact rule text. |
| R2 Mechanical | PASS | Entry gap, 90-day volatility threshold, long direction, and same-day close exit are explicit. |
| R3 Data Available | UNKNOWN | Original strategy ranks S&P 500 stocks; port to SP500.DWX or a DWX CFD universe needs G0 approval. |
| R4 ML Forbidden | PASS | Fixed rule; no ML, no online adaptation, no grid/martingale. |

## R3
SP500.DWX port caveat: "Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable."

## Pipeline-Verlauf
- G0: 2026-05-18, PENDING, drafted from Ernest Chan blog batch 2.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_1082_chan-intraday-reversal]] - earlier Chan same-day cross-sectional reversal variant.

## Lessons Learned (während Pipeline-Lauf)
- TBD
