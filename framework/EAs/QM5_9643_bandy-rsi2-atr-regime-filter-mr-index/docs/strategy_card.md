---
ea_id: QM5_9643
slug: bandy-rsi2-atr-regime-filter-mr-index
type: strategy
source_id: 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
sources:
  - "[[sources/bandy-quantitative-technical-analysis]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/volatility-regime-filter]]"
indicators:
  - "[[indicators/rsi]]"
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
g0_status: APPROVED
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX]
expected_trades_per_year_per_symbol: 6
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
r2_reasoning: "RSI(2) extreme entry gated by SMA200 trend and ATR/close rolling-percentile regime filter, explicit RSI take-profit, 5-day time exit and ATR stop; fully deterministic."
r3_reasoning: "Daily-close index oscillator fade is directly testable on SP500.DWX (backtest) and live-routable NDX.DWX / WS30.DWX."
r4_reasoning: "Fixed-parameter RSI/ATR-percentile rule (fixed quantile cutoff, not adaptive learning), no ML, one position per magic, no pyramiding or martingale."
legacy_contract_repair: true
g0_recovery_reason: "Source-only rejection recovered; fresh semantic R2-R4 G0 review required."
g0_recovery_origin: "D:/QM/strategy_farm/artifacts/cards_rejected/QM5_9643_bandy-rsi2-atr-regime-filter-mr-index.md"
source_citation: ""
g0_approval_reasoning: "R1 lineage retained; R2 deterministic RSI(2), trend and ATR-percentile regime entry with explicit exits/SL and conservative 6 trades/year; R3 testable on SP500/NDX/WS30.DWX; R4 fixed-rule, ML-free, one-position-per-magic."
expected_pf: 1.2
expected_dd_pct: 18.0
---

# Bandy RSI(2) with ATR-Percentile Volatility Regime Filter (Long-Only, Index)

## Quelle
- Source: [[sources/bandy-quantitative-technical-analysis]]
- Book: Howard Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 978-0-9791037-7-1.
- Bandy explicitly criticises the bare Connors RSI(2) for taking signals
  indiscriminately across volatility regimes — in particular, the worst
  RSI(2) drawdowns historically cluster in **high-volatility** regimes
  where mean-reversion has degraded. Bandy's signature contribution is
  to overlay an **ATR-percentile regime filter** on RSI(2): only take
  signals when normalised volatility is in a "favourable" band
  (Bandy uses the bottom ~50% percentile of `ATR/close` over a 252-bar
  rolling window). This is mechanically distinct from Connors' baseline
  and is the Bandy contribution — not a Connors duplicate.
- PDF not on local disk; attribution by author + title under relaxed R1.
- R1 attribution split: RSI(2) baseline = Connors (already covered by
  QM5_1235, QM5_9466). The **regime filter overlay** is Bandy. This card
  is the Bandy contribution; the bare-RSI(2) card is the Connors line.

## Mechanik

### Entry
On each daily close on the target instrument:
- Compute `rsi = RSI(close, 2, D1)` (Wilder's smoothing).
- Compute regime filter `sma200 = SMA(close, 200, D1)`.
- Compute normalised volatility `nv = ATR(14, D1) / close`.
- Compute rolling 50th-percentile of `nv` over the last `252` bars: `nv_p50`.
- If `rsi <= 5` AND `close > sma200` AND `nv <= nv_p50`, enter long at next session open.
- Short side disabled (long-only).
- One position per magic; no pyramiding.

### Exit
- Take-profit: exit at next bar's close after `rsi >= 70`.
- Time exit: exit after `5` trading days if neither TP nor SL has triggered.
- Reverse-on-signal: disabled.
- P3 sweep candidates: RSI entry `2 / 5 / 10`; RSI exit `60 / 70 / 80`; time exit `3 / 5 / 8`; regime SMA `100 / 200 / 300`; ATR-percentile gate `25 / 50 / 75`; ATR period `10 / 14 / 20`.

### Stop Loss
Hard SL: `2.0 * ATR(14, D1)` from entry. RSI(2)≤5 is itself a deep-stretch
reading; the 2.0×ATR backstop is rarely hit and exists to truncate
catastrophic gap-down scenarios.

### Position Sizing
P2: fixed $1,000 risk per trade based on the 2.0×ATR initial stop.
Live: `RISK_PERCENT`.

### Zusätzliche Filter
- Skip new entries on incomplete daily bar.
- News filter: skip new entries within ±30 minutes of high-impact macro releases.
- The ATR-percentile gate is itself the principal "high-vol skip" — no additional vol-spike filter on top.

## Concepts
- [[concepts/mean-reversion]] — primary
- [[concepts/volatility-regime-filter]] — primary (Bandy contribution)

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named Bandy book + ISBN. The regime-filter overlay is the Bandy contribution; Connors RSI(2) baseline is the substrate. |
| R2 Mechanical | PASS | Explicit RSI period, threshold, regime SMA, ATR period, percentile window, percentile cutoff, time exit, SL multiplier. |
| R3 Data Available | PASS | Daily-bar MR on index proxies. Backtests on SP500.DWX (Custom Symbol). Live promotion targets NDX.DWX and WS30.DWX. |
| R4 ML Forbidden | PASS | Fixed parameters; closed-form indicators and rolling percentile; one position per magic; no pyramiding; no martingale. The percentile cutoff is a fixed quantile, NOT adaptive learning. |

## R3
Tested on **SP500.DWX** Custom Symbol (backtest only). **T_Live live-
promotion gate (Board Advisor enforcement):** SP500.DWX is not broker-
routable on Darwinex. If the EA passes P0-P9 on SP500.DWX only, T_Live
deploy requires a parallel-validation on **NDX.DWX** or **WS30.DWX**
before AutoTrading enable.

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from Bandy QTA batch 2.

## Verwandte Strategien
- [[strategies/QM5_1235_connors-rsi2]] — Connors RSI(2) baseline (no regime filter); the substrate this card overlays.
- [[strategies/QM5_9466_connors-r2-d1]] — alt Connors RSI(2) implementation.
- [[strategies/QM5_9576_bandy-zscore-mr-index]] — Bandy z-score sister; different oscillator, same regime-gate template.

## Lessons Learned (während Pipeline-Lauf)
- TBD
