---
strategy_id: YIYI-ES-2025_XTI_XNG_S02
source_id: YIYI-ES-2025
ea_id: QM5_13143
slug: energy-es-rank
status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
g0_status: APPROVED
source_citations:
  - type: paper
    citation: "Qin, Yiyi; Cai, Jun; Zhu, Jie; and Webb, Robert (2025). Commodity Futures Characteristics and Asset Pricing Models. Journal of Futures Markets 45(3), 176-207."
    location: "Complete open paper; data and characteristic construction pp. 13-15, one-way sorts pp. 15-17 and Table 3, IPCA tests Sections 6.3-6.5, conclusion pp. 30-31, Appendix A pp. 61-63; DOI https://doi.org/10.1002/fut.22559"
    quality_tier: A
    role: primary
strategy_type_flags: [symmetric-long-short, atr-hard-stop, time-stop]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13143_XTI_XNG_ES_D1
period: D1
expected_trade_frequency: "One XTI/XNG expected-shortfall package each broker calendar month after 12 completed months and at least 220 valid daily returns; approximately 12 packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
review_focus: "Falsify whether the source's lower-tail risk characteristic survives as a monthly opposite-side XTI/XNG carrier. It adds downside-tail compensation rather than index, metal, RSI, trend, or seasonality exposure; realized book orthogonality is unclaimed until Q09."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, low_frequency, narrow_cross_section]
g0_approval_reasoning: "OWNER mission-directed G0 approval: peer-reviewed primary source and complete open paper; locked prior-12-completed-month average-worst-5%-return estimator, high-ES/low-ES paired direction, monthly hold, equal fixed risk, frozen ATR stops, restart guard, and orphan cleanup; native registered D1 data, no ML/banned/external/grid/martingale logic. Weak full-sample one-way source significance, broad-universe narrowing, and continuous-CFD basis remain binding Q02 kill risks."
---

# XTI/XNG Monthly Expected-Shortfall Rank

## Hypothesis

Commodity contracts with more severe trailing downside tails can carry
different latent risk exposures from contracts whose worst daily outcomes are
less severe. The source identifies expected shortfall as one of the small set
of characteristics consistently associated with commodity latent-factor
loadings. This card expresses that structure as a monthly energy package: buy
the higher expected-shortfall XTI/XNG leg and short the lower one.

Expected shortfall is a negative return statistic here. Higher means a less
damaging lower tail. The opposite-side package reduces common energy direction
but is not guaranteed dollar, beta, volatility, or factor neutral. Only later
portfolio evidence may establish realized correlation to the certified
XAU/SP500/NDX/XNG book.

## Source And Evidence Boundary

The canonical source is Qin, Cai, Zhu, and Webb (2025), Journal of Futures
Markets 45(3), DOI 10.1002/fut.22559. The complete open paper, appendices,
tables, and bibliography were reviewed. It studies 34 commodity futures from
January 1981 through June 2022, measures characteristics before prediction
month t, and defines expected shortfall from the lower 5% of the prior twelve
months of daily returns.

The evidence is deliberately bounded:

- Table 3 reports a positive broad-universe high-minus-low ES return, but its
  full-sample t-statistic is only 1.36.
- The one-way result was stronger in the early sub-sample and is not treated
  as timeless alpha.
- ES remains important in the source's IPCA loading tests, but the EA does not
  implement IPCA or claim latent-factor replication.
- The source ranks broad exchange-traded futures; this card ranks only two
  continuous broker CFDs.

No paper performance, alpha, drawdown, correlation, or cost number is imported
into expected results or portfolio evidence.

## Concept And Formula

On the first tradable XTIUSD.DWX D1 bar of each broker month, select simple
close-to-close returns whose ending bars belong to exactly the twelve fully
completed broker calendar months before the decision month. For each leg i:

    N_i = count(valid daily returns in the twelve complete months)
    K_i = ceil(N_i * 0.05)
    ES_i = arithmetic mean of the K_i lowest daily returns

Direction is locked to the source's high-minus-low sort:

