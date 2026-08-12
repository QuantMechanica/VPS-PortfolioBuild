---
card_schema_version: 2
ea_id: QM5_20184
slug: xauxag-xmom3
type: strategy
strategy_id: FMR-MOMTS-2010_XAU_XAG_S04
variant_id: FMR-MOMTS-2010_XAU_XAG_S04
source_id: FMR-MOMTS-2010
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20184_xauxag-xmom3_card.md
execution_contract_status: DRAFT
created: 2026-07-31
created_by: Research+Development
last_updated: 2026-07-31
source_authors: "Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis"
strategy_mechanic: three-completed-month-average-return-xau-xag-cross-sectional-momentum-monthly-two-leg-basket
source_citation: "Fuertes, Miffre, and Rallis (2010), Journal of Banking & Finance 34(10), 2530-2548."
source_citations:
  - type: peer_reviewed_paper
    citation: "Fuertes, A.-M., Miffre, J., and Rallis, G. (2010). Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals. Journal of Banking & Finance 34(10), 2530-2548."
    location: "Complete 47-page accepted manuscript; momentum construction pp. 6-7 and 17-18; DOI https://doi.org/10.1016/j.jbankfin.2010.04.009; governed packet strategy-seeds/sources/FMR-MOMTS-2010/source.md"
    quality_tier: A
    role: primary
sources:
  - "[[sources/FMR-MOMTS-2010]]"
concepts:
  - "[[concepts/cross-sectional-commodity-momentum]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-month-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, cross-sectional-momentum, market-neutral-basket, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
markets: [commodities, precious_metals]
single_symbol_only: false
logical_symbol: QM5_20184_XAU_XAG_XMOM3_D1
symbol: QM5_20184_XAU_XAG_XMOM3_D1
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "One two-leg package per broker month after four synchronized completed month-end closes; approximately 12 packages/year before Q02 validation."
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
q01_status: PASS
q02_status: PENDING
review_focus: "Falsify the source-defined intermediate three-month XAU/XAG relative-momentum horizon as a two-CFD basket; profitability, neutrality, and book decorrelation are not imported."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, synchronized_history, aggregate_fixed_risk, restart_attempt_state, magic_schema, cfd_futures_basis, narrow_cross_section, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission: R1 peer-reviewed governed source; R2 locked synchronized three-month rank, shared risk, stops, persisted attempt, and repair; R3 registered XAU/XAG D1; R4 deterministic native arithmetic only. Exact dedup clean; source-horizon siblings manually distinct."
---

# QM5_20184 XAU/XAG Three-Month Cross-Sectional Momentum

## Hypothesis

Commodity supply, demand, inventory, and hedging shocks can diffuse slowly.
The source explicitly tests one-, three-, and twelve-month commodity momentum
formation horizons with a one-month hold. This card isolates the missing
intermediate horizon: at each broker-month boundary it buys the stronger of
gold and silver over the preceding three completed months and shorts the
weaker metal.

The opposite legs aim to suppress their common precious-metal and USD factor,
leaving relative gold-versus-industrial-silver momentum. That construction is
market-neutral in direction, not proof of dollar, beta, volatility, or
portfolio neutrality. Q02 and the unchanged downstream gates must establish
economics, execution quality, and realized correlation.

## Source Traceability

The canonical source is Fuertes, Miffre, and Rallis (2010), *Journal of
Banking & Finance* 34(10). The complete accepted manuscript was reviewed
end-to-end and is summarized in the approved durable packet
`strategy-seeds/sources/FMR-MOMTS-2010/source.md`. Pages 6-7 and 17-18 define
average past-return momentum ranks at one-, three-, and twelve-month formation
horizons with a one-month hold.

The paper trades diversified, collateralized commodity-futures portfolios.
It does not test a two-name XAU/XAG CFD basket, equal stop-risk legs, Darwinex
month boundaries, broker costs, or this portfolio. No source PF, return,
drawdown, Sharpe, or correlation statistic is imported.

## Non-Duplicate Decision

The canonical pre-allocation checker found no exact slug or strategy identity.
Its fuzzy hits are expected same-paper siblings and were resolved manually:

- `QM5_20057_xauxag-xmom1` ranks exactly one completed monthly return.
- `QM5_20050_xauxag-xmom12` averages exactly twelve completed monthly returns.
- `QM5_20184_xauxag-xmom3` averages exactly three completed monthly returns,
  the paper's separate intermediate formation horizon.
- `QM5_12862_xauxag-rspread` fades standardized ten-D1 relative-return shocks;
  this card follows, rather than fades, a fixed completed-month rank and exits
  only at the next month boundary.
- Ratio, residual, threshold, quantile, stochastic, breakout, weekday, and
  weekend XAU/XAG baskets use different state variables and decision clocks.

The three-month horizon is locked and load-bearing. Changing it to one or
twelve months recreates an existing EA. This card is not an optimization
variant selected after results; it is the unbuilt source-declared horizon.

## Markets, Timeframe, and Cadence

- Logical basket: `QM5_20184_XAU_XAG_XMOM3_D1`.
- Host/slot 0: `XAUUSD.DWX`, D1, magic `201840000`.
- Companion/slot 1: `XAGUSD.DWX`, D1, magic `201840001`.
- Decision: first tradable XAU D1 bar of each new broker month.
- Formation: four synchronized completed month-end observations, producing
  exactly three consecutive simple monthly returns per leg.
- Hold: until the next broker-month boundary, with a 40-calendar-day stale
  guard.
- Expected cadence: approximately 12 completed packages/year; retire below
  five/year after warm-up.

## Rules

The formula, entry, exit, filter, and management rules below are the complete
authorized baseline. Anything not stated is outside this card.

## Formula

