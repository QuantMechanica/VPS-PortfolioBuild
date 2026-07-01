---
ea_id: QM5_9574
slug: demark-td-anti-diff-3bar-h4
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-strategies-and-systems]]"
concepts:
  - "[[concepts/demark-differential]]"
  - "[[concepts/reversal-pattern]]"
indicators:
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id UUID present; ForexFactory URL plus DeMark Wiley 1994/McGraw-Hill 1999 and Perl Bloomberg 2008 lineage — one canonical source."
r2_mechanical: PASS
r2_reasoning: "Four-bar monotone OHLC close inequalities plus ATR-normalized asymmetry filter fully specify entry; SL, 1.8R TP, and time stop are explicit."
r3_data_available: PASS
r3_reasoning: "H4 price-only classifier testable on DWX FX, metals, oil, and index CFD symbols."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed thresholds throughout; one position per magic; no ML, adaptive parameters, grid, or martingale."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 26
last_updated: 2026-05-19
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, USDCHF.DWX, NZDUSD.DWX, XAUUSD.DWX, XTIUSD.DWX, GDAXI.DWX, NDX.DWX, WS30.DWX, UK100.DWX, FRA40.DWX, JP225.DWX]
g0_approval_reasoning: "R1 PASS: ForexFactory URL plus DeMark/Perl book lineage; R2 PASS: deterministic H4 OHLC/ATR entry, SL, TP/time/opposite-trigger exits with ~26 trades/year/symbol; R3 PASS: price-only rules testable on DWX FX/CFDs; R4 PASS: fixed params, no ML/grid/martingale, one-position-per-magic."
---

# DeMark TD Anti-Differential 3-Bar Variant (H4)

## Quelle

- Source: [[sources/forexfactory-strategies-and-systems]]
- Primary URL: https://www.forexfactory.com/thread/post/14002880
  (ForexFactory Trading Systems sub-forum, DeMark indicators thread
  cluster, TD Anti-Differential variants, posts circa 2016-2025).
- Author lineage: Thomas R. DeMark -- *The New Science of Technical
  Analysis* (Wiley 1994), differential family foundation; Thomas
  DeMark -- *DeMark on Day Trading Options* (McGraw-Hill 1999), ch. 4;
  Jason Perl -- *DeMark Indicators* (Bloomberg Press 2008), ch. 9,
  extended TD Anti-Differential parameter sets.
- Distinctness sibling cards: QM5_1591 covers canonical TD
  Anti-Differential. This card uses Perl's 3-bar anti-differential
  setup with a stricter monotone precondition and ATR-normalized
  asymmetry filter.

## Mechanik

### Entry

All rules use closed H4 bars.

Long trigger:

1. Three-bar declining setup:
   `Close[t-3] > Close[t-2] > Close[t-1]`.
2. Bar `t` closes above bar `t-1`:
   `Close[t] > Close[t-1]`.
3. Anti-differential asymmetry:
   `(Close[t] - Close[t-1]) >= 0.60 * (Close[t-2] - Close[t-1])`.
4. Exhaustion floor: `Low[t-1] < Low[t-2]` AND
   `(High[t-1]-Low[t-1]) >= 0.7*ATR(14)[t-2]`.
5. Entry at next H4 bar open.

Short trigger mirrors the inequalities after three rising closes:
`Close[t-3] < Close[t-2] < Close[t-1]`, then `Close[t] < Close[t-1]`
with equivalent downside asymmetry.

Magic = `9574 * 10000 + slot`; one position per magic.

### Exit

- Primary TP: `1.8R`.
- Differential invalidation exit: close long if a fresh bearish TD
  Differential / Anti-Differential trigger appears before TP; mirror for
  short.
- Time stop: exit after 12 closed H4 bars.

### Stop Loss

- Long: `SL = min(Low[t-3], Low[t-2], Low[t-1], Low[t]) - 0.3*ATR(14)[t]`.
- Short: mirror above the four-bar high.

### Position Sizing

- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.5%` of equity at entry.

### Zusätzliche Filter

- Spread filter: skip if spread > `0.20*ATR(14)`.
- News filter: skip entries within +/-60 minutes of high-impact news.
- H4 closed-bar only; no pyramiding or averaging.
- Do not enter if the four-bar setup range exceeds `4.0*ATR(14)`;
  extreme news bars are excluded.

## Concepts (was ist das für eine Strategie)

- [[concepts/demark-differential]] -- primary.
- [[concepts/reversal-pattern]] -- secondary.

## R1-R4 Bewertung

| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | ForexFactory URL plus DeMark 1994 Wiley, DeMark 1999 McGraw-Hill and Perl 2008 Bloomberg Press lineage. |
| R2 Mechanical | UNKNOWN | Four-bar OHLC/close inequalities, ATR thresholds, explicit SL/TP/time stop. |
| R3 Data Available | UNKNOWN | Price-only H4 classifier; testable on DWX FX/CFD symbols. |
| R4 ML Forbidden | UNKNOWN | Fixed thresholds, no adaptive params, no ML, no grid/martingale, one-position-per-magic. |

### R3 SP500.DWX live-promotion caveat

Live promotion T_Live gate: SP500.DWX is not broker-routable. If the EA
passes P0-P9 on SP500.DWX only, T_Live deploy requires a
parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf

- G0: 2026-05-19, PENDING -- drafted by Research from source
  6e967762-b26d-59a3-b076-35c17f2e7c36 Batch 60.

## Verwandte Strategien

- [[strategies/QM5_1591_demark-td-anti-differential-h4]] -- canonical
  TD Anti-Differential. Distinct: 9574 requires a 3-bar monotone setup
  before the reversal bar and an ATR-normalized asymmetry floor.
- [[strategies/QM5_1581_demark-td-differential-h4]] -- base TD
  Differential.
- [[strategies/QM5_2351_demark-td-diff-rsi-h4]] -- RSI-input
  differential variant.

## Lessons Learned (während Pipeline-Lauf)

- 2026-05-19: Distinctness audit must compare trigger bars vs. QM5_1591.
  If 9574 is mostly a strict subset of 1591 without materially different
  P2 distribution, treat it as a parameter variant rather than a separate
  family member.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
