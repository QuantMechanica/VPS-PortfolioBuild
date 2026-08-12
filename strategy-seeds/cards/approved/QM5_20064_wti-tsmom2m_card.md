---
strategy_id: MOP-TSMOM-2012_XTI_S08
source_id: MOP-TSMOM-2012
ea_id: QM5_20064
slug: wti-tsmom2m
status: APPROVED
g0_status: APPROVED
created: 2026-07-23
created_by: Research+Development
last_updated: 2026-07-23
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; source packet strategy-seeds/sources/MOP-TSMOM-2012"
    quality_tier: A
    role: primary
strategy_type_flags: [time-series-momentum, monthly-rebalance, atr-hard-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Adds medium-horizon WTI trend exposure to the XAU/SP500/NDX/XNG book; unlike QM5_12567 it does not buy short-horizon RSI pullbacks. Q09 must still falsify realized correlation."
g0_approval_reasoning: "APPROVED under the 2026-07-23 OWNER commodity-sleeve mission: peer-reviewed JFE commodity-futures lineage; deterministic monthly two-month return sign; registered WTI D1 carrier and twelve packages/year; no ML, banned indicator, external feed, grid, or martingale."
---

# WTI Two-Month Time-Series Momentum

## Hypothesis And Source Boundary

Moskowitz, Ooi and Pedersen document time-series momentum across liquid futures,
including commodities, over one-to-twelve-month formation horizons. This card
tests the sign of WTI's completed two-month return as a monthly
directional state on the Darwinex CFD. The paper does not establish that this
specific CFD carrier, stop, or post-publication sample is profitable.

## Non-Duplicate Decision

`QM5_12567` is a short-horizon cumulative-RSI pullback strategy; this rule uses
no oscillator and can be long or short for an entire monthly package.
`QM5_12603` uses a 12-month WTI return sign, `QM5_20055` uses 63 D1 bars,
`QM5_20059` uses 126 D1 bars, and `QM5_12780` requires a 252-D1 price anchor.
This card uses the unconditional sign of the completed 42-D1 return, with no
anchor or volatility-regime filter. WTI calendar, seasonal, spread, and
reversal EAs have different clocks and triggers.

## Markets And Timeframe

- `XTIUSD.DWX`, D1, magic slot 0 only.
- Evaluate on the first tradable D1 bar of each broker month.
- Expected cadence is twelve renewed packages per complete year.
- Runtime data is limited to MT5 D1 closes, ATR, spread, broker calendar, and
  position state.
- Backtest risk is `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Rules

The entry, exit, and management sections below are the complete authorized
baseline. Anything not stated there is out of scope.

## Entry Rules

- On the first D1 bar of a new broker month, close the prior package.
- Compare the prior completed D1 close with the completed close 42 D1 bars
  earlier.
- BUY when the log return is positive; SELL when negative; equality stays flat.
- Require valid history, ATR(20), spread no greater than 1000 points, no open
  same-magic position, and no prior entry attempt for the month.
- Place a frozen hard stop at `3.5 * ATR(20)` from entry; no take-profit.

## Exit And Management Rules

- Close at the next monthly boundary before renewal.
- Close after 31 calendar days as a stale safety override.
- Friday close remains enabled.
- One position per magic; no scale-in, partial close, trail, break-even, grid,
  martingale, pyramiding, adaptive fit, external runtime feed, or ML.

## Parameters To Test

| parameter | default | authorized values |
|---|---:|---|
| `strategy_momentum_lookback_d1` | 42 | [42] |
| `strategy_min_abs_return_pct` | 0.0 | [0.0] |
| `strategy_atr_period` | 20 | [20] |
| `strategy_atr_sl_mult` | 3.5 | [3.5] |
| `strategy_max_hold_days` | 31 | [31] |
| `strategy_max_spread_points` | 1000 | [1000] |

All Q02 values are locked. A different horizon, threshold, confirmation, or
exit is a new card, not a rescue sweep.

## Kill Criteria

- Retire if Q02 realizes fewer than five completed packages per year.
- Fail on zero trades, incorrect renewal, repeated same-month entry,
  nondeterminism, risk mismatch, or governed PF/DD failure.
- Do not rescue failure by adding an oscillator, threshold, volatility corridor,
  or parameter sweep.

## Strategy Allowability Check

- [x] R1: one peer-reviewed Journal of Financial Economics source.
- [x] R2: fixed monthly return-sign rule and deterministic exits.
- [x] R3: registered `XTIUSD.DWX` D1 carrier.
- [x] R4: deterministic and free of ML, banned indicators, grid, martingale.
- [x] Mechanic and repository dedup searches are clean.

## Framework Alignment

- no_trade: exact symbol/timeframe/slot and locked inputs.
- trade_entry: monthly sign of completed 42-D1-bar log return.
- trade_management: monthly renewal and 31-day stale close.
- trade_close: framework strategy close or broker ATR stop.

## Risk And Safety Boundary

This authorization covers the card, build, strict compile, one RISK_FIXED
backtest setfile, and Q02 enqueue only. It does not authorize a live setfile,
T_Live access, AutoTrading, deploy manifest, portfolio admission, portfolio
manifest edit, or portfolio-gate change.

## Falsification

Q02 kills the edge on insufficient frequency, PF/DD failure, invalid timing,
or risk-contract breach. Q09 correlation is authoritative; different logic is
not assumed to imply low realized correlation.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-23 | initial source-backed two-month WTI trend build | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-23 | APPROVED under OWNER commodity-sleeve mission | this card |
| Q01 Build Validation | 2026-07-23 | PASS: strict compile and build check, 0 errors/0 warnings | `docs/ops/evidence/2026-07-23_qm5_20064_wti_tsmom2m_q02_enqueue.md` |
| Q02 Baseline Screening | 2026-07-23 | pending, unclaimed | work item `d80fe226-7093-4fcc-bdf6-050c812cccd3` |
