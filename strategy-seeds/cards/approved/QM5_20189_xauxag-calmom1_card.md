---
card_schema_version: 2
ea_id: QM5_20189
slug: xauxag-calmom1
type: strategy
strategy_id: KELOHARJU-FMR-XAUXAG-CALMOM1-2026_S01
variant_id: KELOHARJU-FMR-XAUXAG-CALMOM1-2026_S01
source_id: KELOHARJU-FMR-XAUXAG-CALMOM1-2026
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20189_xauxag-calmom1_card.md
execution_contract_status: DRAFT
created: 2026-07-31
created_by: Research+Development
last_updated: 2026-07-31
source_authors: "Matti Keloharju; Juhani Linnainmaa; Peter Nyberg; Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis"
strategy_mechanic: ten-year-same-calendar-xau-minus-xag-return-sign-agrees-with-immediately-completed-relative-month-two-leg-basket
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Journal of Finance 71(4), 1557-1590; Fuertes, Miffre, and Rallis (2010), Journal of Banking & Finance 34(10), 2530-2548."
source_citations:
  - type: peer_reviewed_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "Commodity construction in Sections 5.4.3-5.6 and Tables 8-9; DOI https://doi.org/10.1111/jofi.12398; complete governed review strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md"
    quality_tier: A
    role: seasonal_state
  - type: peer_reviewed_paper
    citation: "Fuertes, A.-M., Miffre, J., and Rallis, G. (2010). Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals. Journal of Banking & Finance 34(10), 2530-2548."
    location: "Momentum construction pp. 6-7 and 17-18; DOI https://doi.org/10.1016/j.jbankfin.2010.04.009; complete governed review strategy-seeds/sources/FMR-MOMTS-2010/source.md"
    quality_tier: A
    role: momentum_state
sources:
  - "[[sources/KELOHARJU-FMR-XAUXAG-CALMOM1-2026]]"
concepts:
  - "[[concepts/same-calendar-month-seasonality]]"
  - "[[concepts/cross-sectional-commodity-momentum]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-month-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, calendar-seasonality, cross-sectional-momentum, agreement-filter, market-neutral-basket, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
markets: [commodities, precious_metals]
single_symbol_only: false
logical_symbol: QM5_20189_XAU_XAG_CALMOM1_D1
symbol: QM5_20189_XAU_XAG_CALMOM1_D1
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "One monthly decision after the five-year paired same-calendar warm-up; strict agreement should produce approximately 5-8 two-leg packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: QUEUED
q02_work_item_id: 2897ad06-5996-4c5a-8a4b-1de95c867c52
review_focus: "Falsify the agreement of recurring XAU/XAG calendar-month relative seasonality and the exact immediately completed relative month; neutrality, profitability, density, and book decorrelation are not imported."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, synchronized_history, aggregate_fixed_risk, restart_attempt_state, magic_schema, cfd_futures_basis, conjunction_sparsity, narrow_cross_section, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission: R1 two peer-reviewed fully reviewed source lineages; R2 locked same-calendar estimator, exact prior-month rank, strict agreement, shared risk, stops, attempt state, monthly exit, and repair; R3 registered XAU/XAG D1; R4 native deterministic arithmetic only. Deterministic dedup CLEAN; parent siblings manually distinct."
---

# QM5_20189 XAU/XAG Same-Calendar Momentum Agreement

## Hypothesis

Recurring industrial demand, monetary demand, hedging, and capital-allocation
pressures can make gold-versus-silver relative returns differ by calendar
month. Commodity shocks can also diffuse slowly over the immediately following
month. Trading only when the historical same-calendar XAU/XAG relative sign
agrees with the exact completed one-month relative-momentum sign may isolate a
slower precious-metals spread state.

The two opposite legs aim to suppress their common precious-metal and USD
factor, leaving a relative seasonal-plus-momentum package. That construction
is market-neutral in direction, not proof of dollar, beta, volatility, or
portfolio neutrality. Q02 and the unchanged downstream gates must establish
density, economics, execution quality, and realized correlation.

## Source Traceability

The canonical composite packet is
`strategy-seeds/sources/KELOHARJU-FMR-XAUXAG-CALMOM1-2026/source.md`.
Keloharju, Linnainmaa, and Nyberg supply the recurring same-calendar commodity
return state. Fuertes, Miffre, and Rallis supply the one-month cross-sectional
commodity-momentum state and one-month hold.

