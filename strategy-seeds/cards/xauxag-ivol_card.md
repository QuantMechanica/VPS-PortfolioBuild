---
card_schema_version: 2
ea_id: QM5_20192
slug: xauxag-ivol
type: strategy
strategy_id: FUERTES-MOMIVOL-2015_XAU_XAG_S03
variant_id: FUERTES-MOMIVOL-2015_XAU_XAG_S03
source_id: FUERTES-MOMIVOL-2015
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20192_xauxag-ivol_card.md
execution_contract_status: DRAFT
created: 2026-08-01
created_by: Research+Development
last_updated: 2026-08-01
source_authors: "Ana-Maria Fuertes; Joelle Miffre; Adrian Fernandez-Perez"
strategy_mechanic: monthly-252d-ols-idiosyncratic-volatility-rank-xau-xag-two-leg-basket
source_citation: "Fuertes, Miffre, and Fernandez-Perez (2015), Commodity Strategies Based on Momentum, Term Structure and Idiosyncratic Volatility, Journal of Futures Markets 35(3), 274-297."
source_citations:
  - type: peer_reviewed_paper
    citation: "Fuertes, Ana-Maria; Miffre, Joelle; and Fernandez-Perez, Adrian (2015). Commodity Strategies Based on Momentum, Term Structure and Idiosyncratic Volatility. Journal of Futures Markets 35(3), 274-297."
    location: "Complete open accepted manuscript reviewed in the governed packet; equation (1), Sections 3.1-3.2, Tables 1-3 and 6, Appendices A-B; DOI https://doi.org/10.1002/fut.21656; strategy-seeds/sources/FUERTES-MOMIVOL-2015/source.md"
    quality_tier: A
    role: primary_method
sources:
  - "[[sources/FUERTES-MOMIVOL-2015]]"
concepts:
  - "[[concepts/idiosyncratic-volatility]]"
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/commodity-factor-residual]]"
indicators:
  - "[[indicators/ols-residual-volatility]]"
  - "[[indicators/equal-weight-commodity-factor]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, idiosyncratic-volatility, cross-sectional-rank, market-neutral-basket, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
factor_symbols: [XTIUSD.DWX, XNGUSD.DWX, XAUUSD.DWX, XAGUSD.DWX]
markets: [commodities, precious_metals]
single_symbol_only: false
logical_symbol: QM5_20192_XAU_XAG_IVOL_D1
symbol: QM5_20192_XAU_XAG_IVOL_D1
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "One two-leg XAU/XAG package per broker month after the 253-close warm-up; approximately 12 completed packages/year before Q02 validation."
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
q02_status: ENQUEUED
review_focus: "Falsify a relative precious-metals residual-risk premium whose signal is factor-idiosyncratic volatility rather than ratio level, price residual, calendar return, or momentum; neutrality, profitability, and book decorrelation are not imported."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, synchronized_history, aggregate_fixed_risk, restart_attempt_state, magic_schema, cfd_futures_basis, narrow_cross_section, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission 2026-08-01: R1 peer-reviewed fully reviewed source; R2 locked 252-D1 OLS residual-volatility estimator, four-proxy factor, low-IVol-long/high-IVol-short rank, shared risk, stops, monthly attempt and exit, and orphan repair; R3 registered XAU/XAG/XTI/XNG D1; R4 native deterministic arithmetic only. Deterministic checker found only same-source energy fuzzy matches; manual carrier and mechanic review found no XAU/XAG IVol rank."
---

# QM5_20192 XAU/XAG Pure Idiosyncratic-Volatility Spread

## Hypothesis

Commodity-specific volatility left after removing a broad commodity return
factor may carry a cross-sectional premium. Once per broker month, this sleeve
estimates gold and silver residual volatility against the same equal-weight
XTI/XNG/XAU/XAG factor, buys the lower-IVol metal, and shorts the higher-IVol
metal for one month.

The opposing metal legs target relative residual-risk exposure rather than an
outright precious-metal view. They do not prove dollar, beta, volatility, or
portfolio neutrality. Q02 must establish density and economics, and Q09 alone
may establish realized correlation to the certified XAU/SP500/NDX/XNG book.

## Source Traceability

