---
ea_id: QM5_9351
slug: demark-td-demand-line-active-h4
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-strategies-and-systems]]"
concepts:
  - "[[concepts/trendline-breakout]]"
  - "[[concepts/demark-pivot-detection]]"
indicators:
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id 6e967762 present, attributing to the ForexFactory DeMark thread cluster with Thomas DeMark primary publications as named author lineage."
r2_mechanical: PASS
r2_reasoning: "TD-Point detection, active line construction, ATR-buffered penetration entry, DeMark projector TP, and N-bar-extreme SL are all closed-form closed-bar formulas."
r3_data_available: PASS
r3_reasoning: "TD-Lines require only OHLC price data and ATR, testable on all DWX FX majors and index CFDs."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed lookback periods and coefficients; no ML, adaptive equity-dependent parameters, or multi-position logic; one-position-per-magic enforced."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 60
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS cited ForexFactory URL plus DeMark books/Bloomberg lineage; R2 PASS closed-bar TD pivots, active lines, ATR-buffered entries, TP/SL/time exits with expected cadence >=2 trades/year/symbol; R3 PASS price-only H4 logic testable on DWX FX/CFD symbols with SP500.DWX caveat; R4 PASS fixed rules, "
---

# DeMark TD-Demand-Line Active-Update Breakout (H4)

## Quelle

- Source: [[sources/forexfactory-strategies-and-systems]]
- Primary URL: https://www.forexfactory.com/thread/post/13900000 (ForexFactory
  DeMark thread cluster, "DeMark Indicators — TD Lines, Active Update",
  2008-2026 archive).
- Author lineage: Thomas R. DeMark — *The New Science of Technical Analysis*
  (Wiley 1994) ch. 1 "TD Lines", *DeMark on Day Trading Options* (McGraw-Hill
  1999), *DeMark Indicators* (Bloomberg Press 2008) ch. 2. Bloomberg DeMark
  Studies module documentation.
- Sibling card: this is the continuously-updated variant of QM5_9281
  `demark-td-demand-supply-line-h4` and the H4 mirror of QM5_2409
  `demark-td-lines-active-h4`. Where 9281 locks the TD-line once two
  TD-Points are found, this card re-anchors the TD-line on every new
  qualifying TD-Point — i.e. the "active" DeMark concept.

## Mechanik

### TD-Point Detection (closed H4 bars only)

A TD-Demand-Point (low pivot) at bar `t` is defined by:

- `low[t] < low[t-1]` AND
- `low[t] < low[t+1]` (confirmation requires bar `t+1` closed — point
  identification is therefore valid only at the open of bar `t+2`).

Mirror: a TD-Supply-Point (high pivot) at bar `t` is:

- `high[t] > high[t-1]` AND
- `high[t] > high[t+1]`.

### Active TD-Demand-Line Construction

1. Walk back from the current bar.
2. Find the most-recent TD-Demand-Point: call it `D1` at bar `t1`,
   `low_value = L1`.
3. Find the next-most-recent TD-Demand-Point `D2` at bar `t2 < t1`,
   `low_value = L2`.
4. Validity gate: require `L1 < L2` — i.e. the most recent low is **lower**
   than the prior low (DeMark TD-Demand-Line direction: down-sloping demand
   line, the standard variant).
5. If valid, draw the TD-Demand-Line through `(t2, L2)` and `(t1, L1)`.
   Compute slope `m = (L1 − L2) / (t1 − t2)` (negative).
6. At each new closed H4 bar `t_now`, the TD-Demand-Line value is
   `TDD(t_now) = L1 + m · (t_now − t1)`.

**Active-update rule** (the differentiator vs. 9281):

- Re-scan every new closed H4 bar. If a NEW TD-Demand-Point appears that is
  *lower* than the current `D1`, promote: old `D1 → D2`, new point → new
  `D1`. Re-draw the line. The line is "alive" — it tracks the most recent
  two qualifying pivots, not a one-time lock.
- Validity also requires the TD-Demand-Line to currently sit BELOW market
  price at `t_now`. If `close[t_now] ≤ TDD(t_now)`, the line is broken (see
  entry).

Mirror logic for the active TD-Supply-Line (up-sloping, `H1 > H2` required).

### Entry

UP entry (TD-Supply-Line break, BULLISH):

