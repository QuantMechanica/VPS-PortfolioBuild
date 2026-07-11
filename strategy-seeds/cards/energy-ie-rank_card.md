---
strategy_id: HAN-IE-2023_XTI_XNG_S01
source_id: HAN-IE-2023
ea_id: QM5_13141
slug: energy-ie-rank
status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
g0_status: APPROVED
source_citations:
  - type: paper
    citation: "Han, Yufeng; Mo, Xuan; Su, Zhi; and Zhu, Yifeng (2023). Is idiosyncratic asymmetry priced in commodity futures? Journal of Financial Research 46(3), 875-898."
    location: "Complete open paper; Sections 2.1, 3.1, 4.1, 5.1-5.3, 6, Equations 1 and 5, Table 1, Tables 5-8, Appendices A-B; DOI https://doi.org/10.1111/jfir.12339"
    quality_tier: A
    role: primary
strategy_type_flags: [symmetric-long-short, atr-hard-stop, time-stop]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13141_XTI_XNG_IE_D1
period: D1
expected_trade_frequency: "One XTI/XNG idiosyncratic-asymmetry package each broker calendar month after six completed months and at least 100 synchronized observations; approximately 12 packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.02
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
review_focus: "Falsify whether a fixed four-CFD commodity benchmark and two-energy-CFD rank preserve the source's idiosyncratic excess-tail-probability effect. Realized book orthogonality is unclaimed until Q09."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, benchmark_proxy, low_frequency, narrow_cross_section]
g0_approval_reasoning: "OWNER mission-directed G0 approval: complete peer-reviewed open source review; locked six-completed-month quadratic residualization, +/-0.5-sigma empirical IE rank, monthly paired hold, equal-notional guard, fixed-risk ATR stops, restart guard, and orphan cleanup; native registered D1 data, no ML/banned/external/grid/martingale logic. Four-CFD benchmark substitution and two-CFD breadth remain binding Q02 kill risks."
---

# XTI/XNG Monthly Idiosyncratic-Asymmetry Rank

## Hypothesis

Investors can overpay for commodity contracts whose idiosyncratic return
distribution offers relatively more large gains than large losses. The source
finds a negative cross-sectional relation between its distribution-based
idiosyncratic asymmetry statistic and subsequent commodity-futures returns.
This card expresses the structure as a monthly energy package: buy the lower-IE
XTI/XNG leg and short the higher-IE leg.

The package is opposite-side and approximately equal-notional, not guaranteed
beta, factor, or dollar neutral. Its driver is residual tail probability rather
than raw direction, RSI, trend, seasonality, or price-ratio reversion. Only
later portfolio evidence may establish realized correlation to the certified
XAU/SP500/NDX/XNG book.

## Source And Evidence Boundary

The canonical source is Han, Mo, Su, and Zhu (2023), *Journal of Financial
Research* 46(3), DOI `10.1111/jfir.12339`. The complete open published paper,
appendices, tables, and references were reviewed end to end. It:

- studies 27 commodity futures from January 1987 through May 2018;
- explicitly includes WTI crude oil and natural gas in its energy sector;
- removes commodity-market return and squared-return exposure from six months
  of daily returns;
- defines IE as large-gain probability minus large-loss probability beyond
  one-half residual standard deviation; and
- ranks contracts monthly, long low IE and short high IE.

The source uses S&P GSCI and broad tercile portfolios. The EA substitutes a
fixed equal-weight XTI/XNG/XAU/XAG factor and trades only the two energy legs.
It is a new carrier falsification, not a replication. No source performance,
alpha, drawdown, correlation, or cost number is imported.

## Concept And Formula

On the first tradable `XTIUSD.DWX` D1 bar of a broker month, collect common
completed D1 observations from exactly the six complete broker-calendar months
before the decision month. Simple close-to-close returns are used, matching the
source. For each common date:

    r_m[d] = 0.25 * (r_XTI[d] + r_XNG[d] + r_XAU[d] + r_XAG[d])

