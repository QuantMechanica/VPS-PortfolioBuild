---
card_schema_version: 2
ea_id: QM5_20186
slug: xauxag-samecal
type: strategy
strategy_id: KELOHARJU-FMR-XAUXAG-SAMECAL-2026_S01
variant_id: KELOHARJU-FMR-XAUXAG-SAMECAL-2026_S01
source_id: KELOHARJU-FMR-XAUXAG-SAMECAL-2026
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20186_xauxag-samecal_card.md
execution_contract_status: DRAFT
created: 2026-07-31
created_by: Research+Development
last_updated: 2026-07-31
source_authors: "Matti Keloharju; Juhani Linnainmaa; Peter Nyberg; Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis"
strategy_mechanic: prior-ten-year-same-calendar-month-average-return-xau-xag-relative-rank-monthly-two-leg-basket
source_citation: "Keloharju, Linnainmaa, and Nyberg (2016), Journal of Finance 71(4); Fuertes, Miffre, and Rallis (2010), Journal of Banking & Finance 34(10)."
source_citations:
  - type: peer_reviewed_paper
    citation: "Keloharju, M., Linnainmaa, J. T., and Nyberg, P. (2016). Return Seasonalities. The Journal of Finance 71(4), 1557-1590."
    location: "Complete governed review at strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md; DOI https://doi.org/10.1111/jofi.12398"
    quality_tier: A
    role: same_calendar_month_rank
  - type: peer_reviewed_paper
    citation: "Fuertes, A.-M., Miffre, J., and Rallis, G. (2010). Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals. Journal of Banking & Finance 34(10), 2530-2548."
    location: "Complete governed review at strategy-seeds/sources/FMR-MOMTS-2010/source.md; DOI https://doi.org/10.1016/j.jbankfin.2010.04.009"
    quality_tier: A
    role: xau_xag_cross_sectional_carrier
sources:
  - "[[sources/KELOHARJU-FMR-XAUXAG-SAMECAL-2026]]"
concepts:
  - "[[concepts/same-calendar-month-seasonality]]"
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/month-end-close]]"
  - "[[indicators/arithmetic-mean]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, calendar-seasonality, same-calendar-month, relative-rank, market-neutral-basket, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
markets: [commodities, precious_metals, relative_value]
single_symbol_only: false
logical_symbol: QM5_20186_XAU_XAG_SAMECAL_D1
symbol: QM5_20186_XAU_XAG_SAMECAL_D1
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "One two-leg package per broker month after the five-year synchronized warm-up; approximately 12 packages/year before Q02 validation."
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
q02_status: QUEUED
q02_work_item_id: d6305296-8823-42f6-8604-37725d037617
review_focus: "Falsify a narrow XAU/XAG translation of source-defined same-calendar commodity seasonality; profitability, neutrality, and book decorrelation are not imported."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, synchronized_history, aggregate_fixed_risk, restart_attempt_state, magic_schema, cfd_futures_basis, narrow_cross_section, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission 2026-07-31: R1 PASS two peer-reviewed, completely reviewed governed source lineages; R2 PASS locked prior-ten-year same-calendar relative rank, shared risk, stops, persisted attempt, and orphan repair; R3 PASS registered synchronized XAU/XAG D1; R4 PASS deterministic native arithmetic only. Exact dedup CLEAN across 4,243 registry rows and 377 cards plus manual resolution of every XAU/XAG neighbor."
---

# QM5_20186 XAU/XAG Same-Calendar Relative Seasonality

## Hypothesis

Commodity supply, demand, hedging, and capital-allocation pressures can recur
in the same calendar month. At each month boundary, this card estimates gold's
and silver's historical return for that calendar month across prior years,
buys the metal with the stronger seasonal average, and shorts the weaker.

Opposite legs aim to suppress their common precious-metal and USD factor while
retaining relative monetary-gold versus industrial-silver seasonality. That is
a market-neutral construction objective, not proof of dollar, beta,
volatility, or portfolio neutrality. Q02 and unchanged downstream gates must
establish economics, execution quality, and realized correlation.

## Source traceability

The approved composite packet
`strategy-seeds/sources/KELOHARJU-FMR-XAUXAG-SAMECAL-2026/source.md` preserves
the two completely reviewed parent lineages and the current retrieval-policy
evidence. Keloharju, Linnainmaa, and Nyberg supply the recurring
same-calendar-month commodity rank and five-year minimum history. Fuertes,
Miffre, and Rallis supply the governed XAU/XAG cross-sectional commodity
carrier and one-month hold.

