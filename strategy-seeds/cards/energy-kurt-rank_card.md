---
strategy_id: HOLLSTEIN-MAX-2021_XTI_XNG_S02
source_id: HOLLSTEIN-MAX-2021
ea_id: QM5_13131
slug: energy-kurt-rank
status: APPROVED
created: 2026-07-11
created_by: Research
last_updated: 2026-07-11
g0_status: APPROVED
source_citations:
  - type: paper
    citation: "Hollstein, Fabian; Prokopczuk, Marcel; and Tharann, Bjoern (2021). Anomalies in Commodity Futures Markets. Quarterly Journal of Finance 11(4), article 2150017."
    location: "Complete 57-page accepted article and online appendix; especially pp. 9-10, 19, 22-25, Appendix B p. 27, Tables 4 and A1/A3/A4/A5; DOI https://doi.org/10.1142/S2010139221500178"
    quality_tier: A
    role: primary
strategy_type_flags: [atr-hard-stop, time-stop, symmetric-long-short]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13131_XTI_XNG_HKURT_D1
period: D1
expected_trade_frequency: "One monthly XTI/XNG historical-kurtosis package after 253 completed D1 closes; approximately 12 completed packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.02
expected_dd_pct: 28.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
review_focus: "Falsify a pure fourth-moment energy risk premium in a market-neutral XTI/XNG carrier. The source's two-portfolio result is insignificant and its post-financialization sign reverses, so no performance transfer or portfolio decorrelation is assumed."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_execution, friday_close, magic_schema, risk_mode_dual, cfd_futures_basis, narrow_cross_section, postfinancialization_sign_reversal]
g0_approval_reasoning: "OWNER mission-directed G0 approval on 2026-07-11: complete peer-reviewed source and appendix; exact prior-252-return Pearson historical-kurtosis rank, monthly paired hold, equal fixed risk, ATR hard stops, restart-safe no-reentry; native registered XTI/XNG D1 data; no ML/banned/external/grid/martingale logic. Manual dedup review CLEAN before atomic QM5_13131 allocation. Approval preserves the insignificant two-portfolio result and post-financialization sign reversal as binding Q02 kill risks."
---

# XTI/XNG Historical-Kurtosis Rank

## Hypothesis

The source finds that commodities with higher trailing historical kurtosis earn
higher next-month returns in its full-sample tercile sort, consistent with a
premium for bearing infrequent extreme-return risk. This card tests the rule as
a two-leg energy package: buy the higher-kurtosis XTI/XNG leg and short the
lower-kurtosis leg for one broker month.

The prior is deliberately weak. The source's two-portfolio result is positive
but insignificant, its cross-sectional regression slope is insignificant, and
the high-minus-low return reverses sign in the post-financialization subperiod.
The 2017+ Darwinex Q02 run is therefore an out-of-sample falsification, not a
replication claim.

## Source And Evidence Boundary

The sole primary source is Hollstein, Prokopczuk, and Tharann (2021),
*Quarterly Journal of Finance* 11(4), DOI
`10.1142/S2010139221500178`. The complete accepted article and online appendix
were reviewed end to end. The paper:

- sorts commodities at month-end and holds for one month;
- requires at least six available futures and uses tercile portfolios in the
  main specification;
- defines historical kurtosis from daily excess returns over the prior 12
  months;
- includes WTI crude oil and natural gas in its source universe;
- reports a significant positive full-sample tercile spread;
- reports an insignificant two-portfolio spread and Fama-MacBeth slope; and
- reports a negative, insignificant post-financialization spread.

No source return, alpha, drawdown, correlation, or transaction-cost result is
imported into the QM prior. The source uses rolled, fixed-maturity,
fully-collateralized futures; the EA uses continuous broker CFDs and simple
close-to-close returns. That basis difference is a kill risk.

## Concept And Formula

On the first tradable `XTIUSD.DWX` D1 bar of each broker month, use the most
recent 253 completed D1 closes for both energy legs and calculate exactly 252
simple daily returns. For each leg `i`, let `D=252` and compute:

```text
mu_i       = sum(return_i[d]) / D
variance_i = sum((return_i[d] - mu_i)^2) / (D - 1)
moment4_i  = sum((return_i[d] - mu_i)^4) / D
kurtosis_i = moment4_i / variance_i^2
```

This is Pearson historical kurtosis. Do not subtract three. Although excess
kurtosis would preserve a two-leg rank, the source formula is retained exactly.

Direction is fixed by the source's full-sample relationship:

- `kurtosis_XTI > kurtosis_XNG`: BUY XTI and SELL XNG.
- `kurtosis_XTI < kurtosis_XNG`: SELL XTI and BUY XNG.
- Numerical tie, nonpositive variance, invalid arithmetic, or incomplete
  history: remain flat.

## Rules

### Markets And Timeframe