For each traded energy leg `i`, estimate one fixed three-parameter OLS model:

    r_i[d] = alpha_i + beta_i * r_m[d] + gamma_i * r_m[d]^2 + epsilon_i[d]

Let `mu_epsilon` and `sigma_epsilon` be the population mean and standard
deviation of the fitted residuals, and `z_i[d]` the standardized residual.

    IE_i = count(z_i >= +0.5) / N - count(z_i <= -0.5) / N

Direction is locked:

- `IE_XTI < IE_XNG`: BUY XTI and SELL XNG.
- `IE_XTI > IE_XNG`: SELL XTI and BUY XNG.
- tie within `1e-12`, singular regression, or invalid data: remain flat.

## Rules

The locked rule is a monthly low-IE-long/high-IE-short energy package using
the source's six-month quadratic residual design and empirical half-sigma tail
probabilities. The detailed market, entry, exit, filter, and management rules
follow.

## Markets And Timeframe

- Logical basket: `QM5_13141_XTI_XNG_IE_D1`.
- Host and traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Read-only factor members: `XAUUSD.DWX`, `XAGUSD.DWX`, D1.
- Formation: exactly the prior six completed broker months; current month and
  current D1 bar are excluded.
- Rebalance: first tradable D1 bar of every broker month.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, bounded across both legs.
- Runtime data: MT5-native D1 time/close, ATR, spread, broker calendar, deal
  history, position state, and contract metadata only.

## 4. Entry Rules

- Require exact host `XTIUSD.DWX`, timeframe D1, and magic slot 0.
- Detect a monthly transition from the current and prior completed host bars.
- Load at most `strategy_history_bars=220` completed D1 bars for all four
  registered symbols and retain only timestamps common to all four histories.
- Require all six expected previous month keys and at least
  `strategy_min_return_observations=100` synchronized simple returns.
- Reject nonpositive prices, mismatched return intervals, nonfinite arithmetic,
  singular/ill-conditioned OLS, nonpositive residual variance, or a numerical
  IE tie.
- Buy the lower-IE energy leg and short the higher-IE leg.
- Reject missing ATR, excess spread, invalid lot metadata, post-rounding
  notional mismatch above 20%, an existing package, or a month already entered.
- Scan current positions and entry deals so restart or one-leg stop cannot
  create another package in the same month.
- Split the fixed package stop-risk to target equal dollar notional after
  broker volume-step rounding and attach frozen `ATR(20) * 3.5` hard stops.
- If the second order fails, flatten the first leg immediately.

## 5. Exit Rules

- Close both legs on the first tradable D1 bar of the next broker month before
  evaluating a replacement package.
- Close both legs after `strategy_max_hold_days=40` as a stale time stop.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the source-aligned monthly hold.

## 6. Filters (No-Trade Module)

- Framework kill switch remains first and authoritative.
- Locked formula/window/threshold, exact host, synchronized history, expected
  month, observation count, regression condition, residual variance, spread,
  ATR, lot, notional, prior-attempt, magic, and composition checks fail closed.
- News compliance gates new entries for both traded symbols; lifecycle
  management and orphan cleanup remain active. Q02 disables both news axes.

## 7. Trade Management Rules

- Exactly two opposite-side energy legs with approximately equal notional and
  one shared fixed-risk budget.
- Close both legs together at monthly reset or 40-day stale limit; flatten any
  orphan or invalid composition on the next tick.
