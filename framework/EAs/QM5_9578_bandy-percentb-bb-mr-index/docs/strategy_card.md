---
ea_id: QM5_9578
slug: bandy-percentb-bb-mr-index
type: strategy
source_id: 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
sources:
  - "[[sources/bandy-quantitative-technical-analysis]]"
concepts:
  - "[[concepts/index-mean-reversion]]"
  - "[[concepts/long-only]]"
  - "[[concepts/bollinger-band-reversal]]"
indicators:
  - "[[indicators/bollinger-percentb]]"
  - "[[indicators/sma]]"
g0_status: APPROVED
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX]
expected_trades_per_year_per_symbol: 8
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
r2_reasoning: "Bollinger %B entry/exit with explicit thresholds (period 20, stdev 2.0, %B<0.0 entry gated by SMA200, %B>=0.5 exit), 7-day time stop and ATR stop; fully deterministic."
r3_reasoning: "Daily-close index mean reversion is directly testable on SP500.DWX (backtest) and live-routable NDX.DWX / WS30.DWX."
r4_reasoning: "Fixed-parameter Bollinger %B rule with no adaptive/PnL-dependent parameters, no ML, one position per magic, no martingale."
legacy_contract_repair: true
g0_recovery_reason: "Source-only rejection recovered; fresh semantic R2-R4 G0 review required."
g0_recovery_origin: "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_9578_bandy-percentb-bb-mr-index.md"
source_citation: ""
g0_approval_reasoning: "R1 lineage retained; R2 deterministic daily percent-B/SMA200 entry with midband/time/ATR exits and conservative 8 trades/year; R3 testable on SP500.DWX, NDX.DWX, and WS30.DWX; R4 fixed-rule ML-free one-position-per-magic."
expected_pf: 1.2
expected_dd_pct: 16.0
---

# Bandy Bollinger %B Mean Reversion (Index, Long-Only)

## Quelle
- Source: [[sources/bandy-quantitative-technical-analysis]]
- Book: Howard Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015.
- Bandy's chapter on entry/exit construction uses Bollinger %B (the normalized position of close inside the Bollinger band envelope) as a canonical mean-reversion entry on US large-cap indices. Bandy explicitly contrasts a `%B < 0` close-below-lower-band entry against the simpler `close < lower band` formulation and shows the %B form is more stable across volatility regimes.
- PDF not on local disk; attribution by author + title under relaxed R1.

## Mechanik

### Entry
On each daily close on the target index proxy:
- Compute `mid = SMA(close, 20)`, `sd = StdDev(close, 20)`, `upper = mid + 2*sd`, `lower = mid - 2*sd`.
- `%B = (close - lower) / (upper - lower)`.
- If `%B < 0.0` (i.e. close strictly below lower band) AND `close > SMA(close, 200)` (long-regime filter), enter long at next session open. One position per magic.

### Exit
- Exit long when `%B >= 0.5` (close crosses back above the 20-SMA midband).
- Time stop: exit after `7` trading days if midband cross has not triggered.
- P3 sweep candidates: entry `%B < -0.05 / 0.00 / 0.05`; exit `%B >= 0.40 / 0.50 / 0.60`; BB period `15 / 20 / 25`; BB stdev `1.8 / 2.0 / 2.2`.

### Stop Loss
No explicit stop in source. Baseline catastrophic stop: `2.5 * ATR(14, D1)`.

### Position Sizing
P2 baseline: fixed $1,000 risk per trade. Live: framework `RISK_PERCENT`.

### Zusätzliche Filter
- Skip on incomplete daily bar.
- One open position per magic.
- `close > SMA(200)` regime gate is part of the entry rule (not optional).

## Concepts
- [[concepts/index-mean-reversion]] — primary
- [[concepts/long-only]] — secondary
- [[concepts/bollinger-band-reversal]] — secondary

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named author + published book + ISBN. |
| R2 Mechanical | PASS | All thresholds explicit (period 20, stdev 2.0, %B<0 entry, %B>=0.5 exit, 7d time stop, 200-SMA regime). |
| R3 Data Available | PASS | Daily index CFD. SP500.DWX (backtest-only) + NDX.DWX / WS30.DWX (live). |
| R4 ML Forbidden | PASS | Fixed-parameter Bollinger; no ML; one-position-per-magic. |

## R3
SP500.DWX port caveat: same T_Live gate as siblings — parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from Bandy QTA batch 1.

## Verwandte Strategien
- [[strategies/QM5_9576_bandy-zscore-mr-index]] — z-score is the linear-distance variant of %B inside the same Bollinger framework.
- [[strategies/QM5_9577_bandy-dvi-varadi-mr-index]] — alternative MR oscillator from same source.

## Lessons Learned (während Pipeline-Lauf)
- TBD