- ES_XTI greater than ES_XNG: BUY XTI and SELL XNG.
- ES_XTI less than ES_XNG: SELL XTI and BUY XNG.
- A numerical tie, missing expected month, insufficient observations,
  nonpositive price, or invalid arithmetic remains flat.

The deterministic ceiling rule includes at least 5% of observations and is
the declared finite-sample implementation detail.

## Markets And Timeframe

- Logical basket: QM5_13143_XTI_XNG_ES_D1.
- Host and traded slot 0: XTIUSD.DWX, D1.
- Traded slot 1: XNGUSD.DWX, D1.
- Formation: exactly the prior 12 completed broker calendar months; current
  month and current D1 bar are excluded.
- Rebalance: first tradable D1 bar of every broker month.
- Backtest risk: RISK_FIXED=1000, RISK_PERCENT=0,
  PORTFOLIO_WEIGHT=1, split equally across both legs.
- Runtime data: MT5-native D1 close/time, ATR, spread, broker calendar, deal
  history, position state, and contract metadata only.

## Rules

The following entry, exit, filter, and lifecycle rules are the complete
authorized baseline. Anything not stated here is out of scope.

## 4. Entry Rules

- Require exact host XTIUSD.DWX, timeframe D1, and magic slot 0.
- Detect a monthly transition from the current and prior host D1 bars.
- For both legs, scan at most strategy_history_bars=400 completed D1 bars and
  accept returns only when their ending bar is in one of the prior twelve
  expected month keys.
- Require each expected month to contribute at least one return and each leg
  to have at least strategy_min_daily_observations=220 returns.
- Sort each return array ascending, set K to ceil(N times 0.05), and average
  exactly the lowest K values.
- Buy higher ES and short lower ES.
- Reject a numerical tie, missing/nonpositive close, invalid return, invalid
  ATR/price/lot metadata, excess spread, existing package, or a calendar month
  already entered.
- Scan positions and entry deals so restart or a stopped leg cannot create
  another package in the same month.
- Split fixed package risk equally and attach a frozen ATR(20) times 3.5 hard
  stop to each leg.
- If the second order fails, immediately flatten the first leg.

## 5. Exit Rules

- Close both legs on the first tradable D1 bar of the next broker month before
  evaluating a replacement package.
- Close both legs after strategy_max_hold_days=40 as a stale time stop.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the source-aligned monthly hold.

## 6. Filters (No-Trade Module)

- Framework kill switch remains first and authoritative.
- Parameter, exact-host, history, calendar coverage, observation, tail-count,
  arithmetic, spread, ATR, lot, month-attempt, magic, and composition checks
  fail closed.
- News compliance gates new entries for both symbols; lifecycle management and
  orphan cleanup remain active. The Q02 structural setfile disables both news
  axes.

## 7. Trade Management Rules

- Exactly two opposite-side legs use equal fixed-risk shares.
- No TP, trail, break-even, partial close, scale-in, grid, martingale,
  pyramiding, regression, IPCA, PCA, external feed, futures curve, banned
  indicator, adaptive PnL fit, or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| strategy_es_window_months | 12 | [12] | source-defined completed-month window |
| strategy_tail_probability | 0.05 | [0.05] | source-defined lower-tail fraction |
| strategy_history_bars | 400 | [350, 400, 500] | bounded D1 retrieval buffer only |
| strategy_min_daily_observations | 220 | [200, 220, 240] | data-sufficiency floor |
| strategy_atr_period_d1 | 20 | [14, 20, 30] | per-leg stop volatility estimate |
| strategy_atr_sl_mult | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| strategy_max_hold_days | 40 | [40] | stale guard around monthly reset |
| strategy_xti_max_spread_pts | 1500 | [1000, 1500, 2500] | XTI spread cap |
| strategy_xng_max_spread_pts | 3000 | [2000, 3000, 4500] | XNG spread cap |
| strategy_deviation_points | 20 | [10, 20, 50] | basket order deviation |

