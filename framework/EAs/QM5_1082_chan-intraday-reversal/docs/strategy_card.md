---
ea_id: QM5_1082
slug: chan-intraday-reversal
type: strategy
source_id: fce67611-4e0f-5dce-8cff-c8b9dd84dd49
sources:
  - "[[sources/ernest-chan-blog]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/intraday-reversal]]"
indicators:
  - "[[indicators/one-day-return-rank]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: UNKNOWN
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 URL to Chan blog; R2 mechanical prior-day rank entry at session open and flat by close; R3 testable on DWX indices incl SP500.DWX backtest with T6 caveat; R4 fixed non-ML single-basket logic."
expected_trades_per_year_per_symbol: 500
---

# Chan Intraday Cross-Sectional Reversal

## Quelle
- Source: [[sources/ernest-chan-blog]]
- Page / Timestamp: Ernest P. Chan, "How a mean-reversion strategy performed during the turmoil?", 2007-10-18, https://epchan.blogspot.com/2007/10/how-mean-reversion-strategy-performed.html

## Mechanik

### Entry
At the regular-session open:
- Use the prior completed daily bar to compute each symbol's close-to-close 1-day return.
- Rank the universe by that prior 1-day return.
- Buy the worst `N` performers and short the best `N` performers at/near the session open.
- Use equal dollar or equal volatility sizing per leg.

### Exit
- Exit all legs at the same session's close.
- No overnight hold.

### Stop Loss
- Source does not specify a stop.
- Build default: intraday ATR stop plus time exit at session close.

### Position Sizing
- Dollar-neutral long/short basket with equal allocation per selected leg.
- P2 baseline uses Fixed Risk $1,000 per V5 convention.

### Zusätzliche Filter
- Trade only after the first `M` minutes if opening spread is abnormal.
- Skip entries when a scheduled high-impact event is within the session window.

## Concepts (was ist das für eine Strategie)
- [[concepts/intraday-reversal]] — primary
- [[concepts/cross-sectional-reversal]] — secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full URL, named author Ernest P. Chan, dated blog post. |
| R2 Mechanical | PASS | Daily return ranking at open, long losers/short winners, flat by close. |
| R3 Data Available | UNKNOWN | Original source uses US equities. Port to DWX indices/FX/commodities needs session-open definition and universe selection. |
| R4 ML Forbidden | PASS | Fixed rank-and-hold intraday rule; no ML or adaptive parameters. |

## R3
Primary port candidates: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX` as an index basket; optionally add FX majors and metals if cross-asset ranks are acceptable.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, extracted by Research from Chan blog.

## Verwandte Strategien
- [[strategies/QM5_1081_chan-lo-1d-reversal]] — overnight/close-to-close sibling.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
