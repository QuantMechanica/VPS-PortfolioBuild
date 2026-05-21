---
ea_id: QM5_9151
slug: chan-at-fstx-gap-mom
type: strategy
source_id: 307ac442-75f6-5323-819b-5d129d5383d0
sources:
  - "[[sources/chan-algorithmic-trading]]"
concepts:
  - "[[concepts/opening-gap-momentum]]"
  - "[[concepts/intraday-momentum]]"
  - "[[concepts/time-stop]]"
indicators:
  - "[[indicators/open-gap-return]]"
  - "[[indicators/rolling-standard-deviation]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 Chan Wiley book cited; R2 deterministic gap-threshold entry and same-session exit; R3 GBPUSD.DWX/index-CFD port testable; R4 fixed non-ML one-position rule."
---

# Chan AT FSTX Opening-Gap Momentum

## Quelle
- Source: [[sources/chan-algorithmic-trading]]
- Book: Ernest P. Chan, *Algorithmic Trading: Winning Strategies and Their Rationale*, Wiley Trading, 2013, ISBN 978-1-118-46014-6 / 978-1-118-46019-1.
- Page / Timestamp: Chapter 7, "Opening Gap Strategy", Example 7.1, printed/PDF pp. 156-157; local evidence `C:/QM/repo/strategy-seeds/sources/SRC05/raw/full_text.txt` lines 7012-7066.

## Mechanik

Target symbol / period: baseline on `GBPUSD.DWX` H1 using a deterministic virtual session open/close; index-CFD variants may use the mapped DWX index session.

### Entry
At the defined session open:
- Compute `stdretC2C90d = stdev(close_to_close_returns, 90)`, shifted back one completed bar.
- Compute `upper_trigger = prior_high * (1 + entry_z * stdretC2C90d)`.
- Compute `lower_trigger = prior_low * (1 - entry_z * stdretC2C90d)`.
- If `today_open > upper_trigger`, enter long at/near the session open.
- If `today_open < lower_trigger`, enter short at/near the session open.
- Source default `entry_z = 0.1`.

Source instruments are FSTX Dow Jones STOXX 50 futures and a GBPUSD variant with a virtual session open at 5:00 a.m. ET and close at 5:00 p.m. ET.

### Exit
- Exit the same position at that session's close.
- Do not hold overnight.
- No intraday reversal or second entry on the same session.

### Stop Loss
No stop loss is specified by the source. P1 baseline should add only a catastrophic intraday stop, for example `2.5 * ATR(14)` or a volatility-scaled stop based on `stdretC2C90d`, and leave optimization to P3.

### Position Sizing
Fixed $1,000 P2 risk-equivalent, one position per magic number.

### Zusätzliche Filter
- Require valid prior high/low, open, close, and 90 completed bars.
- Use a deterministic session definition per DWX symbol.
- Apply standard V5 news, spread, and Friday-close filters.

## Concepts (was ist das für eine Strategie)
- [[concepts/opening-gap-momentum]] - primary
- [[concepts/intraday-momentum]] - secondary
- [[concepts/time-stop]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named Wiley book by Ernest Chan with chapter, example, page, ISBN, and local raw-text evidence. |
| R2 Mechanical | PASS | Entry threshold, direction, volatility lookback, and same-session exit are fully mechanical. |
| R3 Data Available | UNKNOWN | GBPUSD.DWX is directly testable with a virtual session; the FSTX index-futures case needs a DWX index-CFD mapping such as STOXX50/EUSTX50 equivalent if available. |
| R4 ML Forbidden | PASS | Fixed rule set; no ML, online learning, adaptive parameters, martingale, or grid. |

## R3
DWX mapping candidates: `GBPUSD.DWX` for the FX variant, and an EU index CFD equivalent for FSTX if available. If mapped to an S&P-style index proxy, include the standard SP500.DWX live-promotion caveat.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from Chan AT farm continuation batch.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_9152_chan-at-buy-on-gap]] - opposite gap-fade direction on a cross-sectional stock universe.

## Lessons Learned (während Pipeline-Lauf)
- TBD