For each leg `i`, let `C_i[0]` be the just-completed broker-month close and
`C_i[1..3]` the three preceding synchronized month-end closes:

```text
r_i[k] = C_i[k] / C_i[k+1] - 1,  k = 0..2
avg3_i = (r_i[0] + r_i[1] + r_i[2]) / 3
```

- `avg3_XAU > avg3_XAG`: BUY XAU and SELL XAG.
- `avg3_XAU < avg3_XAG`: SELL XAU and BUY XAG.
- Difference within `1e-10`, missing/nonconsecutive endpoints, timestamp
  mismatch, nonpositive close, or invalid arithmetic: remain flat for the
  consumed month.

There is no price ratio, z-score, regression, oscillator, moving average,
breakout, carry proxy, external series, trained model, or PnL-adaptive rule.

## 4. Entry Rules

1. Require exact EA ID `20184`, XAU D1 host, slot 0, and locked three-month
   formation horizon.
2. Evaluate only at a genuine broker-month transition.
3. Persist the current month attempt before history, signal, spread, quote,
   stop, risk, news, or order gates. A flat, blocked, rejected, stopped, or
   partially opened decision cannot retry after restart.
4. Reconstruct exactly four consecutive completed broker-month endpoints for
   both legs from completed D1 bars. Require matching month keys and matching
   endpoint timestamps across XAU and XAG.
5. Calculate exactly three simple monthly returns and their arithmetic average
   for each leg. Require an absolute average-return difference above `1e-10`.
6. Buy the higher-average-return leg and sell the lower-average-return leg.
7. Require no owned leg, acceptable spreads, valid current quotes, completed
   ATR(20), registered magics, and valid symbol/volume metadata.
8. Split the one package `RISK_FIXED` budget equally between the two
   ATR-normalized legs. Attach a frozen `3.5 * ATR(20,D1)` hard stop to each;
   there is no take-profit.
9. Open XAU then XAG. Keep the package only if exactly one correctly directed
   position exists in each registered slot. If either order or the final
   package check fails, flatten every owned leg immediately.

## 5. Exit Rules

1. On the first tradable D1 bar of the next broker month, close both legs
   before considering a new package.
2. Close both legs after 40 calendar days as a stale guard.
3. Immediately flatten an orphan, duplicate, wrong-symbol, same-direction,
   wrong-magic, or missing-stop package.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source hold spans month-end weekends.
6. No take-profit, trailing, break-even, partial close, scale-in, grid,
   martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside `XAUUSD.DWX` D1 slot 0 or if the formation horizon is
  not exactly three completed months.
- Require synchronized, consecutive month endpoints and sufficient bounded D1
  history on both legs.
- Require nonnegative current spreads no greater than 1,500 points for XAU
  and 3,000 points for XAG.
- Require valid ATR, quotes, volume steps, contract metadata, magic rows,
  attempt state, and package state.
- Q02 freezes both news axes OFF. No external calendar or data file is read.

## 7. Trade Management Rules

The EA may own exactly two opposite-direction positions: XAU slot 0 and XAG
slot 1. Risk is one shared fixed budget, not `RISK_FIXED` independently on
each leg. Package composition is checked every tick; invalid or partial state
is flattened. There is at most one attempted package per broker month.

## Parameters To Test

| parameter | baseline | authorized range | role |
|---|---:|---|---|
| `strategy_return_window_months` | 3 | locked | source-defined formation horizon |
| `strategy_history_bars` | 500 | [400, 500, 600] | bounded D1 retrieval buffer |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | completed-bar stop volatility |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 40 | locked | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | [1000, 1500, 2500] | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 3000 | [2000, 3000, 4500] | XAG entry spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | order deviation |

## Risk and Test Contract

The canonical Q02 setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both legs share that one budget equally after independent
ATR normalization. Q02 evaluates the logical basket, not two standalone
symbol results.

Retire on fewer than five completed packages/year, nonpositive governed
economics, nondeterminism, mismatched endpoints, repeated monthly attempts,
orphan persistence, aggregate-risk breach, wrong magic/direction, or a
downstream correlation rejection. Financing, legging, lot granularity, CFD
basis, common-metal beta, industrial silver beta, gaps, and the two-name
translation are binding risks.

## Strategy Allowability Check

- [x] R1: one approved peer-reviewed JBF source lineage with DOI and a
  completely reviewed accepted manuscript.
- [x] R2: fixed synchronized three-month rank, direction, shared risk, stops,
  attempt state, monthly exit, and repair rules.
- [x] R3: registered XAUUSD.DWX and XAGUSD.DWX D1 routes with established
  logical-basket tester support.
- [x] R4: deterministic native price/calendar arithmetic only; no banned
  indicator, ML, external runtime feed, grid, martingale, or pyramiding.
- [x] Dedup: no exact match; expected one-/twelve-month fuzzy siblings were
  manually resolved by their mutually exclusive locked formation horizons.

## Framework Alignment

- No-trade: exact host/timeframe/slot, locked horizon, history synchronization,
  spread, symbol, magic, package, and attempt guards.
- Trade entry: monthly three-return rank, opposite two-leg orders, shared
  fixed-risk sizing, hard stops, and atomic repair.
- Trade management: package validation, next-month close, stale close, and
  orphan cleanup.
- Trade close: framework close helper plus broker hard stops and kill switch.

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
`RISK_FIXED` backtest setfile, one basket manifest, and one paced Q02 enqueue.
It does not authorize a live setfile, AutoTrading, T_Live access, a deploy or
T_Live manifest, portfolio admission, correlation waiver, or portfolio-gate
change.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-31 | initial source-defined three-month XAU/XAG basket | G0 | PENDING |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-07-31 | PENDING deterministic approval | this card |
