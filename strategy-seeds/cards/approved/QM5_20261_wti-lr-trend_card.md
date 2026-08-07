---
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_LR12R2_S14
variant_id: MOP-TSMOM-2012_XTI_LR12R2_S14
source_id: MOP-WTI-LRTREND-2026
ea_id: QM5_20261
slug: wti-lr-trend
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20261_wti-lr-trend_card.md
execution_contract_status: DRAFT
created: 2026-08-07
created_by: Research+Development
last_updated: 2026-08-07
g0_status: APPROVED
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI https://doi.org/10.1016/j.jfineco.2011.11.003; complete-paper evidence strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded extraction strategy-seeds/sources/MOP-WTI-LRTREND-2026/source.md"
    quality_tier: A
    role: primary_own_price_trend_and_monthly_cadence
strategy_mechanic: monthly-wti-thirteen-month-end-log-price-ols-slope-with-fixed-r-squared-path-quality-gate
sources:
  - "[[sources/MOP-WTI-LRTREND-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/trend-quality]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/ordinary-least-squares]]"
  - "[[indicators/month-end-close]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, structural-trend, path-consistency, monthly-rebalance, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 202610000
period: D1
timeframe: D1
expected_trade_frequency: "Estimated 6-10 completed monthly WTI positions/year after thirteen completed month ends; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify a direct WTI monthly path-quality trend whose OLS slope and fixed R-squared gate differ from endpoint momentum, return-sign, calendar, oscillator, and variance-ratio builds; Q09 alone may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [completed_month_reconstruction, regression_orientation, fixed_fit_threshold, monthly_attempt_state, risk_mode_dual, friday_close_disabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-07_qm5_20261_wti_lr_trend_g0.md: R1 one tier-A peer-reviewed complete-read source with explicit WTI membership; R2 locked thirteen completed month ends, oldest-to-newest log-price OLS slope, fixed R-squared 0.50 gate, monthly attempt, ATR stop, rollover, and stale exit; R3 registered XTIUSD.DWX D1 history; R4 deterministic native arithmetic only. Deterministic dedup scanned 4,318 registry rows and 435 cards with no exact collision; five lexical/source-family fuzzy neighbors were manually resolved, and a content scan found no existing WTI OLS slope plus fit-gate mechanic. No source efficacy or decorrelation transfers."
---

# QM5_20261 WTI Linear-Trend Quality

## Hypothesis

WTI can sustain slow price paths as supply investment, production policy,
inventory, transport, refining, hedging, and demand regimes adjust. A simple
endpoint return cannot distinguish a persistent path from one dominated by a
single jump. This card therefore trades monthly WTI trend direction only when
an ordinary least-squares fit to thirteen completed log-price endpoints has a
fixed minimum explanatory fit.

The crude-oil carrier is economically different from the certified XAU,
SP500, NDX, and XNG book. That does not prove decorrelation, profitability, or
portfolio suitability. Q02 owns density and economics; unchanged downstream
gates, including Q09, own robustness and realized book overlap.

## Source Traceability And Claim Boundary

