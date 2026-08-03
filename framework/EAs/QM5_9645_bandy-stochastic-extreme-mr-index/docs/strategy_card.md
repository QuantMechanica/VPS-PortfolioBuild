---
ea_id: QM5_9645
slug: bandy-stochastic-extreme-mr-index
type: strategy
source_id: 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
sources:
  - "[[sources/bandy-quantitative-technical-analysis]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/oscillator-extreme-fade]]"
indicators:
  - "[[indicators/stochastic]]"
  - "[[indicators/sma]]"
g0_status: APPROVED
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX]
expected_trades_per_year_per_symbol: 10
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
r2_reasoning: "Fully mechanical: explicit Stochastic(14,3,3) K/D entry thresholds, SMA200 regime gate, %K>=50 take-profit, 8-day time exit and 2.2xATR stop — no discretion, no ML."
r3_reasoning: "Daily-bar Stochastic/SMA/ATR indicators are testable on SP500.DWX, NDX.DWX and WS30.DWX, all present in dwx_symbol_matrix.csv with live-tradable index CFDs."
r4_reasoning: "Fixed-parameter closed-form oscillator, one position per magic, no pyramiding and no martingale — deterministic and ML-free."
legacy_contract_repair: true
g0_recovery_reason: "Source-only rejection recovered; fresh semantic R2-R4 G0 review required."
g0_recovery_origin: "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_9645_bandy-stochastic-extreme-mr-index.md"
source_citation: ""
g0_approval_reasoning: "R1 lineage retained; R2 deterministic dual-stochastic extreme plus SMA regime entry with explicit exits/SL and conservative 10 trades/year; R3 testable on SP500/NDX/WS30.DWX; R4 fixed-rule, ML-free, one-position-per-magic."
expected_pf: 1.2
expected_dd_pct: 17.0
---

# Bandy Stochastic Extreme Fade (Mean-Reversion, Long-Only, Index)

## Quelle
- Source: [[sources/bandy-quantitative-technical-analysis]]
- Book: Howard Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 978-0-9791037-7-1.
- Bandy presents the classic Lane Stochastic(14, 3) (slow K and D) as one
  of his mechanical MR oscillator exemplars on equity-index proxies. The
  Stochastic is structurally Williams %R smoothed by a 3-bar SMA on K and
  again on D — slower and noisier than %R(10), but a distinct fade
  family worth testing alongside CCI/%R/z-score. Bandy pairs the 20/80
  extremes with the same long-only regime gate (price > long SMA) he
  applies to all of his equity-index MR systems.
- PDF not on local disk; attribution by author + title under relaxed R1.

## Mechanik

### Entry
On each daily close on the target instrument:
- Compute Stochastic `%K = SMA(raw_K, 3)` where `raw_K = 100 * (close - LL(14)) / (HH(14) - LL(14))`.
- Compute `%D = SMA(%K, 3)` (Lane's slow Stochastic; %D is the trigger line).
- Compute regime filter `sma200 = SMA(close, 200, D1)`.
- If `%K <= 20` AND `%D <= 25` AND `close > sma200`, enter long at next session open.
  - The dual condition (both K and D below their thresholds) is Bandy's standard "confirmed-Stoch" trigger — using K alone is too noisy, K-and-D agreeing dampens whipsaws.
- Short side disabled (long-only).
- One position per magic; no pyramiding.

### Exit
- Take-profit: exit at next bar's close after `%K >= 50` (midline).
- Time exit: exit after `8` trading days if neither TP nor SL has triggered.
- Reverse-on-signal: disabled.
- P3 sweep candidates: K-period `9 / 14 / 21`; smoothing `1 / 3 / 5`; entry K-threshold `15 / 20 / 25`; entry D-threshold `20 / 25 / 30`; exit threshold `40 / 50 / 60`; time exit `5 / 8 / 12`; regime SMA `100 / 200 / 300`.

### Stop Loss
Hard SL: `2.2 * ATR(14, D1)` from entry. Stochastic 20/80 thresholds are
less stretched than CCI ±100 or z-score ±2, so the SL is sized between the
%R(10) tighter 2.0×ATR and the CCI 2.5×ATR.

### Position Sizing
P2: fixed $1,000 risk per trade based on the 2.2×ATR initial stop.
Live: `RISK_PERCENT`.

### Zusätzliche Filter
- Skip new entries on incomplete daily bar.
- Skip if `ATR(14) / close` is in the top 1st percentile over `252` bars.
- News filter: skip new entries within ±30 minutes of high-impact macro releases.

## Concepts
- [[concepts/mean-reversion]] — primary
- [[concepts/oscillator-extreme-fade]] — primary

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named Bandy book + ISBN. Lane Stochastic is the textbook oscillator; Bandy's contribution is the long-only regime-gated treatment on equity indices. |
| R2 Mechanical | PASS | Explicit K-period, smoothing, K-threshold, D-threshold, regime SMA, exit threshold, time exit, SL multiplier. |
| R3 Data Available | PASS | Daily-bar MR on index proxies. Backtests on SP500.DWX (Custom Symbol). Live promotion targets NDX.DWX and WS30.DWX. |
| R4 ML Forbidden | PASS | Fixed parameters; closed-form indicator; one position per magic; no pyramiding; no martingale. |

## R3
Tested on **SP500.DWX** Custom Symbol (backtest only). **T_Live live-
promotion gate (Board Advisor enforcement):** SP500.DWX is not broker-
routable on Darwinex. If the EA passes P0-P9 on SP500.DWX only, T_Live
deploy requires a parallel-validation on **NDX.DWX** or **WS30.DWX**
before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from Bandy QTA batch 2.

## Verwandte Strategien
- [[strategies/QM5_9642_bandy-williams-r-reversal-mr-index]] — %R(10) is structurally Stochastic raw-K without smoothing; sister MR.
- [[strategies/QM5_9641_bandy-cci-extreme-fade-mr-index]] — slower-stretched oscillator family (CCI), same regime-gate template.
- [[strategies/QM5_1235_connors-rsi2]] — momentum-extreme oscillator; orthogonal oscillator family.

## Lessons Learned (während Pipeline-Lauf)
- TBD
