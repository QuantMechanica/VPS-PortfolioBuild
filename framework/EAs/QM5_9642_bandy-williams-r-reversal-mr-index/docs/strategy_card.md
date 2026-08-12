---
ea_id: QM5_9642
slug: bandy-williams-r-reversal-mr-index
type: strategy
source_id: 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
sources:
  - "[[sources/bandy-quantitative-technical-analysis]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/oscillator-extreme-fade]]"
indicators:
  - "[[indicators/williams-r]]"
  - "[[indicators/sma]]"
g0_status: APPROVED
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX]
expected_trades_per_year_per_symbol: 12
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
r2_reasoning: "Williams %R(10) extreme entry gated by SMA200, explicit mid-range take-profit, 6-day time exit, ATR stop and vol-percentile/news filters; fully deterministic."
r3_reasoning: "Daily-close index oscillator fade is directly testable on SP500.DWX (backtest) and live-routable NDX.DWX / WS30.DWX."
r4_reasoning: "Fixed-parameter Williams %R rule with no adaptive/PnL-dependent parameters, no ML, one position per magic, no pyramiding or martingale."
legacy_contract_repair: true
g0_recovery_reason: "Source-only rejection recovered; fresh semantic R2-R4 G0 review required."
g0_recovery_origin: "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_9642_bandy-williams-r-reversal-mr-index.md"
source_citation: ""
g0_approval_reasoning: "R1 lineage retained; R2 deterministic daily Williams-percent-R/SMA200 fade with mid-range/time/ATR exits and conservative 12 trades/year after joint filters; R3 testable on SP500.DWX, NDX.DWX, and WS30.DWX; R4 fixed-rule ML-free one-position-per-magic."
expected_pf: 1.2
expected_dd_pct: 17.0
---

# Bandy Williams %R Reversal (Mean-Reversion, Long-Only, Index)

## Quelle
- Source: [[sources/bandy-quantitative-technical-analysis]]
- Book: Howard Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 978-0-9791037-7-1.
- Bandy presents Larry Williams' %R(10) as a faster cousin of RSI(2) /
  Stochastic — same mean-reverting intent, shorter lookback, different
  normalisation (range-position vs. up/down-momentum). Bandy specifically
  uses `-90` as the long-entry threshold and `-50` as the mid-range exit,
  paired with the long-only regime gate that he applies to all equity-
  index MR systems.
- PDF not on local disk; attribution by author + title under relaxed R1.

## Mechanik

### Entry
On each daily close on the target instrument:
- Compute `wr = WilliamsR(10, D1) = -100 * (HighestHigh(10) - close) / (HighestHigh(10) - LowestLow(10))` — ranges from `0` (at HH) to `-100` (at LL).
- Compute regime filter `sma200 = SMA(close, 200, D1)`.
- If `wr <= -90` AND `close > sma200`, enter long at next session open.
- Short side disabled (Bandy's long-only treatment for indices).
- One position per magic; no pyramiding.

### Exit
- Take-profit: exit at next bar's close after `wr >= -50` (back to mid-range).
- Time exit: exit after `6` trading days if neither TP nor SL has triggered.
- Reverse-on-signal: disabled (long-only).
- P3 sweep candidates: entry threshold `-80 / -90 / -95`; exit threshold `-50 / -30 / 0`; time exit `4 / 6 / 8 / 10`; %R period `5 / 10 / 14`; regime SMA `100 / 200 / 300`.

### Stop Loss
Hard SL: `2.0 * ATR(14, D1)` from entry. Williams %R reaches -90 on
ordinary 1-2 σ pullbacks (it's a range-position oscillator, not a
momentum-extreme oscillator), so a tighter SL than CCI's 2.5×ATR is
appropriate.

### Position Sizing
P2: fixed $1,000 risk per trade based on the 2.0×ATR initial stop.
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
| R1 Track Record | PASS | Named Bandy book + ISBN. |
| R2 Mechanical | PASS | Explicit %R period, entry threshold, exit threshold, time exit, regime SMA, SL multiplier. |
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
- [[strategies/QM5_9641_bandy-cci-extreme-fade-mr-index]] — slower oscillator family (CCI vs. %R), same regime-gate template.
- [[strategies/QM5_1235_connors-rsi2]] — Connors RSI(2); momentum-extreme oscillator, faster than %R(10) but conceptually adjacent.
- [[strategies/QM5_9645_bandy-stochastic-extreme-mr-index]] — sister Stoch(14,3) MR; Stochastic is %R + smoothing.

## Lessons Learned (während Pipeline-Lauf)
- TBD