Neither paper tests this two-name same-calendar CFD basket, equal stop-risk
halves, ATR stops, or QM portfolio behavior. Runtime reads only registered
Darwinex MT5 prices, calendar, symbol, execution, position, deal, and framework
state; no external source is queried by the EA.

## Non-duplicate decision

The deterministic pre-allocation check returned `CLEAN` for slug
`xauxag-samecal`, strategy ID
`KELOHARJU-FMR-XAUXAG-SAMECAL-2026_S01`, and the exact mechanic.

- `QM5_20157` and `QM5_20161` fade a log ratio or rolling OLS residual.
- `QM5_20012` and `QM5_13205` use threshold or quantile cointegration.
- `QM5_12724` follows a ratio channel breakout; `QM5_12862` fades a ten-D1
  return-spread shock.
- `QM5_20019` and `QM5_20095` trade weekend or Monday session differentials.
- `QM5_20057`, `QM5_20184`, and `QM5_20050` rank contiguous one-, three-, and
  twelve-month returns rather than recurring prior-year calendar-month returns.
- `QM5_13115` applies same-calendar ranking to XTI/XNG energy, never to metals.

The historical same-calendar estimator, XAU/XAG pair, relative direction, and
monthly lifecycle are jointly load-bearing.

## Markets, timeframe, and cadence

- Logical basket: `QM5_20186_XAU_XAG_SAMECAL_D1`.
- Host/slot 0: `XAUUSD.DWX`, D1, magic `201860000`.
- Companion/slot 1: `XAGUSD.DWX`, D1, magic `201860001`.
- Decision: first tradable XAU D1 bar of every broker month.
- Formation: exactly ten prior years inspected for the decision calendar
  month; at least five synchronized paired samples required.
- Hold: until the next broker-month boundary, with a 40-calendar-day guard.
- Expected cadence: approximately 12 completed packages/year after warm-up;
  retire below five/year.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Rules

The following rules are the complete authorized baseline. No parameter sweep
or post-result rescue is authorized.

## 4. Entry Rules

1. Require exact EA 20186, `XAUUSD.DWX` D1 host, slot 0, all frozen inputs,
   and both registered symbols selected.
2. Evaluate only on the first tradable host D1 bar of a new broker month.
3. Persist the month attempt before history, signal, news, spread, quote,
   stop, lot, or order gates. Never retry the month after a flat, blocked,
   rejected, stopped, partially opened, or restarted decision.
4. For the decision calendar month, inspect exactly the ten prior calendar
   years. For each year reconstruct its completed month-end close and the
   preceding month-end close on both legs.
5. Retain a sample only when both endpoint timestamps match across XAU and XAG.
   Require at least five paired samples.
6. Calculate each paired log return, average by leg, and subtract
   `mean_XAG` from `mean_XAU`.
7. If the score is above `1e-12`, BUY XAU and SELL XAG. If below `-1e-12`,
   SELL XAU and BUY XAG. Otherwise remain flat for the consumed month.
8. Require completed D1 `ATR(20)`, nonnegative spreads no greater than 1,500
   XAU points and 3,000 XAG points, and executable prices for both legs.
9. Split the one fixed-risk package budget equally by per-leg stop risk and
   attach frozen `3.5 * ATR(20)` stops. No take-profit is authorized.
10. Prepare both legs before submission. If the second leg fails or the final
    package is malformed, immediately flatten every opened leg.

## 5. Exit Rules

1. At the first host D1 bar of the next broker month, close both old legs
   before evaluating a replacement.
2. Close both legs after 40 elapsed calendar days if the normal month boundary
   is unavailable.
3. Immediately flatten a one-leg orphan, same-direction pair, duplicate leg,
   missing hard stop, wrong magic, or other malformed package.
4. Per-leg frozen broker stops and the framework kill switch remain
   authoritative.
5. Friday close is disabled for the source-aligned month hold. No target,
   signal reversal, trail, break-even, partial close, or discretionary exit is
   authorized inside the month.

## 6. Filters (No-Trade Module)

- Fail closed for wrong host, timeframe, EA, slot, unlocked input, malformed
  month boundary, consumed month, existing package, or same-month deal.
- Fail closed for missing/nonconsecutive endpoints, cross-leg timestamp
  mismatch, fewer than five paired samples, nonpositive close, invalid
  logarithm, exact-zero score, invalid ATR/price/point/lot metadata, negative
  spread, excessive spread, or failed package preparation.