The durable extraction authority is
`strategy-seeds/sources/FUERTES-MOMIVOL-2015/source.md`. Fuertes, Miffre, and
Fernandez-Perez (2015) study 27 commodity futures, explicitly including gold
and silver. Their standalone IVol strategy estimates rolling OLS residual
standard deviation against a traditional commodity benchmark, buys the lowest
IVol cross-section, sells the highest, and rebalances monthly. They test 1-,
3-, 6-, and 12-month formation windows and allow a one-top/one-bottom
implementation in sensitivity analysis.

The complete accepted manuscript was previously reviewed end-to-end and that
review is recorded in the governed packet. A fresh generic-PDF request on
2026-08-01 was policy-deferred, so this card uses no fresh page text or uncited
claim. It imports no source return, Sharpe ratio, constituent frequency,
correlation, hedge ratio, or execution statistic.

The paper does not test a four-CFD factor, a two-metal Darwinex basket,
equal-notional risk translation, continuous-CFD financing, restart behavior,
or the QM book. Those are explicit falsification risks.

## Non-Duplicate Decision

The deterministic pre-allocation check scanned 4,248 EA-registry rows and 379
cards. It found no exact duplicate and returned only the expected fuzzy
same-source matches:

- `QM5_13133_energy-ivol` trades XTI/XNG with XAU/XAG read-only; this card
  trades XAU/XAG with XTI/XNG read-only.
- `QM5_13113_energy-mom-ivol` additionally requires momentum/IVol rank
  agreement and trades XTI/XNG; this card has no momentum input.

Manual semantic review separates every built XAU/XAG neighbor:

- `QM5_12577`, `QM5_20157`, `QM5_20161`, `QM5_20012`, and `QM5_13205` trade
  ratio, price-residual, threshold-cointegration, or conditional-quantile
  convergence states.
- `QM5_12724` follows a ratio channel breakout; `QM5_12862` fades a short
  return-spread shock.
- `QM5_20050`, `QM5_20057`, and `QM5_20184` rank prior returns, not residual
  volatility.
- `QM5_20019`, `QM5_20095`, `QM5_20186`, and `QM5_20189` use weekday or
  same-calendar return effects.

The four-proxy factor, 252-return OLS residual standard deviations, XAU/XAG
low-minus-high IVol rank, and monthly two-leg carrier are jointly
load-bearing. Replacing the signal with a ratio, spread z-score, return rank,
calendar rule, total volatility, or momentum agreement recreates another
family.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_20192_XAU_XAG_IVOL_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1, magic `201920000`.
- Traded slot 1: `XAGUSD.DWX`, D1, magic `201920001`.
- Read-only factor members: `XTIUSD.DWX` and `XNGUSD.DWX`.
- Formation: 252 synchronized completed D1 log returns from 253 closes.
- Decision: first tradable XAU D1 bar of each broker month.
- Hold: next broker-month transition, with a 35-calendar-day stale guard.
- Expected cadence: approximately 12 completed packages/year after warm-up;
  retire below five/year.

## Rules

The following formula, entry, exit, filter, and management rules are the
complete authorized Q02 baseline. There is no baseline sweep.

For completed D1 observation `t`, form:

```text
factor[t] = 0.25 * (r_XTI[t] + r_XNG[t] + r_XAU[t] + r_XAG[t])
r_metal[t] = alpha_metal + beta_metal * factor[t] + epsilon_metal[t]
IVol_metal = sqrt(sum(epsilon_metal[t]^2) / (252 - 2))
```

An exact or numerical tie within `1e-12`, zero factor variance, invalid OLS,
or incomplete synchronized history stays flat for the consumed month.

## 4. Entry Rules

1. Require exact EA ID `20192`, XAU D1 host, magic slot 0, and every baseline
   input locked to the values below.
2. Evaluate only at a genuine XAU D1 broker-month transition.
3. Close an older package first. Persist the current month attempt before
   history, signal, spread, quote, news, stop, risk, or order gates. A flat,
   blocked, rejected, stopped, or partially opened month cannot retry after a
   restart.
4. Load exactly 253 synchronized completed D1 closes for XTI, XNG, XAU, and
   XAG. Reject missing, stale, nonpositive, or timestamp-misaligned data.
5. Form 252 log returns and the equal-weight four-proxy factor. Fit separate
   intercept-plus-factor OLS regressions for XAU and XAG and compute residual
   standard deviations with denominator `252 - 2`.
6. If `IVol_XAU < IVol_XAG - 1e-12`, BUY XAU and SELL XAG. If
   `IVol_XAU > IVol_XAG + 1e-12`, SELL XAU and BUY XAG. Otherwise remain flat.
