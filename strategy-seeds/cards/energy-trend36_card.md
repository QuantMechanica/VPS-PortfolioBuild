---
strategy_id: HOLLSTEIN-3YR-2021_XTI_XNG_S01
source_id: HOLLSTEIN-3YR-2021
ea_id: QM5_13149
slug: energy-trend36
status: APPROVED
created: 2026-07-12
created_by: Research
last_updated: 2026-07-12
g0_status: APPROVED
source_citations:
  - type: paper
    citation: "Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021). Anomalies in Commodity Futures Markets. Quarterly Journal of Finance 11(4), article 2150017."
    location: "Complete 57-page accepted manuscript and online appendix; especially pp. 5-15, Appendix B p. 28, Table 4 Panel C, and Online Appendix Tables A1, A3-A5; DOI https://doi.org/10.1142/S2010139221500178"
    quality_tier: A
    role: primary
strategy_type_flags: [signal-reversal-exit, atr-hard-stop, time-stop, symmetric-long-short]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13149_XTI_XNG_TREND36_D1
period: D1
expected_trade_frequency: "One XTI/XNG 36-month relative-trend package per broker calendar month after 37 completed month-end closes; approximately 12 completed packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Falsify whether a 36-completed-month average-return high-minus-low rank survives as a monthly XTI/XNG package. The directly relevant source two-portfolio result and cross-sectional slope are insignificant; no efficacy or book orthogonality is claimed."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, low_frequency, narrow_cross_section]
g0_approval_reasoning: "APPROVED under the OWNER commodity-sleeve mission: R1 complete peer-reviewed article and online appendix; R2 locked 36-completed-month arithmetic average of simple returns, high-minus-low monthly direction, equal fixed risk, hard stops, restart-safe no-reentry, and orphan cleanup; R3 native registered XTI/XNG D1 data; R4 no ML, banned indicator, external runtime feed, grid, martingale, or pyramiding. Canonical exact dedup is clean and same-paper fuzzy matches were manually resolved as different mechanics. The insignificant two-portfolio source result, broad-to-two-CFD narrowing, continuous-CFD basis, and legging are binding Q02 kill risks."
---

# XTI/XNG Monthly 36-Month Relative Trend

## Hypothesis

Long-horizon commodity relative performance may persist because slow-moving
supply investment, hedging demand, and risk-premium regimes adjust over years.
This card buys whichever of WTI crude oil or natural gas has the higher average
monthly return over the prior 36 completed months and shorts the lower-return
leg for one broker month.

Opposite directions and equal fixed-risk halves reduce outright energy
direction. They do not guarantee dollar, beta, volatility, factor, or realized
market neutrality. Later portfolio gates alone may establish correlation to
the certified XAU/SP500/NDX/XNG book.

## Source And Evidence Boundary

Hollstein, Prokopczuk, and Tharann (2021), *Anomalies in Commodity Futures
Markets*, studies 26 collateralized futures including WTI crude oil and natural
gas. It defines the source-labelled `3Y Reversal` characteristic as the average
commodity-futures excess return over the prior 36 months and tests monthly
high-minus-low portfolios.

The label is potentially misleading: the source's actual tested direction is
long the high characteristic and short the low characteristic. This card calls
that rule 36-month relative trend. It does not reverse the source direction to
make the name fit.

Evidence is weak for the narrow carrier. The three-portfolio high-minus-low
mean is positive and only weakly significant; the two-portfolio result most
relevant to two legs is positive but insignificant; the cross-sectional slope
is insignificant; and subperiod evidence is unstable. Q02 receives a low prior
and owns the first evidence for the CFD translation.

## Concept And Formula

On the first tradable host D1 bar of broker month `t`, collect the last close
from each of the 37 completed broker months ending at `t-1`. For each leg `i`:

```text
r_i[m]       = month_close_i[m] / month_close_i[m-1] - 1
avg36_i      = sum(r_i[m], m=1..36) / 36
```

- `avg36_XTI > avg36_XNG`: BUY XTI and SELL XNG.
- `avg36_XTI < avg36_XNG`: SELL XTI and BUY XNG.
- Numerical tie, missing month, invalid close, or nonfinite result: remain
  flat.

The arithmetic mean and simple-return definition preserve the source
characteristic as closely as native CFD closes permit. There is no z-score,
ratio, variance, beta, carry, reversal, fixed-origin normalization, or entry
threshold.

## Markets And Timeframe

