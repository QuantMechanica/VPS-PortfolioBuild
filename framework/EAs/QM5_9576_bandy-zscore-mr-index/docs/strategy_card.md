---
ea_id: QM5_9576
slug: bandy-zscore-mr-index
type: strategy
source_id: 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
sources:
  - "[[sources/bandy-quantitative-technical-analysis]]"
concepts:
  - "[[concepts/index-mean-reversion]]"
  - "[[concepts/long-only]]"
  - "[[concepts/daily-swing]]"
indicators:
  - "[[indicators/zscore-rolling]]"
  - "[[indicators/sma]]"
  - "[[indicators/stdev]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 10
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX]
last_updated: 2026-07-26
r1_track_record: TIER_C
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
card_body_incomplete: true
card_body_missing: "legacy_contract_repair"
g0_rejection_reason: "SUPERSEDED: source-only rejection recovered under OWNER R1 policy on 2026-07-23; original retained in cards_rejected."
status: draft
r1_reasoning: "Existing attribution retained; R1 is informational and non-gating under OWNER policy 2026-07-23."
r2_reasoning: "Z-score entry/exit with explicit thresholds (SMA20/StdDev20, z<=-2.0 entry, z>=0.0 exit), 10-day time stop and ATR catastrophic stop; fully deterministic."
r3_reasoning: "Daily-close index mean reversion is directly testable on SP500.DWX (backtest) and live-routable NDX.DWX / WS30.DWX."
r4_reasoning: "Fixed-parameter Z-score rule with no adaptive/PnL-dependent parameters, no ML, one position per magic, no martingale."
legacy_contract_repair: true
g0_recovery_reason: "Source-only rejection recovered; fresh semantic R2-R4 G0 review required."
g0_recovery_origin: "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_9576_bandy-zscore-mr-index.md"
source_citation: ""
g0_approval_reasoning: "R1 lineage recorded; R2 deterministic D1 z-score extreme entry with mean/time/ATR exits and conservative 10 trades/year/symbol; R3 price-only index logic ports to SP500/NDX/WS30.DWX; R4 fixed-parameter, ML-free and one-position-per-magic."
expected_pf: 1.2
expected_dd_pct: 15.0
---

# Bandy Z-Score Mean Reversion (Index, Long-Only)

## Quelle
- Source: [[sources/bandy-quantitative-technical-analysis]]
- Book: Howard Bandy, "Quantitative Technical Analysis: An integrated approach to trading system development and trading management", Blue Owl Press, 2015 (ISBN 978-0-9791037-7-1).
- Chapters: System-development examples around mean-reversion baselines; Bandy uses Z-Score(close, 20) repeatedly as the canonical mean-reversion benchmark on US equity index ETFs (SPY/QQQ) when comparing system robustness across permutations.
- Author note: PDF not on local disk for this batch — attribution by author + title is sufficient under relaxed R1 (2026-05-15).

## Mechanik

### Entry
On each daily close on the target index proxy:
- Compute `mean = SMA(close, 20)` and `sd = StdDev(close, 20)`.
- `z = (close - mean) / sd`.
- If `z <= -2.0`, enter long at the next session open. One position per magic number.
- Long-only. No short-side mirror (Bandy notes the short mirror underperforms on US large-cap indices).

### Exit
- Exit long when `z >= 0.0` (mean-cross) at the close.
- Time stop: exit after `10` trading days if mean-cross has not triggered.
- P3 sweep candidates: exit threshold `z >= -0.5 / 0.0 / +0.5`; lookback `15 / 20 / 30`; time stop `5 / 10 / 15`.

### Stop Loss
No explicit stop in source. Baseline catastrophic stop: `3.0 * ATR(14, D1)` from entry close.

### Position Sizing
P2 baseline: fixed $1,000 risk per trade (HR4). Live P10 sizing: Bandy's `safef` fraction (bootstrap-bounded) is out of scope for V5; use the framework `RISK_PERCENT` default.

### Zusätzliche Filter
- Skip entries on incomplete daily bar.
- One open position per magic number.
- Optional P3 regime filter: only take entries when `close > SMA(close, 200)` (Bandy's "trade with the long-trend, fade only the short-term dislocation" guideline).

## Concepts (was ist das für eine Strategie)
- [[concepts/index-mean-reversion]] — primary
- [[concepts/long-only]] — secondary
- [[concepts/daily-swing]] — secondary

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named author + published book title (Howard Bandy, "Quantitative Technical Analysis", Blue Owl Press 2015, ISBN attached). Relaxed R1 accepts author+title without PDF on disk. |
| R2 Mechanical | PASS | Deterministic Z-Score entry/exit with concrete numerical thresholds; time stop and ATR catastrophic stop are explicit defaults under relaxed R2. |
| R3 Data Available | PASS | Long index mean-reversion testable on `SP500.DWX` (backtest-only) and live-routable on `NDX.DWX` / `WS30.DWX`. |
| R4 ML Forbidden | PASS | Fixed-parameter Z-Score rule; no ML, no adaptive parameters, no grid/martingale, one position per magic. |

## R3
SP500.DWX port caveat: "Live promotion T_Live gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T_Live deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable." Board Advisor enforces at T_Live gate.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from Bandy QTA batch 1.

## Verwandte Strategien
- [[strategies/QM5_1058_gatev-fx-pairs-zscore]] — pairs-cointegration zscore, different mechanic (cross-sectional spread, not single-asset).
- [[strategies/QM5_1223_bhatti-fx-zscore-mr]] — FX single-asset zscore-MR; this card is the index-CFD analogue.
- [[strategies/QM5_1336_chan-index-10d-low]] — Ernest Chan index N-day-low MR; same family, different entry trigger (rank vs. zscore).

## Lessons Learned (während Pipeline-Lauf)
- TBD