The sole source of record is the governed bounded packet
`strategy-seeds/sources/MOP-WTI-LRTREND-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), a peer-reviewed *Journal of
Financial Economics* paper that documents monthly own-return continuation
through twelve lags and includes WTI among its commodity futures.

The source does not fit a log-price line or impose an `R^2` gate. The OLS path,
fixed fit threshold, Darwinex continuous CFD, broker-month reconstruction,
fixed-dollar sizing, ATR hard stop, spread cap, attempt ledger, and lifecycle
controls are transparent QM mechanizations. No source return, alpha, Sharpe
ratio, drawdown, trade count, cost, CFD equivalence, or correlation statistic
is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,318 EA-registry rows and 435 intake cards. It
found no exact slug or strategy-ID collision and returned five expected fuzzy
matches from shared WTI/trend language or the source family. Manual review
fixes the boundary:

- `QM5_12603_wti-tsmom12m` uses one endpoint-to-endpoint return sign.
- `QM5_20056_wti-dual-mom` and `QM5_20258_wti-mom-vote` combine cumulative
  return horizons rather than fitting the path between endpoints.
- `QM5_13150_wti-signmom` counts monthly return signs, and
  `QM5_20244_wti-trend-sign` requires that count to agree with cumulative
  return; neither uses regression residual dispersion.
- WTI moving-average, channel, variance-ratio, calendar, pullback, reversal,
  event, and relative-value EAs use different state variables or clocks.

A content scan found no WTI card requiring both log-price OLS slope and fixed
regression fit. The thirteen endpoints, oldest-to-newest orientation, slope
direction, `R^2 >= 0.50`, flat weak-trend state, consumed attempt, and monthly
renewal are jointly load-bearing. Verdict:
`CLEAN_AFTER_EXPECTED_FUZZY_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1; magic slot 0; intended magic `202610000`.
- Decision clock: first processed D1 bar after a genuine broker-month change.
- Formation: thirteen consecutive completed broker-month closes.
- Holding clock: next broker-month boundary, with a forty-calendar-day stale
  guard.
- Expected cadence: six to ten completed positions per full post-warm-up year;
  retire below five.
- Runtime data: native MT5 D1 time/close, ATR, spread, quote, position, deal,
  broker calendar, and contract metadata only.

## Formula

At the start of month `t`, let `P_0..P_12` be completed month-end closes from
months `t-13..t-1`, ordered oldest to newest. Define:

```text
x_i   = i
y_i   = ln(P_i)
x_bar = 6
y_bar = average(y_i)
Sxx   = sum((x_i - x_bar)^2)
Sxy   = sum((x_i - x_bar) * (y_i - y_bar))
Syy   = sum((y_i - y_bar)^2)
beta  = Sxy / Sxx
R2    = (Sxy * Sxy) / (Sxx * Syy)
```

Require `Sxx > 0`, `Syy > 0`, finite arithmetic, `abs(beta) > 1e-10`, and
`R2 >= 0.50`. BUY when beta is positive and SELL when beta is negative. A
weak, flat, malformed, or unavailable state consumes the month flat.

## Rules

The rules below are the complete authorized baseline. There is no parameter
sweep and no fallback to endpoint return, a moving average, oscillator,
calendar direction, external series, or previous pipeline result.

## 4. Entry Rules

1. Require exact EA ID `20261`, `XTIUSD.DWX` D1, magic slot 0, and every
   baseline input locked to its declared value.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current month as consumed before history, signal, spread,
   quote, news, stop, sizing, or order checks. No retry is allowed that month.
4. Reject an owned position or any same-month entry deal for the magic.
5. Reconstruct exactly thirteen completed month-end closes from bounded D1
   history. Require the newest endpoint to be the immediately prior month and
   every older key to be consecutive.
6. Reverse the endpoints to oldest-to-newest order, take natural logarithms,
   and calculate the fixed OLS statistics exactly as specified.
7. Continue only when beta is nonzero and `R2 >= 0.50`; use beta's sign as the
   order direction.
8. Require spread in `[0,1500]` points, executable quote, completed
   `ATR(20,D1)`, valid point/digit/volume metadata, and valid fixed-risk sizing.
9. Open at most one market position with a frozen `3.5 * ATR(20,D1)` hard
   stop and no take-profit.

## 5. Exit Rules

1. Close the prior position on the first processed D1 bar of each new broker
   month before considering replacement risk.
2. Close after forty elapsed calendar days as a stale guard.
3. Broker hard stops and the framework kill switch remain authoritative.
4. Friday close is disabled because the source-aligned hold spans weekends.
5. No intramonth signal flip, profit target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact symbol, timeframe, EA ID, magic slot, fixed risk,
  news/Friday contract, or locked strategy inputs.