The twelve-month window, simple returns, 5% lower-tail mean, ceiling count,
high-minus-low direction, monthly renewal, equal half-risk carrier, and no
same-month re-entry are locked. A different quantile, winsorization, ES trend
filter, residualized tail, direction reversal, or shorter window requires a
new card and full pipeline run.

## Author Claim

The source defines ES as the "average of the worst 5% returns" (paper p. 15).
Its conclusion identifies expected shortfall among three significant
commodity characteristics. These source claims motivate a queue candidate;
they do not validate the two-CFD carrier.

## Risk

## Initial Risk Profile And Kill Criteria

- expected_pf 1.01 is a low queue-ordering prior, not evidence.
- expected_dd_pct 30.0 reflects XNG gaps, legging, tail-estimator instability,
  two-name rank flips, continuous-CFD basis, and month-long holds.
- Expected density is twelve packages/year after warm-up. Retire below five
  completed packages/year under the binding Q02 economic floor.
- Fail Q02 on zero trades, invalid logical-basket accounting, nondeterminism,
  persistent orphan exposure, incomplete calendar coverage, or risk mismatch.
- Do not change the tail fraction, reverse direction, shorten the window, add
  momentum/skew filters, or relax package guards to rescue a weak baseline.
- The source's weak one-way full-sample ES result is a kill risk, never a
  waiver argument.

## Strategy Allowability Check

- [x] Mechanical structural downside-tail risk-premium thesis.
- [x] Peer-reviewed primary source, DOI, open complete paper, and precise
      reproducible locations.
- [x] No ML, banned indicator, external runtime feed, option input, futures
      curve, grid, martingale, pyramiding, or adaptive PnL fitting.
- [x] D1/monthly expected density is twelve packages/year before Q02.
- [x] Backtests use RISK_FIXED; no live setfile is authorized.
- [x] Friday-close exception is source-aligned and documented.
- [x] Canonical dedup fuzzy hits were manually reviewed and found mechanically
      distinct before atomic allocation.

## Non-Duplicate Decision

- QM5_12567 cum-rsi2-commodity: short-horizon long-only RSI pullback.
- QM5_13129 energy-rsj: one-month normalized signed squares, not a twelve-month
  lower-tail mean.
- QM5_13130 xti-xng-lowmax: average of five largest positive returns with the
  opposite low-MAX orientation, not the worst 5%.
- QM5_13118 and QM5_13131: third and fourth moments, not expected shortfall.
- QM5_13133 energy-ivol: regression-residual dispersion, not raw tail losses.
- QM5_13141 energy-ie-rank: frequency of factor-residual extremes, not their
  raw downside magnitude.
- QM5_13139, QM5_13140, QM5_13142: coefficient of variation, activity-scaled
  illiquidity, and salience-weight covariance, respectively.

The checker returned lexical rank-family matches only. Manual signal-input,
transform, direction, window, and exit review verdict:
CLEAN_AFTER_MANUAL_REVIEW.

## Framework Alignment

- no_trade: exact host/slot, locked estimator, bounded history, calendar
  coverage, observation and tail-count floors, arithmetic, spread, ATR, lot,
  month-attempt, magic, and package guards.
- trade_entry: prior-twelve-month expected-shortfall rank, paired orders,
  equal fixed-risk allocation, and frozen hard stops.
- trade_management: next-month reset, 40-day stale close, restart-safe deal
  guard, composition validation, and orphan cleanup.
- trade_close: framework close helper plus broker-side hard stops.

No T_Live, AutoTrading setting, live setfile, deploy manifest, portfolio gate,
portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-11 | initial monthly XTI/XNG expected-shortfall basket | Q01 | BUILDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-11 | APPROVED by OWNER mission directive | this card |
| Q01 Build Validation | 2026-07-11 | BUILDING | pending |
| Q02 Baseline Screening | TBD | TBD | TBD |

## Lessons Captured

- 2026-07-11: Expected shortfall remains distinct from signed variance and
  extreme-return counts only when the lower-tail mean, tail fraction, and
  formation window stay explicit and locked.