- On the close of the H4 bar `t_now` such that:
  - `close[t_now] > TDS(t_now) + 0.10·ATR(14)` (clean break above the
    active TD-Supply-Line, 0.10 ATR penetration to filter false ticks).
  - Previous bar `close[t_now-1] ≤ TDS(t_now-1)` (must be a fresh break).
  - The TD-Supply-Line has been "alive" (continuously re-anchored or stable)
    for at least 3 closed H4 bars (avoids whipsaw on a newly-formed line).
- → BUY at next bar open.

DOWN entry (TD-Demand-Line break, BEARISH):

- On the close of bar `t_now` such that:
  - `close[t_now] < TDD(t_now) − 0.10·ATR(14)`.
  - `close[t_now-1] ≥ TDD(t_now-1)`.
  - Active for at least 3 closed H4 bars.
- → SELL at next bar open.

Magic = `9351 * 10000 + slot` (HR4).

### Exit

**TD Price Projector** (DeMark's measured-move target):

- For a TD-Supply-Line break, `TP = close[t_break] + (close[t_break] − L1)`
  where `L1` is the most recent TD-Demand-Point's low BEFORE the break.
- For a TD-Demand-Line break, `TP = close[t_break] − (H1 − close[t_break])`
  where `H1` is the most recent TD-Supply-Point's high BEFORE the break.

**Time stop:** exit at market if open beyond 40 closed H4 bars after entry.

### Stop Loss

- BUY: `SL = min(low[t_break−2], low[t_break−1], low[t_break]) − 0.30·ATR(14)`
  (the three-bar low surrounding the break, with ATR buffer — DeMark's
  "TD-Inverted-Lookback" SL school).
- SELL: `SL = max(high[t_break−2], high[t_break−1], high[t_break]) +
  0.30·ATR(14)`.

ATR(14) snapshot at entry, fixed.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD (HR4).
- Live: `RISK_PERCENT = 0.5%` (HR4).

### Zusätzliche Filter

- Spread filter: skip if spread > `0.15·ATR(14)`.
- One open position per magic. If a position is already open in the symbol,
  no new entry until close.
- News filter (P1 baseline): skip if HIGH-impact news on any quote currency
  within ±60 minutes of bar open.
- H4 only; no intra-bar entries.

## Concepts (was ist das für eine Strategie)

- [[concepts/trendline-breakout]] — primary
- [[concepts/demark-pivot-detection]] — secondary

## R1–R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | DeMark TD-Lines: published 1994 Wiley primary, 2008 Bloomberg Press secondary. Bloomberg DeMark Studies institutional adoption. ForexFactory thread cluster active 2008-2026. Named-author + multi-publication + institutional. R1 PASS. |
| R2 Mechanical | UNKNOWN | TD-Point detection = closed-bar pivot rules. Line construction = linear interpolation through two points. Active update = re-scan on each bar close. Entry = ATR-buffered penetration. TP = DeMark's projector formula. SL = N-bar extreme + ATR buffer. All closed-form. R2 PASS. |
| R3 Data Available | UNKNOWN | TD-Lines are price-only, instrument-agnostic. Testable on FX-majors, XAUUSD, XTIUSD, all major index CFDs H4. SP500.DWX backtest-only — T6 live promotion requires NDX.DWX or WS30.DWX parallel validation. R3 PASS. |
| R4 ML Forbidden | UNKNOWN | Fixed periods (14, 3, 40), fixed coefficients (0.10, 0.30). No adaptive params, no learning. 1-pos-per-magic. R4 PASS. |

### R3 SP500.DWX live-promotion caveat

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA
passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation
on NDX.DWX or WS30.DWX before AutoTrading enable. This is Board Advisor's
T6-gate enforcement, not Research's.

## Pipeline-Verlauf

- G0: 2026-05-19, PENDING — drafted by Research from
  6e967762-b26d-59a3-b076-35c17f2e7c36 Batch 56.

## Verwandte Strategien

- [[strategies/QM5_9281_demark-td-demand-supply-line-h4]] — locked-line
  variant: line anchored once two TD-Points found, no re-anchoring.
- [[strategies/QM5_2409_demark-td-lines-active-h4]] — sibling card on a
  different timeframe / different active-update granularity.
- [[strategies/QM5_2187_demark-td-trap-h4]] — DeMark TD-Trap sibling
  (different mechanic, same lineage).

## Lessons Learned (während Pipeline-Lauf)

- 2026-05-19: G0 distinctness audit must compare entry-rule trigger
  behaviour against QM5_9281 (locked variant) and QM5_2409 (other
  active variant) on H4 DWX data. The active-update rule changes the
  empirical break-frequency and break-timing materially.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