- Reject a consumed attempt, owned exposure, same-month entry history,
  malformed or nonconsecutive endpoints, current-month leakage, nonpositive
  close, invalid logarithm, degenerate regression, weak fit, excessive spread,
  invalid quote, unavailable ATR, invalid stop, or invalid volume metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not read a futures chain, inventory release, volume, open
  interest, file, API, analyst forecast, trained output, or portfolio result.

## 7. Trade Management Rules

- Maintain at most one WTI position and one consumed attempt per broker month.
- Preserve the original hard stop; close before monthly renewal or after forty
  calendar days.
- Restart recovery combines a terminal-persistent month marker with owned
  position and deal history; tester initialization clears a future/prior-run
  marker so historical runs remain deterministic.
- No randomness, adaptive fitting, external state, partial close, scale-in,
  grid, martingale, or pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_regression_points` | 13 | [13] | completed month-end log-price observations |
| `strategy_min_r_squared` | 0.50 | [0.50] | fixed path-quality gate |
| `strategy_slope_epsilon` | 1e-10 | [1e-10] | deterministic flat-slope boundary |
| `strategy_history_bars_d1` | 800 | [800] | bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

The endpoint count, log transform, regression orientation, slope direction,
fit formula and threshold, entry clock, risk, stop, hold, and no-retry policy
are locked. Changing any of them requires a new card and full pipeline run.

## Author Claims

Moskowitz, Ooi, and Pedersen document time-series momentum across liquid
futures and identify WTI in their commodity universe. They do not claim that
this OLS-quality rule works, that `R^2 = 0.50` is optimal, that a continuous
CFD reproduces futures, or that the candidate diversifies the QM book.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: WTI gaps, CFD roll/basis and financing,
single-name concentration, path-gate sparsity, stale smooth trends, regression
sensitivity to large endpoints, stop-outs, and correlation with XNG or risk
assets can dominate the premise. `R^2` is a descriptive in-sample path measure,
not a forecast-confidence guarantee.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full
  post-warm-up year.
- Fail on wrong endpoint order, nonconsecutive months, current-month leakage,
  incorrect OLS or fit arithmetic, entry below the fit threshold, wrong-side
  entry, repeated monthly attempt, hold beyond forty days, missing hard stop,
  invalid risk mode, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing lookback, transform, fit threshold,
  direction, entry clock, stop, hold, spread cap, retry policy, or carrier.

## Strategy Allowability Check

- [x] R1: one tier-A peer-reviewed source with DOI, complete-paper evidence,
  and explicit WTI membership.
- [x] R2: fixed endpoints, regression formula, fit gate, direction, attempt,
  hard stop, rollover, and stale exit.
- [x] R3: registered `XTIUSD.DWX` D1 plus native V5 execution state only.
- [x] R4: deterministic logarithm, OLS, calendar, and ATR arithmetic; no
  trained model, banned signal indicator, external feed, grid, or martingale.
- [x] Dedup: no exact identity; all fuzzy neighbors manually resolved.

## Framework Alignment

- no_trade: exact WTI/D1/EA/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap parameter guards.
- trade_entry: month-attempt persistence, endpoint reconstruction, OLS and fit
  calculation, spread/quote/ATR/stop checks, and one fixed-risk order.
- trade_management: prior-month and stale exits before entry-only gates.
- trade_close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only research, deterministic allocation, build, strict
compile/Q01, and one non-live paced Q02 handoff. It does not authorize a manual
backtest; live, demo, shadow, optimization, or stress setfile; AutoTrading;
`T_Live`; deploy or T_Live manifest; portfolio admission; portfolio-gate edit;
or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-07 | initial source-bounded WTI linear-trend quality card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-07 | APPROVED | `decisions/2026-08-07_qm5_20261_wti_lr_trend_g0.md` |
| Q01 Build Validation | 2026-08-07 | NOT_RUN | pending deterministic allocation and strict compile |
| Q02 Baseline Screening | 2026-08-07 | NOT_ENQUEUED | pending Q01 PASS and paced-fleet capacity |
