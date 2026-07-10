---
ea_id: QM5_13116
slug: xng-signmom
type: strategy
strategy_id: PAPAILIAS-RSM-2021_XNG_S01
source_id: PAPAILIAS-RSM-2021
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
source_citation: "Papailias, Liu, and Thomakos (2021), Return Signal Momentum, Journal of Banking & Finance 124, 106063, DOI 10.1016/j.jbankfin.2021.106063."
source_citations:
  - type: paper
    citation: "Papailias, Fotis; Liu, Jiadong; and Thomakos, Dimitrios D. (2021). Return Signal Momentum. Journal of Banking & Finance 124, Article 106063."
    location: "Sections 2.1, 2.2, 4.1-4.2; Equations 7 and 10; Tables 1-2 and G.1-G.3; accepted manuscript https://pureadmin.qub.ac.uk/ws/files/229452162/RSM_011220.pdf"
    quality_tier: A
    role: primary
strategy_type_flags: [momentum, time-stop, symmetric-long-short, atr-hard-stop]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
period: D1
timeframes: [D1]
expected_trade_frequency: "One renewed XNG position per broker month after warm-up; approximately 12 completed trades/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.05
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
review_focus: "Adds an XNG sign-persistence trend driver mechanically opposite to QM5_12567's long-only RSI pullback; Q09 alone judges realized orthogonality."
g0_approval_reasoning: "Mission-directed G0: peer-reviewed source with XNG explicit; fixed mechanical monthly sign rule; native XNG D1; no ML/banned/external/grid/martingale; dedup clean."
---

# XNG Return-Sign Momentum

## Hypothesis And Source Boundary

Monthly return direction can persist when magnitude is noisy. The peer-reviewed
source tests a 55-futures universe with natural gas explicit in its 24-commodity
panel. It defines the signal as the equal-weight probability of positive signs
over 12 completed monthly returns and renews positions monthly. Diversified
futures results are not imported as a claim for the DWX CFD carrier.

## Entry

- On the first `XNGUSD.DWX` D1 bar of each broker month, retain the most recent
  completed close from each of the prior 13 distinct months.
- Convert the 12 monthly returns to `1` when non-negative and `0` when negative.
- BUY when their mean is at least fixed threshold `0.40`; otherwise SELL.
- Require valid history, arithmetic, spread, ATR, no existing position, and no
  prior attempt in the current month.
- Place a frozen `3.5 * ATR(20)` stop; no target.

## Exit And Management

- Close on the first tradable D1 bar of the next broker month or after 35 days.
- No same-month re-entry after a stop.
- No trailing, break-even, partial close, pyramiding, grid, martingale, adaptive
  threshold, external feed, or ML.
- Friday close is disabled to preserve the source's one-month hold; kill switch,
  stale close, monthly close, news entry compliance, and broker stop remain.

## Non-Duplicate Boundary

This is not `QM5_12567` long-only two-day cumulative-RSI pullback,
`QM5_12804` one cumulative 252-D1 magnitude-return signal, six-month reversal,
one-week momentum, breakout, seasonality, storage/COT/fundamental event, ratio,
carry, or return-spread logic. Pre-allocation dedup was `CLEAN`.

## Parameters To Test

| parameter | default | authorized range |
|---|---:|---|
| `strategy_lookback_months` | 12 | [12] |
| `strategy_positive_threshold` | 0.40 | [0.30, 0.40, 0.50] |
| `strategy_history_bars` | 500 | [400, 500, 650] |
| `strategy_atr_period` | 20 | [14, 20, 30] |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] |
| `strategy_max_hold_days` | 35 | [35] |
| `strategy_max_spread_points` | 3000 | [2000, 3000, 4500] |

## Risk, Kill Criteria, And Framework Alignment

- Q02 setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; expected approximately 12 trades/year.
- Retire below five trades/year; fail on zero trades, invalid month
  reconstruction, non-determinism, or risk mismatch. No post-baseline threshold
  widening or formation-window shortening.
- No-Trade: exact host/slot, parameters, month, history, spread, ATR, and
  position guards.
- Entry: 12-month positive-sign probability with fixed 0.40 threshold.
- Management/Close: monthly renewal, 35-day stale close, and ATR broker stop.
- No live setfile, T_Live/deploy manifest, portfolio gate, `T_Live`, or
  AutoTrading change is authorized.

## Pipeline

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 | 2026-07-10 | APPROVED | this card |
| Q01 | 2026-07-10 | PASS | `artifacts/qm5_13116_build_result.json` |
| Q02 | 2026-07-10 | ENQUEUED | `d3bef250-99ff-492c-b737-5eba646cff3e` |