7. Require acceptable spreads, executable quotes, completed ATR(20), valid
   symbol/volume metadata, registered magics, and news gates.
8. Attach a frozen `3.0 * ATR(20,D1)` hard stop to each leg. Split one package
   `RISK_FIXED` budget using relative stop distances to target equal
   pre-rounding dollar notionals; reject more than 20% post-rounding mismatch.
9. Open XAU first and XAG second. Retain the package only if exactly one
   correctly directed, stopped position exists in each registered slot. Any
   second-leg or final-composition failure flattens every owned leg.

## 5. Exit Rules

1. Close both legs on the first tradable D1 bar of the next broker month
   before considering replacement risk.
2. Close both legs after 35 calendar days as a stale guard.
3. Immediately flatten an orphan, duplicate, wrong-symbol, same-direction,
   wrong-magic, or missing-stop package.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source hold spans month-end weekends.
6. No take-profit, trailing, break-even, partial close, scale-in, grid,
   martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside `XAUUSD.DWX` D1 slot 0 or on unlocked parameters.
- Require synchronized completed timestamps across all four factor members,
  positive closes, finite returns, positive factor variance, valid OLS
  residuals, and a non-tied rank.
- Require nonnegative current spreads no greater than 1,500 points for XAU and
  3,000 points for XAG.
- Require valid ATR, quotes, tick-size/value, volume steps, stops, magics,
  notional match, attempt state, and package state.
- Q02 freezes both news axes OFF. No external calendar or data file is read.

## 7. Trade Management Rules

- Exactly two opposite positions are permitted: XAU slot 0 and XAG slot 1.
- One shared fixed budget covers the package; each leg retains its original
  server-side hard stop.
- Validate composition and stops every tick. Flatten the full package if one
  leg is absent or malformed.
- Close at the next month boundary or the 35-day stale limit. A consumed month
  cannot retry after a stop or repair.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_ivol_lookback_d1` | 252 | [252] | completed OLS observations |
| `strategy_atr_period_d1` | 20 | [20] | completed-bar stop volatility |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_notional_mismatch_pct` | 20.0 | [20.0] | rounded neutrality guard |
| `strategy_max_hold_days` | 35 | [35] | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread cap |
| `strategy_deviation_points` | 20 | [20] | basket order deviation |

Changing the factor membership, estimator, formation horizon, direction,
carrier, cadence, stop, sizing, mismatch guard, retry policy, or risk mode
requires a new card and full pipeline run.

## Risk And Test Contract

The canonical Q02 setfile uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. Both legs share that one budget. Q02 evaluates the
logical basket, not standalone XAU and XAG results.

Primary risks are two-name breadth, factor self-inclusion, futures-to-CFD
translation, XAG liquidity and gaps, financing, synchronized-history gaps,
legging, lot granularity, residual-volatility instability, and unintended
metal beta. Retire on fewer than five completed packages/year, nonpositive
governed economics, nondeterminism, invalid basket accounting, aggregate-risk
breach, orphan persistence, missing stops, wrong magic/direction, or later
correlation rejection. No correlation waiver is authorized.

## Strategy Allowability Check

- [x] R1 reputable: peer-reviewed *Journal of Futures Markets* paper with DOI
  and a durable complete-manuscript review.
- [x] R2 mechanical: fixed factor, OLS estimator, IVol rank, direction, shared
  risk, stops, attempt state, monthly exit, and repair.
- [x] R3 testable: registered XTI/XNG/XAU/XAG D1 histories; XAU/XAG are traded.
- [x] R4 compliant: deterministic native calendar/OHLC/OLS/ATR arithmetic; no
  trained model, external runtime feed, banned indicator, grid, martingale,
  scale-in, or pyramiding.
- [x] Dedup: no exact match; same-source energy fuzzy matches manually resolved
  by traded carrier and absence of a momentum gate.

## Framework Alignment

- no_trade: exact host/timeframe/slot, locked inputs, synchronized history,
  factor variance, OLS residual, spread, quote, ATR, metadata, magic,
  notional, package, and attempt guards.
- trade_entry: monthly low/high IVol rank, opposite orders, shared fixed-risk
  sizing, hard stops, and atomic repair.
- trade_management: package validation, next-month close, stale close, and
  orphan cleanup.
- trade_close: framework close helper plus broker hard stops and kill switch.