Both parent papers trade broad collateralized commodity-futures portfolios.
Neither tests this conjunction, a two-name XAU/XAG CFD basket, equal stop-risk
legs, Darwinex month boundaries, broker costs, or this portfolio. No source
profit factor, return, drawdown, trade count, hedge ratio, or correlation
statistic is imported.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,246 registry rows and 377
cards and returned `CLEAN`. Manual review resolves the closest systems:

- `QM5_20186_xauxag-samecal` uses the seasonal rank alone.
- `QM5_20057_xauxag-xmom1` uses the immediately completed relative month alone.
- `QM5_20184_xauxag-xmom3` averages three contiguous completed months and has
  no recurring calendar estimator.
- `QM5_20157_xau-xag-ratio` and `QM5_20161_xauxag-ols-rv` fade continuous
  ratio or residual z-scores; this card follows two agreeing return signs.
- `QM5_12862_xauxag-rspread` fades a standardized ten-D1 shock.
- `QM5_20136_wti-caltrend` is an outright WTI carrier, not a precious-metals
  relative basket.

The same-calendar estimator, immediately completed relative month, strict sign
agreement, and two opposite legs are jointly load-bearing. Removing either
state recreates a built parent. A ratio, residual, reversal, channel, weekday,
or different-horizon substitution is outside this card.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_20189_XAU_XAG_CALMOM1_D1`.
- Host/slot 0: `XAUUSD.DWX`, D1, magic `201890000`.
- Companion/slot 1: `XAGUSD.DWX`, D1, magic `201890001`.
- Decision: first tradable XAU D1 bar of every new broker month.
- Seasonal formation: decision-month returns from the prior ten years,
  requiring at least five synchronized paired observations.
- Momentum formation: exactly the immediately completed broker-month return
  for each leg.
- Hold: until the next broker-month boundary, with a 40-day stale guard.
- Expected cadence: approximately 5-8 completed packages/year after warm-up;
  retire below five/year.

## Rules

The formula, entry, exit, filter, and management rules below are the complete
authorized baseline. Anything not stated is outside this card.

## Formula

At the first tradable D1 bar of decision month `m` in year `Y`, reconstruct
synchronized completed month-end closes for both legs.

For each prior year `y` in `[Y-10, Y-1]` with a valid completed return for
calendar month `m`:

```text
season_y = ln(C_XAU[y,m] / C_XAU[y,m-1])
         - ln(C_XAG[y,m] / C_XAG[y,m-1])
seasonal_score = arithmetic_mean(season_y)
```

Require at least five paired `season_y` observations. For the immediately
completed broker month:

```text
momentum_score = ln(C_XAU[t-1] / C_XAU[t-2])
               - ln(C_XAG[t-1] / C_XAG[t-2])