- Logical basket: `QM5_13131_XTI_XNG_HKURT_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1.
- Traded slot 1: `XNGUSD.DWX`, D1.
- Signal cadence: first tradable D1 bar of each broker month.
- Formation: exactly 252 completed D1 simple returns; current D1 bar excluded.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, split equally across the legs.
- Runtime data: MT5-native closes, ATR, spread, broker calendar, deal history,
  and position state only.

### Entry Rules

- Require exact host `XTIUSD.DWX`, timeframe D1, and magic slot 0.
- Detect a month transition by comparing the current host D1 bar's month with
  the immediately preceding completed host bar's month.
- Load 253 completed closes for each leg and compute the source-defined
  Pearson historical kurtosis from exactly 252 returns.
- Buy the higher-kurtosis leg and short the lower-kurtosis leg.
- Reject a numerical tie, missing/nonpositive close, nonpositive sample
  variance, invalid moment, incomplete history, invalid ATR/price/lot metadata,
  excess spread, an existing package, or a month already entered.
- Scan current positions and entry deals so restart or a stopped leg cannot
  produce a second package in the same broker month.
- Split fixed package risk equally and attach a frozen
  `ATR(20) * 3.5` hard stop to each leg.
- If the second order fails, immediately flatten the first leg.

### Exit Rules

- Close both legs on the first tradable D1 bar of the next broker month before
  evaluating a replacement package.
- Close both legs after `strategy_max_hold_days=35` as a stale guard.
- If either hard stop removes one leg, flatten the orphan immediately.
- Flatten duplicate, same-side, wrong-symbol, or wrong-magic composition.
- Friday close is disabled only to preserve the source's one-month hold.

### Filters And Trade Management

- Framework kill switch remains first and authoritative.
- Parameter, history, arithmetic, spread, ATR, lot, monthly-attempt, magic, and
  package-composition checks fail closed.
- News compliance gates new entries for both symbols; lifecycle management and
  orphan repair remain active. The Q02 structural setfile disables news axes.
- Exactly two opposite-side legs with equal fixed-risk shares.
- No TP, trail, break-even, partial close, scale-in, grid, martingale,
  pyramiding, external feed, adaptive PnL fit, or ML.

## Parameters To Test

| parameter | default | authorized range | role |
|---|---:|---|---|
| `strategy_lookback_d1` | 252 | [252] | source-aligned completed return count |
| `strategy_history_bars` | 320 | [280, 320, 380] | bounded retrieval buffer only |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg stop volatility estimate |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| `strategy_max_hold_days` | 35 | [35] | stale guard around monthly reset |
| `strategy_xti_max_spread_pts` | 1500 | [1000, 1500, 2500] | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | XNG entry spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | basket order deviation |

The 252-return window, source variance/moment denominators, Pearson-kurtosis
rank, high-minus-low direction, monthly renewal, equal half-risk carrier, and
no same-month re-entry are locked. A skew filter, excess-return proxy, shorter
formation period, or post-financialization direction flip requires a new card.

## Author Claims

"historical kurtosis seems to be priced in the cross-section of commodity
returns." (p. 19)

"the premium on historical kurtosis seems to vanish in the
post-financialization period." (p. 24)

These bounded claims capture both the headline and its strongest conflict.
Neither validates a two-CFD energy carrier.

## Risk

- `expected_pf: 1.02` is a low queue-ordering prior, not evidence.
- `expected_dd_pct: 28.0` reflects XNG gaps, legging, fourth-moment instability,
  narrow cross-section, and adverse modern source evidence.
- Expected frequency is approximately 12 packages/year after warm-up and must
  clear the binding Q02 minimum of five.
- `risk_class: high`; `ml_required: false`.

## Strategy Allowability Check

- [x] Mechanical structural higher-moment risk-premium thesis.
- [x] Peer-reviewed primary source, DOI, institutional full text, and complete
  article/appendix review.
- [x] No ML, banned indicator, external runtime data, futures curve, option
  feed, volume, grid, martingale, or pyramiding.
- [x] D1/monthly expected density above the Q02 floor.
- [x] Backtests use `RISK_FIXED`; no live setfile is authorized.
- [x] Friday-close exception is source-aligned and documented.
- [x] Manual repository dedup review was clean before allocation.

## Non-Duplicate Decision

- `QM5_13118_energy-skew-rank`: third moment, low-skew direction; this is
  fourth moment, high-kurtosis direction.
- `QM5_13129_energy-rsj`: one-month signed semivariance; this is a centered
  fourth moment across 252 returns.
- `QM5_13130_xti-xng-lowmax`: top-five upside order statistic and low-MAX
  direction; this uses every return and high-kurtosis direction.
- `QM5_1212_carver-kurtsabs` and `QM5_1221_carver-kurtsrv`: skew-conditioned
  daily forecasts with scaling/smoothing; this is an unconditioned monthly
  cross-sectional rank.
- `QM5_10322_realized-moments`: weekly H1 composite; this is pure D1 kurtosis.
- No RSI, momentum, value, carry, calendar, event, spread-z-score, or channel
  input is present.

The dedup tool flagged `QM5_13130` only because both strategy IDs share their
approved paper. Manual mechanic review verdict:
`CLEAN_AFTER_MANUAL_REVIEW`.

## Framework Alignment

- no_trade: exact host/slot, locked signal dimension, bounded history,
  arithmetic, spread, ATR, lot, monthly-attempt, magic, and package guards.
- trade_entry: prior-252-return Pearson-kurtosis rank, paired orders, equal
  fixed-risk allocation, and frozen ATR stops.
- trade_management: next-month reset, 35-day stale close, restart-safe deal
  scan, composition validation, and orphan cleanup.
- trade_close: framework close helper plus broker-side hard stops.

No `T_Live`, AutoTrading setting, live setfile, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI path is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-11 | initial historical-kurtosis XTI/XNG basket | Q02 | ENQUEUED |

## Lessons Captured

- 2026-07-11: A significant full-sample tercile result is not enough to claim
  a two-leg modern edge; the insignificant two-portfolio result and modern
  sign reversal must travel with the card into Q02.
