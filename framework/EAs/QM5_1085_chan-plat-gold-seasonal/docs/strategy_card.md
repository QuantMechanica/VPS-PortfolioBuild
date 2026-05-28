---
ea_id: QM5_1085
slug: chan-plat-gold-seasonal
type: strategy
source_id: fce67611-4e0f-5dce-8cff-c8b9dd84dd49
sources:
  - "[[sources/ernest-chan-blog]]"
concepts:
  - "[[concepts/seasonality]]"
  - "[[concepts/spread-trading]]"
indicators:
  - "[[indicators/calendar-window]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
card_body_incomplete: true
card_body_missing: "period"
g0_approval_reasoning: "Chan 2007 blog dated post R1; mechanical calendar Feb-26 entry / Apr-19 exit R2; platinum unavailable in DWX -> port to XAUUSD long / XAGUSD short same window per R3 relaxed-port; D1 ATR stop, fixed dates, no ML R4"
---

# Chan Platinum-Gold Seasonal Spread

## Quelle
- Source: [[sources/ernest-chan-blog]]
- Page / Timestamp: Ernest P. Chan, "Recap: Platinum-gold spread trade", 2007-04-27, https://epchan.blogspot.com/2007/04/recap-platinum-gold-spread-trade.html

## Mechanik

### Entry
Annually:
- On the configured seasonal entry date, open a long platinum / short gold spread.
- Default source-derived dates for first test: enter on February 26.
- Size legs by equal notional or volatility-adjusted notional.

### Exit
- Exit all legs on April 19.
- If either leg data is unavailable, skip the year.

### Stop Loss
- Source recap does not define a hard stop.
- Build default: D1 spread ATR stop and V5 risk cap.

### Timeframe
- D1 bars -- end-of-day evaluation of the long-platinum / short-gold spread; ATR(D1) for stop sizing.

### Position Sizing
- One bounded seasonal spread position per magic number.
- P2 baseline uses Fixed Risk $1,000 per V5 convention.

### Zusätzliche Filter
- Optional: only enter if 20-day platinum/gold spread momentum is not already extreme against the trade.
- No pyramiding or averaging-in.

## Concepts (was ist das für eine Strategie)
- [[concepts/seasonality]] -- primary
- [[concepts/spread-trading]] -- secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full URL, named author Ernest P. Chan, dated blog post. |
| R2 Mechanical | PASS | Calendar entry and exit dates are directly implementable. |
| R3 Data Available | UNKNOWN | Gold is available as `XAUUSD.DWX`; platinum availability is not confirmed in DWX. A precious-metals proxy port to `XAUUSD.DWX`/`XAGUSD.DWX` needs G0 approval. |
| R4 ML Forbidden | PASS | Fixed seasonal calendar spread; no ML, adaptive parameters, grid, or martingale. |

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, extracted by Research from Chan blog.

## Verwandte Strategien
- [[strategies/QM5_1083_chan-gld-gdx-z2]] -- precious-metals spread mean-reversion family.

## Lessons Learned (während Pipeline-Lauf)
- TBD

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