```

- Both scores `> 1e-10`: BUY XAU and SELL XAG.
- Both scores `< -1e-10`: SELL XAU and BUY XAG.
- Disagreement, deadband, missing/nonconsecutive endpoints, timestamp
  mismatch, nonpositive close, or invalid arithmetic: remain flat for the
  consumed month.

There is no price ratio, z-score, regression, oscillator, moving average,
breakout, carry proxy, external series, trained model, or PnL-adaptive rule.

## 4. Entry Rules

1. Require exact EA ID `20189`, XAU D1 host, slot 0, and every baseline input
   locked to the values below.
2. Evaluate only at a genuine broker-month transition.
3. Persist the current month attempt before history, signal, spread, quote,
   stop, risk, news, or order gates. A flat, blocked, rejected, stopped, or
   partially opened decision cannot retry after restart.
4. Reconstruct bounded completed D1 month endpoints for both legs. Require
   matching month keys and endpoint timestamps wherever the pair is used.
5. Compute the ten-prior-year same-calendar relative-return mean with at least
   five paired samples and the exact immediately completed relative month.
6. Require both scores beyond `1e-10` with the same sign. Buy XAU/sell XAG for
   positive agreement; sell XAU/buy XAG for negative agreement.
7. Require no owned leg, acceptable spreads, valid current quotes, completed
   ATR(20), registered magics, and valid symbol/volume metadata.
8. Split one package `RISK_FIXED` budget equally between the two ATR-normalized
   legs. Attach a frozen `3.5 * ATR(20,D1)` hard stop to each; no take-profit.
9. Open XAU then XAG. Keep the package only if exactly one correctly directed
   position exists in each registered slot. If either order or the final
   package check fails, flatten every owned leg immediately.

## 5. Exit Rules

1. On the first tradable D1 bar of the next broker month, close both legs
   before considering a replacement package.
2. Close both legs after 40 calendar days as a stale guard.
3. Immediately flatten an orphan, duplicate, wrong-symbol, same-direction,
   wrong-magic, or missing-stop package.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source hold spans month-end weekends.
6. No take-profit, trailing, break-even, partial close, scale-in, grid,
   martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside `XAUUSD.DWX` D1 slot 0.
- Require synchronized month endpoints, ten prior calendar years, at least
  five paired same-month samples, and the exact immediately completed month.
- Require nonnegative current spreads no greater than 1,500 points for XAU
  and 3,000 points for XAG.
- Require valid ATR, quotes, volume steps, contract metadata, magic rows,
  attempt state, and package state.
- Q02 freezes both news axes OFF. No external calendar or data file is read.

## 7. Trade Management Rules

The EA may own exactly two opposite-direction positions: XAU slot 0 and XAG
slot 1. Risk is one shared fixed budget, not `RISK_FIXED` independently on each
leg. Package composition and hard stops are checked every tick; invalid or
partial state is flattened. There is at most one attempted package per broker
month.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_history_years` | 10 | [10] | bounded same-calendar estimator |
| `strategy_min_history_years` | 5 | [5] | paired seasonal sample floor |
| `strategy_history_bars` | 4000 | [4000] | bounded D1 retrieval buffer |
| `strategy_momentum_months` | 1 | [1] | exact completed relative month |
| `strategy_signal_epsilon` | 1e-10 | [1e-10] | deterministic tie deadband |
| `strategy_atr_period_d1` | 20 | [20] | completed-bar stop volatility |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread cap |
| `strategy_deviation_points` | 20 | [20] | order deviation |

There is no baseline sweep. Both source states are jointly load-bearing.

## Risk And Test Contract

The canonical Q02 setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both legs share that one budget equally after independent
ATR normalization. Q02 evaluates the logical basket, not standalone symbols.

Retire on fewer than five completed packages/year, nonpositive governed
economics, nondeterminism, mismatched endpoints, repeated monthly attempts,
orphan persistence, aggregate-risk breach, wrong magic/direction, or a
downstream correlation rejection. Financing, legging, lot granularity, CFD
basis, common-metal beta, industrial-silver beta, gaps, and conjunction
sparsity are binding risks.

## Strategy Allowability Check

- [x] R1: two approved peer-reviewed source lineages with DOIs and complete
  durable repository reviews.
- [x] R2: fixed synchronized seasonal mean, exact one-month rank, agreement,
  direction, shared risk, stops, attempt state, monthly exit, and repair rules.
- [x] R3: registered XAUUSD.DWX and XAGUSD.DWX D1 logical-basket route.
- [x] R4: deterministic native price/calendar arithmetic only; no banned
  indicator, trained model, external runtime feed, grid, martingale, or pyramid.
- [x] Dedup: no exact match; seasonal-only and momentum-only parents were
  manually resolved and both states remain mandatory.

## Framework Alignment

- No-trade: exact host/timeframe/slot, locked inputs, history synchronization,
  spread, symbol, magic, package, and attempt guards.
- Trade entry: monthly two-state agreement, opposite two-leg orders, shared
  fixed-risk sizing, hard stops, and atomic repair.
- Trade management: package validation, next-month close, stale close, and
  orphan cleanup.
- Trade close: framework close helper plus broker hard stops and kill switch.

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
`RISK_FIXED` backtest setfile, one basket manifest, and one paced Q02 enqueue.
It does not authorize a live setfile, AutoTrading, `T_Live` access, a deploy or
T_Live manifest, portfolio admission, a portfolio-gate change, or a
correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-31 | initial XAU/XAG calendar-momentum agreement basket | G0 | APPROVED |
| v1-q02 | 2026-07-31 | strict build recorded and logical basket enqueued | Q02 | QUEUED |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-07-31 | APPROVED; R1-R4 PASS | this card and governed source packet |
| Q01 Build Validation | 2026-07-31 | PASS | `D:/QM/reports/framework/21/build_check_20260731_175224.json`; strict compile `D:/QM/reports/compile/20260731_175613/summary.csv` |
| Q02 Baseline Screening | 2026-07-31 | QUEUED | work item `2897ad06-5996-4c5a-8a4b-1de95c867c52` |
