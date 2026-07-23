---
strategy_id: MOP-TSMOM-2012_XCU_S05
source_id: MOP-TSMOM-2012
ea_id: QM5_20058
slug: xcu-tsmom3m
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
sources:
  - "[[sources/MOP-TSMOM-2012]]"
strategy_type_flags: [time-series-momentum, monthly-rebalance, atr-hard-stop, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XCUUSD.DWX]
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
review_focus: "Adds a medium-horizon Copper trend carrier to the XAU/SP500/NDX/XNG book; falsify costs, CFD/futures basis, trend whipsaw, and later book correlation."
g0_approval_reasoning: "APPROVED under the 2026-07-23 OWNER commodity-sleeve mission: peer-reviewed JFE commodity-futures lineage; deterministic monthly three-month return sign; registered XCU D1 carrier and twelve packages/year; no ML, banned indicator, external feed, grid, or martingale."
---

# Copper Three-Month Time-Series Momentum

## Hypothesis And Source Boundary

Moskowitz, Ooi and Pedersen document time-series momentum across liquid futures,
including commodities, over one-to-twelve-month formation horizons. This card
tests the sign of Copper's completed three-month return as a monthly directional
state on the continuous Darwinex CFD. The paper does not establish that this
particular CFD carrier, stop, spread cap, or post-publication sample is
profitable; Q02 and later gates must falsify those translations.

## Non-Duplicate Decision

No existing EA uses the completed three-month Copper return as its sole signal.
`QM5_12603` uses a 12-month return, while `QM5_12616` requires a 9-month signal
and uses three months only as same-sign confirmation. `QM5_13150` counts the
signs of twelve separate monthly returns. Event, calendar, inventory, reversal,
Donchian, RSI, and XCU/XNG relative-value builds have different triggers. This
card is therefore a distinct medium-horizon Copper state, not a parameter sweep of
an existing approved execution contract.

## Markets And Timeframe

- `XCUUSD.DWX`, D1, magic slot 0 only.
- Evaluate on the first tradable D1 bar of each broker month.
- Expected cadence is twelve renewed packages per complete year.
- Runtime inputs are MT5 D1 OHLC, ATR, spread, broker calendar, and
  position/deal state only.
- Backtest risk is `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Rules

The entry, exit, and management sections below are the complete authorized
baseline. Anything not stated there is out of scope.

## Entry Rules

- On the first D1 bar of a new broker month, close the prior package.
- Compare the prior completed D1 close with the completed close 63 D1 bars
  earlier.
- BUY when the log return is strictly positive; SELL when strictly negative;
  exact equality remains flat.
- Require valid history, prices, ATR(20), spread no greater than 1000 points,
  no open same-magic position, and no prior entry attempt for the month.
- Place a frozen hard stop at `3.5 * ATR(20)` from entry; no take-profit.

## Exit And Management Rules

- Close at the next monthly boundary before considering renewal.
- Close after 31 calendar days as a stale safety override.
- Friday close remains enabled.
- One position per magic; no scale-in, partial close, trail, break-even, grid,
  martingale, pyramiding, adaptive fit, external runtime feed, or ML.

## Parameters To Test

| parameter | default | authorized values |
|---|---:|---|
| `strategy_momentum_lookback_d1` | 63 | [63] |
| `strategy_min_abs_return_pct` | 0.0 | [0.0] |
| `strategy_atr_period` | 20 | [20] |
| `strategy_atr_sl_mult` | 3.5 | [3.5] |
| `strategy_max_hold_days` | 31 | [31] |
| `strategy_max_spread_points` | 1000 | [1000] |

All values are locked for Q02. A different horizon, threshold, confirmation,
or exit is a new card, not a rescue sweep.

## Kill Criteria

- Retire if Q02 realizes fewer than five completed packages per year.
- Fail on zero trades, incorrect month renewal, repeated same-month entry,
  nondeterministic reruns, risk mismatch, or governed PF/DD failure.
- Do not rescue failure by changing the horizon, adding a threshold or
  oscillator, or weakening execution controls.

## Strategy Allowability Check

- [x] R1: peer-reviewed Journal of Financial Economics source.
- [x] R2: fixed monthly three-month return-sign rule and deterministic exits.
- [x] R3: registered `XCUUSD.DWX` D1 carrier.
- [x] R4: deterministic and free of ML, banned indicators, grid, and martingale.
- [x] Exact and mechanic dedup searches are clean.

## Framework Alignment

- no_trade: exact symbol/timeframe/slot, locked inputs, history and spread.
- trade_entry: monthly sign of the completed 63-D1-bar log return.
- trade_management: monthly renewal and 31-day stale close.
- trade_close: framework strategy close or broker ATR stop.

## Risk And Safety Boundary

This authorization covers the card, build, strict compile, one RISK_FIXED
backtest setfile, and Q02 enqueue only. It does not authorize a live setfile,
T_Live access, AutoTrading, a deploy manifest, portfolio admission, a
portfolio-manifest edit, or a portfolio-gate change.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-23 | initial source-backed three-month Copper trend build | Q02 | pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-23 | APPROVED under OWNER commodity-sleeve mission | this card |
| Q01 Build Validation | 2026-07-23 | PENDING strict compile | `docs/ops/evidence/2026-07-23_qm5_20058_xcu_tsmom3m_q02_enqueue.md` |
| Q02 Baseline Screening | 2026-07-23 | pending, unclaimed | work item `425d98e6-2234-469b-9f49-ab5ae9da0d6f` |