## Source-Defined Rules

- Estimate each commodity's idiosyncratic volatility as the standard deviation
  of residuals from a rolling OLS regression on a traditional commodity
  factor.
- Rank the cross-section monthly, buy the lowest-IVol member, sell the
  highest-IVol member, and hold the long-short portfolio for one month.
- The paper tests a 12-month formation window, an equal-weight commodity
  benchmark alternative, and a one-top/one-bottom implementation. It includes
  gold and silver in the source universe.

The source does not prescribe Darwinex symbols, CFD lot sizing, hard stops,
spread limits, retry state, or a four-name factor. Those are QM translations
and are not represented as source findings.

## QM Interpretations

- Translate the source's 12-month window to exactly 252 synchronized completed
  D1 returns from 253 aligned closes.
- Use the equal-weight return of XTI, XNG, XAU, and XAG as the bounded native
  commodity factor. Estimate XAU and XAG residual volatility separately and
  trade only those two metals.
- Treat the first tradable XAU D1 bar after a broker-month change as the monthly
  formation event. A difference at or below `1e-12` is a tie and stays flat.
- Interpret low/high rank only as the pair direction. The package is not
  asserted to be dollar-, beta-, volatility-, or portfolio-neutral.

## Framework Execution Overrides

- Freeze the backtest at `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`; both legs consume one aggregate risk budget.
- Use independent `3.0 * ATR(20,D1)` server-side stops and translate the shared
  risk budget toward equal dollar notional, rejecting more than 20% rounded
  notional mismatch.
- Apply explicit XAU/XAG spread caps, atomic second-leg failure repair, magic
  and direction checks, missing-stop repair by full flatten, and a 35-day stale
  guard.
- Disable both news axes, legacy news mode, Friday close, and stress rejection.
  Consume persistent month-attempt state before any fallible entry gate so a
  failed or stopped package cannot retry in the same month.

## Exit Precedence

1. Framework kill-switch handling takes precedence on every tick.
2. A missing, extra, wrong-direction, wrong-magic, or stopless leg flattens the
   complete package immediately.
3. Broker-side hard stops remain live independently for each leg; any resulting
   orphan is flattened on the next handled tick.
4. At a genuine broker-month transition, a prior-month package is closed
   before any new package can be considered.
5. The 35-calendar-day stale guard closes any package that survives without a
   recognized month transition. There is no discretionary or signal-flip exit.

## Runtime Data Dependencies

- Completed D1 OHLC history for `XTIUSD.DWX`, `XNGUSD.DWX`, `XAUUSD.DWX`, and
  `XAGUSD.DWX`, including 253 exactly aligned closes and gaps no larger than
  seven calendar days.
- Current XAU/XAG bid/ask quotes, tick size/value, point, volume bounds and
  steps, plus completed D1 ATR inputs for both traded legs.
- Broker time for month boundaries and terminal global-variable storage for
  persistent attempt state. No network feed, future data, custom indicator,
  trained model, or external calendar is required at runtime.

## Falsification And Requalification

Q02 retires the candidate on fewer than five completed packages/year,
nonpositive governed economics, nondeterministic signals, invalid combined
basket accounting, missing or orphaned legs, aggregate-risk breach, or material
cost failure. Q09 alone can test realized portfolio orthogonality; this card
grants no correlation waiver.

A change to factor constituents, alignment rule, estimator, lookback, carrier,
direction, formation cadence, stop, sizing, mismatch guard, retry behavior, or
risk mode is a new strategy variant and requires a new approved card and full
requalification.

## Safety Boundary

This approval covers one branch-only card, deterministic allocation, V5 build,
strict compile, one `RISK_FIXED` backtest setfile, one basket manifest, and one
paced Q02 enqueue. It does not authorize a live setfile, AutoTrading,
`T_Live`, a deploy or T_Live manifest, portfolio admission, a portfolio-gate
change, portfolio KPI claim, or a correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-01 | initial XAU/XAG pure-IVol carrier | G0 | APPROVED |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-01 | APPROVED | this card and governed source packet |
| Q01 Build Validation | 2026-08-01 | PASS | strict build check `D:/QM/reports/framework/21/build_check_20260801_083647.json`; zero failures and zero warnings |
| Q02 Baseline Screening | 2026-08-01 | ENQUEUED | work item `37be7fda-97c5-403a-9e99-4dfc22594621`; pending and unclaimed at confirmation |
