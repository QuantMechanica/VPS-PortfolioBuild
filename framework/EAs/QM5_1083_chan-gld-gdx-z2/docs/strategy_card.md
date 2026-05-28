---
ea_id: QM5_1083
slug: chan-gld-gdx-z2
type: strategy
source_id: fce67611-4e0f-5dce-8cff-c8b9dd84dd49
sources:
  - "[[sources/ernest-chan-blog]]"
concepts:
  - "[[concepts/pairs-trading]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/z-score-spread]]"
  - "[[indicators/half-life]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: UNKNOWN
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "R1 Chan 2006-11-17 blog post URL+author PASS; R2 z>=|2| entry z->0 exit + 3*half-life timeout deterministic PASS; R3 GLD/GDX unavailable, ported XAUUSD/XAGUSD metals proxy pair PASS; R4 fixed statistical rules no ML PASS"
---

# Chan GLD-GDX Two-Sigma Spread

## Quelle
- Source: [[sources/ernest-chan-blog]]
- Page / Timestamp: Chan, E.P. (2006) "Reader suggested a possible trading strategy with the GLD - GDX spread", epchan.blogspot.com (2006-11-17), URL: https://epchan.blogspot.com/2006/11/reader-suggested-possible-trading.html

## Timeframe / Bar Period
- Trading bar period: D1 (daily close evaluation).
- Lookback / hedge-ratio window: D1 rolling window (Chan default 90-100 D1 bars; build to expose as P3-sweepable).
- Target symbols (DWX port - GLD/GDX unavailable): XAUUSD.DWX (gold leg) vs XAGUSD.DWX (silver leg) as metals proxy pair; alternative XAUUSD.DWX vs XTIUSD.DWX cross-commodity pair.

## Mechanik

### Entry
Daily:
- Estimate hedge ratio between the two legs over a fixed lookback window.
- Compute spread = `leg_a_price - hedge_ratio * leg_b_price`.
- Compute spread z-score over the same lookback.
- If z-score <= -2, buy spread: long leg A, short hedge-adjusted leg B.
- If z-score >= +2, short spread: short leg A, long hedge-adjusted leg B.

### Exit
- Exit when spread z-score crosses 0.
- Also exit after `3 * estimated_half_life` bars if mean reversion has not occurred.

### Stop Loss
- Source emphasizes z-score entry and half-life; no hard SL specified.
- Build default: close if abs(z-score) exceeds 4 or portfolio loss reaches V5 risk cap.

### Position Sizing
- Hedge-ratio adjusted pair sizing.
- P2 baseline uses Fixed Risk $1,000 per V5 convention.

### Zusätzliche Filter
- Require spread stationarity/cointegration precheck on the lookback.
- One open pair position per magic number.

## Concepts
- [[concepts/pairs-trading]] - primary
- [[concepts/mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full URL, named author Ernest P. Chan, dated blog post. |
| R2 Mechanical | PASS | Z-score threshold entry and mean/half-life exits are implementable. |
| R3 Data Available | UNKNOWN | GLD/GDX are not DWX instruments. Closest port is metal pair testing such as `XAUUSD.DWX`/`XAGUSD.DWX`; exact miner hedge is unavailable. |
| R4 ML Forbidden | PASS | Fixed statistical spread rules; no ML/adaptive online learning. |

## Pipeline-Verlauf
- G0: 2026-05-17, PENDING, extracted by Research from Chan blog.