- Lock both news axes and legacy news mode OFF for this native-price Q02
  baseline. Lifecycle and orphan exits are never delayed by entry gates.
- Runtime may not read a futures curve, contract chain, volume, open interest,
  COT, external calendar, file, API, analyst forecast, or model output.

## 7. Trade Management Rules

- Maintain exactly one XAU leg and one oppositely directed XAG leg, each with
  its registered magic and frozen stop.
- One shared fixed-risk package budget, split equally by stop risk; no claim of
  exact dollar or beta neutrality is made.
- Consume at most one decision per broker month. Terminal-persistent state and
  deal/position history prevent restart re-entry; future-dated tester state is
  cleared at initialization.
- Close old-month and malformed exposure before entry-only gates.
- No grid, martingale, pyramid, partial close, scale-in, randomness, adaptive
  fit, or discretionary override.

## Parameters to test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_history_years` | 10 | [10] | bounded prior same-month years |
| `strategy_min_history_years` | 5 | [5] | minimum synchronized samples |
| `strategy_history_bars` | 3000 | [3000] | bounded D1 reconstruction buffer |
| `strategy_atr_period_d1` | 20 | [20] | completed per-leg risk estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | basket order deviation |

## Author claims

Keloharju, Linnainmaa, and Nyberg support recurring same-calendar information
in a broad commodity cross-section. Fuertes, Miffre, and Rallis support the
governed XAU/XAG cross-sectional carrier. Neither source claims that this
two-metal seasonal reduction, CFD execution, risk controls, or portfolio
objective is profitable. No source PF, return, drawdown, count, cost, hedge,
or correlation statistic is imported.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Narrow two-name breadth, common-metal beta, industrial
silver cyclicality, limited same-month samples, CFD rolls/basis, financing,
gaps, asymmetric stops, legging, and two-leg costs are first-order kill risks.

Retire on zero trades or fewer than five completed packages/year after warm-up.
Fail on wrong direction, unsynchronized history, duplicate month entry,
orphan persistence, hold beyond 40 days, missing stop, invalid risk mode,
nondeterminism, or any governed PF/DD failure. Do not rescue failure by
changing history, sample floor, score sign, pair, entry clock, stops, hold,
spread caps, or retry policy. Later gates must reject the sleeve if it does not
diversify the certified book; no correlation waiver is authorized.

## Strategy allowability check

- [x] R1: two peer-reviewed named-author lineages with complete durable
  repository reviews.
- [x] R2: fixed calendar estimator, synchronized sample floor, relative rank,
  monthly attempt state, shared risk, stops, and deterministic repair.
- [x] R3: registered synchronized XAU/XAG D1 history and native inputs only.
- [x] R4: deterministic calendar/OHLC/logarithm/ATR arithmetic; no trained
  model, prohibited runtime component, grid, martingale, scale-in, or pyramid.
- [x] Dedup: deterministic CLEAN plus manual resolution of all pair neighbors.

## Framework alignment

- no_trade: exact host/D1/EA/slot, locked inputs, history, synchronization,
  arithmetic, spread, quote, stop, lot, consumed-month, and package guards.
- trade_entry: first monthly D1 bar, prior-year same-calendar relative rank,
  two opposite legs, shared fixed risk, and frozen stops.
- trade_management: old-month, stale, orphan, composition, direction, magic,
  and stop repair before entry gates.
- trade_close: framework basket close, per-leg broker stops, and kill switch.

## Safety boundary

This approval covers one card, deterministic registries, one EA build, strict
compile, one logical-basket `RISK_FIXED` backtest setfile, and one paced Q02
enqueue. It does not authorize a manual backtest, live setfile, AutoTrading,
`T_Live`, a deploy manifest, portfolio admission, portfolio-gate change,
portfolio KPI claim, or correlation waiver.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-31 | source-backed XAU/XAG same-calendar rank card | G0 | APPROVED |
| v1-q02 | 2026-07-31 | strict build recorded and logical basket enqueued | Q02 | QUEUED |

## Pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-31 | APPROVED | this card and governed source packet |
| Q01 Build Validation | 2026-07-31 | PASS | `D:/QM/reports/framework/21/build_check_20260731_132521.json` |
| Q02 Baseline Screening | 2026-07-31 | QUEUED | work item `d6305296-8823-42f6-8604-37725d037617` |