- No TP, trail, break-even, partial close, scale-in, grid, martingale,
  pyramiding, density estimation, kernel smoothing, external feed, GSCI series,
  adaptive PnL fit, banned indicator, PCA, or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_lookback_months` | 6 | [6] | source-aligned completed-month window |
| `strategy_history_bars` | 220 | [180, 220, 280] | bounded D1 retrieval buffer only |
| `strategy_min_return_observations` | 100 | [90, 100, 110] | synchronized-data floor |
| `strategy_tail_threshold_sigma` | 0.5 | [0.5] | source IE tail boundary |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg stop volatility estimate |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| `strategy_max_notional_mismatch_pct` | 20.0 | [10.0, 20.0, 30.0] | post-rounding neutrality guard |
| `strategy_max_hold_days` | 40 | [40] | stale guard around monthly reset |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG entry spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The six-month window, simple returns, equal-weight four-CFD factor, intercept +
linear + squared OLS design, population residual standardization, inclusive
`+/-0.5` empirical tail counts, low-minus-high direction, monthly renewal,
paired carrier, equal-notional target, and no same-month re-entry are locked.
Changing any requires a new card and full pipeline run.

## Author Claim

The authors find that "idiosyncratic asymmetry negatively and significantly
predicts commodity futures returns" (abstract). This source claim motivates a
queue candidate; it is not evidence for the two-CFD proxy carrier.

## Risk

### Initial Risk Profile And Kill Criteria

- `expected_pf: 1.02` is a low queue-ordering prior, not evidence.
- `expected_dd_pct: 30.0` reflects XNG gaps, legging, benchmark endogeneity,
  quadratic-regression instability, narrow rank, CFD basis, and month holds.
- Expected frequency is 12 packages/year after warm-up. Retire below five
  completed packages/year under the binding Q02 economic floor.
- Fail Q02 on zero trades, invalid logical-basket accounting, persistent
  notional mismatch, nondeterminism, orphan persistence, or risk-mode mismatch.
- Do not replace the benchmark, remove the squared term, move the 0.5 threshold,
  shorten the six-month window, add raw skew confirmation, or relax the
  neutrality guard to rescue a weak baseline.

## Strategy Allowability Check

- [x] Mechanical structural cross-sectional asymmetry-premium thesis.
- [x] Peer-reviewed open primary source, DOI, institutional copy, and complete
      source review.
- [x] No ML, density fit, banned indicator, external runtime feed, futures
      curve, grid, martingale, pyramiding, or adaptive PnL fitting.
- [x] D1/monthly expected density is 12 packages/year before Q02 validation.
- [x] Backtests use RISK_FIXED; no live setfile is authorized.
- [x] Friday-close exception is source-aligned and documented.
- [x] Canonical dedup fuzzy hits were manually reviewed and found mechanically
      distinct before atomic allocation.

## Non-Duplicate Decision

- `QM5_13118_energy-skew-rank`: raw third moment, no residual factor or
  distribution-tail count.
- `QM5_13133_energy-ivol`: residual standard deviation, no residual-tail sign
  distribution and no squared market term.
- `QM5_13139_energy-cv-rank`: 36-month variance/mean ratio, not daily IE.
- `QM5_13140_energy-aliq-rank`: return per tick-volume activity, not residuals.
- `QM5_13123_energy-val-rank`: multi-year price anchor, not asymmetry.
- `QM5_12567_cum-rsi2-commodity`: short-horizon long-only RSI pullback.

The dedup checker returned only fuzzy slug-token matches to CV and value ranks.
Manual signal-input, transform, direction, window, and exit review verdict:
`CLEAN_AFTER_MANUAL_REVIEW`.

## Framework Alignment

- no_trade: exact host/slot, locked estimator, synchronized bounded history,
  month coverage, observation floor, matrix condition, residual variance,
  spread, ATR, lot, notional, current-month attempt, magic, and package guards.
- trade_entry: six-month quadratic residual IE rank, equal-notional risk
  translation, paired orders, and frozen hard stops.
- trade_management: broker-month reset, 40-day stale close, restart-safe deal
  guard, composition validation, and orphan cleanup.
- trade_close: framework close helper plus broker-side hard stops.

No T_Live, AutoTrading setting, live setfile, deploy manifest, portfolio gate,
portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-11 | initial monthly XTI/XNG idiosyncratic-asymmetry basket | Q01 | IN_BUILD |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-11 | APPROVED by OWNER mission directive | this card |
| Q01 Build Validation | TBD | TBD | TBD |
| Q02 Baseline Screening | TBD | TBD | TBD |

## Lessons Captured

- 2026-07-11: A distribution-based residual-tail characteristic is distinct
  from raw skewness only when the factor proxy, quadratic residualization, and
  empirical threshold remain explicit and locked.