- Logical basket: `QM5_13149_XTI_XNG_TREND36_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Signal data: 37 consecutive completed broker-month-end D1 closes per leg;
  current bars and the current month are excluded.
- Rebalance: first tradable D1 host bar of every broker month.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split equally across both legs.
- Runtime data: native MT5 D1 closes, ATR, spread, broker calendar, deal
  history, position state, and contract metadata only.

## Rules

The following entry, exit, filter, and lifecycle rules are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

- Require exact host `XTIUSD.DWX`, timeframe D1, and magic slot 0.
- Detect the first tradable D1 host bar of each broker month using completed
  host-bar dates; do not depend on MN1 history.
- For each leg, collect the latest completed D1 close from each of 37
  consecutive broker months. Fail closed if a whole month is absent.
- Calculate exactly 36 simple monthly returns and their arithmetic average.
- Buy the higher-average-return leg and short the lower-average-return leg;
  reject an absolute average-return difference at or below `1e-10`.
- Reject invalid history, nonpositive closes, arithmetic failure, invalid
  ATR/price/lot metadata, excess spread, an existing package, or a broker month
  already entered.
- Scan positions and entry deals so restart or a stopped leg cannot create a
  second package in the same month.
- Split fixed package risk equally and attach a frozen `ATR(20) * 3.5` hard
  stop to each leg. If the second order fails, flatten the first immediately.

## 5. Exit Rules

- Close both legs on the first tradable D1 host bar of the next broker month
  before evaluating a replacement package.
- Close both legs after `strategy_max_hold_days=40` as a stale time stop.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the declared monthly hold.

## 6. Filters (No-Trade Module)

- Framework kill switch remains first and authoritative.
- Exact host, locked window, bounded completed-bar history, calendar
  continuity, finite arithmetic, spread, ATR, lot, month-attempt, magic, and
  package checks fail closed.
- News compliance gates new entries for both symbols; lifecycle management and
  orphan cleanup remain active. Q02 disables both news axes.

## 7. Trade Management Rules

- Exactly two opposite-side legs use equal fixed-risk shares.
- One paired package per broker month; a stopped or missing leg does not
  authorize same-month re-entry.
- No TP, trail, break-even, partial close, scale-in, grid, martingale,
  pyramiding, external feed, futures chain, banned indicator, adaptive PnL fit,
  or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_return_window_months` | 36 | locked | source-defined completed monthly-return count |
| `strategy_history_bars` | 1200 | [1000, 1200, 1400] | bounded D1 retrieval buffer only |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg stop volatility estimate |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| `strategy_max_hold_days` | 40 | locked | stale guard around monthly reset |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The 36-return window, simple-return arithmetic mean, high-minus-low direction,
monthly cadence, equal half-risk carrier, and no same-month re-entry are
locked. Changing any requires a new card and full pipeline run.

## Author Claim

The paper reports a "positive mean return of 2.36% p.a." for the 36-month
three-portfolio sort (accepted manuscript p. 14). This short claim motivates
queue admission only; it does not validate the two-CFD carrier.

## Risk And Kill Criteria

- `expected_pf: 1.01` is a deliberately low queue-ordering prior, not evidence.
- `expected_dd_pct: 30.0` reflects XNG gaps, legging, two-name concentration,
  long formation, continuous-CFD basis, and weak source robustness.
- Expected density is twelve packages/year after warm-up. Retire below five
  completed packages/year under the binding Q02 economic floor.
- Fail Q02 on zero trades, invalid logical-basket accounting, nondeterminism,
  persistent orphan exposure, incomplete month history, or risk mismatch.
- Do not shorten the formation window, flip the direction, add a threshold,
  change the return definition, or relax package/history guards to rescue weak
  economics.
- The broad-to-two-name narrowing, insignificant two-portfolio result,
  futures/CFD basis, collateral omission, financing, gaps, legging, and costs
  are kill risks, never waiver grounds.

## Strategy Allowability Check

- [x] Mechanical structural long-horizon relative-trend thesis.
- [x] Complete peer-reviewed primary source and online appendix reviewed.
- [x] No banned indicator, ML, external runtime feed, futures-chain data,
      grid, martingale, pyramiding, or adaptive PnL fitting.
- [x] D1/monthly expected density is twelve packages/year before Q02.
- [x] Backtests use RISK_FIXED; no live setfile is authorized.
- [x] Friday-close exception is source-translation aligned and documented.
- [x] Exact dedup clean; same-paper fuzzy matches manually resolved.

## Non-Duplicate Decision

- `QM5_12386_comm-mom12m` and `QM5_13121_energy-tfmom`: 12-month momentum,
  not 36 completed monthly returns.
- `QM5_13120_energy-momrev`: conditional 12/18-month rank disagreement, not
  one unconditional 36-month high-minus-low rank.
- `QM5_13123_energy-val-rank`: 54-66-month price-anchor value, not average
  monthly return.
- `QM5_13148_energy-rank-lmh`: immutable-origin normalized price rank, not a
  rolling formation window.
- `QM5_12934_aa-comm-spot-rev-card`: one-year contrarian direction across four
  commodities, not 36-month energy continuation.
- `QM5_12567_cum-rsi2-commodity`: two-day long-only RSI pullback.

The canonical pre-allocation checker returned three same-author/source fuzzy
matches. Manual formula/input/direction/window review verdict:
`FUZZY_SAME_SOURCE_MANUALLY_RESOLVED_DISTINCT`.

## Framework Alignment

- no_trade: exact host/slot, locked window, bounded completed-bar history,
  calendar continuity, finite arithmetic, spread, ATR, lot, magic, package,
  and prior-attempt guards.
- trade_entry: monthly 36-return high-minus-low rank, paired orders, equal
  fixed-risk allocation, and frozen hard stops.
- trade_management: next-month close, 40-day time stop, restart-safe deal
  guard, composition validation, and orphan cleanup.
- trade_close: framework close helper plus broker-side hard stops.

No T_Live, AutoTrading setting, live setfile, deploy manifest, portfolio gate,
portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-12 | initial 36-month XTI/XNG relative-trend basket | Q02 | Q01 build pending |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-12 | APPROVED under OWNER commodity-sleeve mission; R1-R4 and dedup clean | this card |
| Q01 Build Validation | - | pending | - |
| Q02 Baseline Screening | - | pending enqueue | - |

## Lessons Captured

- 2026-07-12: Preserve the source's tested high-minus-low direction even when
  its variable name says reversal; code and card names must describe mechanics.
