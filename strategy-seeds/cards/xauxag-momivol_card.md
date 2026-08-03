---
card_schema_version: 2
ea_id: QM5_20206
slug: xauxag-momivol
type: strategy
strategy_id: FUERTES-MOMIVOL-2015_XAU_XAG_S04
variant_id: FUERTES-MOMIVOL-2015_XAU_XAG_S04
source_id: FUERTES-MOMIVOL-2015
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20206_xauxag-momivol_card.md
execution_contract_status: DRAFT
created: 2026-08-03
created_by: Research+Development
last_updated: 2026-08-03
source_authors: "Ana-Maria Fuertes; Joelle Miffre; Adrian Fernandez-Perez"
strategy_mechanic: monthly-63d-xau-xag-relative-momentum-and-ols-idiosyncratic-volatility-rank-agreement
source_citation: "Fuertes, Miffre, and Fernandez-Perez (2015), Commodity Strategies Based on Momentum, Term Structure and Idiosyncratic Volatility, Journal of Futures Markets 35(3), 274-297."
source_citations:
  - type: peer_reviewed_paper
    citation: "Fuertes, Ana-Maria; Miffre, Joelle; and Fernandez-Perez, Adrian (2015). Commodity Strategies Based on Momentum, Term Structure and Idiosyncratic Volatility. Journal of Futures Markets 35(3), 274-297."
    location: "Complete open accepted manuscript reviewed in the governed packet; momentum and IVol construction pp. 6-10, combined screens pp. 13-19, Table 7 p. 34, one-top/one-bottom sensitivity p. 16, and source constituents in Appendix A; DOI https://doi.org/10.1002/fut.21656; strategy-seeds/sources/FUERTES-MOMIVOL-2015/source.md"
    quality_tier: A
    role: primary_method
sources:
  - "[[sources/FUERTES-MOMIVOL-2015]]"
concepts:
  - "[[concepts/cross-sectional-momentum]]"
  - "[[concepts/idiosyncratic-volatility]]"
  - "[[concepts/precious-metals-relative-value]]"
indicators:
  - "[[indicators/completed-return]]"
  - "[[indicators/ols-residual-volatility]]"
  - "[[indicators/equal-weight-commodity-factor]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, momentum, idiosyncratic-volatility, agreement-filter, market-neutral-basket, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
factor_symbols: [XTIUSD.DWX, XNGUSD.DWX, XAUUSD.DWX, XAGUSD.DWX]
markets: [commodities, precious_metals]
single_symbol_only: false
logical_symbol: QM5_20206_XAU_XAG_MOMIVOL_D1
symbol: QM5_20206_XAU_XAG_MOMIVOL_D1
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "One monthly decision after the 64-close warm-up; strict rank agreement should produce approximately 5-8 XAU/XAG packages/year before Q02 validation."
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
q02_status: ENQUEUED
q02_work_item_id: 46fef851-87fd-4e85-adef-554ed0022088
review_focus: "Falsify a relative precious-metal momentum/IVol intersection rather than outright XAU direction: only the 63-D1 momentum winner that is also the lower factor-residual-volatility metal is held against the other leg; Q09 alone may establish book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, synchronized_history, aggregate_fixed_risk, restart_attempt_state, magic_schema, cfd_futures_basis, narrow_cross_section, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the OWNER 2026-08-03 commodity/energy sleeve mission: R1 completely reviewed peer-reviewed source; R2 locked 63-D1 momentum and four-proxy OLS IVol ranks, strict agreement, shared risk, stops, monthly attempt and exit, and orphan repair; R3 registered XTI/XNG/XAU/XAG D1 histories; R4 deterministic native arithmetic only. Exact dedup clear; expected same-source fuzzy neighbors manually resolved by traded carrier or missing signal gate."
---

# QM5_20206 XAU/XAG Momentum–Idiosyncratic-Volatility Double Screen

## Hypothesis

Relative precious-metal performance and commodity-factor-residual risk are
different information objects. A monthly package that buys the stronger of
gold and silver only when it is also the lower-IVol metal, while shorting the
other metal, may isolate a structural relative-value premium with less common
metal beta than an outright XAU signal.

The opposite legs do not prove market, dollar, beta, volatility, or portfolio
neutrality. Q02 must establish trade density and economics, and the unchanged
Q09 portfolio gate alone may establish realized decorrelation from the
XAU/SP500/NDX/XNG book.

## Source Traceability And Claim Boundary

The canonical packet is
`strategy-seeds/sources/FUERTES-MOMIVOL-2015/source.md`. Fuertes, Miffre, and
Fernandez-Perez (2015) estimate commodity IVol from rolling factor-regression
residuals, rank past performance and IVol separately, and test double screens
with monthly formation and one-month holding. The source includes 3-month
formation and a one-top/one-bottom sensitivity; gold and silver are source
constituents.

The paper trades a broad exchange-futures cross-section and also studies term
structure, which the Darwinex runtime cannot reproduce. This card retains only
the momentum/IVol intersection and narrows it to two continuous CFDs plus a
four-proxy native factor. No source return, Sharpe, drawdown, significance,
constituent frequency, neutrality, cost, or correlation statistic is imported.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,262 registry rows and 385
cards, found no exact duplicate, and returned three expected fuzzy matches:

- `QM5_13113_energy-mom-ivol` trades XTI/XNG and reads XAU/XAG only as factor
  members; this card trades XAU/XAG.
- `QM5_20192_xauxag-ivol` ranks 252-D1 pure IVol and has no momentum gate.
- `QM5_20184_xauxag-xmom3` ranks 63-D1 momentum and has no IVol gate.

Ratio z-score, OLS price-level residual, conditional-quantile, calendar,
one-month/twelve-month momentum, and long-horizon reversal XAU/XAG systems use
different states. The four-symbol factor, 63-return OLS residual standard
deviation, 63-D1 relative momentum, strict rank agreement, flat disagreement
regime, and XAU/XAG traded carrier are jointly load-bearing.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_20206_XAU_XAG_MOMIVOL_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1, magic `202060000`.
- Traded slot 1: `XAGUSD.DWX`, magic `202060001`.
- Read-only factor members: `XTIUSD.DWX` and `XNGUSD.DWX`.
- Formation: 63 synchronized completed D1 log returns from 64 closes.
- Decision: first tradable XAU D1 bar of each broker month.
- Hold: next broker-month transition, with a 35-calendar-day stale guard.
- Expected cadence: approximately 5-8 completed packages/year; retire below
  five/year.

## Rules

The signal, entry, exit, filter, sizing, and lifecycle rules below are the
complete frozen Q02 baseline. There is no parameter sweep or fallback trade.

For synchronized completed observation `t`, form:

```text
factor[t] = 0.25 * (r_XTI[t] + r_XNG[t] + r_XAU[t] + r_XAG[t])
r_metal[t] = alpha_metal + beta_metal * factor[t] + epsilon_metal[t]
IVol_metal = sqrt(sum(epsilon_metal[t]^2) / (63 - 2))
Mom_metal = ln(close_metal[latest] / close_metal[oldest])
```

- `Mom_XAU > Mom_XAG` and `IVol_XAU < IVol_XAG`: BUY XAU, SELL XAG.
- `Mom_XAU < Mom_XAG` and `IVol_XAU > IVol_XAG`: SELL XAU, BUY XAG.
- Rank disagreement, either tie within `1e-12`, zero factor variance, invalid
  OLS, or incomplete synchronized history: remain flat for the consumed month.

## 4. Entry Rules

1. Require exact EA ID `20206`, XAU D1 host, magic slot 0, and every baseline
   input locked to the values below.
2. Process lifecycle exits before entry-only gates and evaluate only at a
   genuine broker-month transition.
3. Persist the current month attempt before history, signal, spread, quote,
   news, stop, sizing, or order gates. A flat, blocked, rejected, stopped, or
   restarted month cannot retry.
4. Reject an owned package, malformed owned position, or current-month entry
   deal. Load exactly 64 timestamp-aligned completed D1 closes for XTI, XNG,
   XAU, and XAG.
5. Form 63 log returns and their equal-weight factor. Fit separate
   intercept-plus-factor OLS regressions for XAU and XAG and compute residual
   standard deviations with denominator `63 - 2`.
6. Compute each metal's 63-D1 log return. Enter only when the higher-momentum
   metal is also the lower-IVol metal; ties and conflicts stay flat.
7. Require acceptable spreads, executable quotes, completed ATR(20), valid
   symbol/volume metadata, registered magics, and news gates.
8. Attach `3.0 * ATR(20,D1)` hard stops. Split one package `RISK_FIXED` budget
   using relative stop distances to target equal pre-rounding dollar notionals;
   reject more than 20% post-rounding mismatch.
9. Open XAU first and XAG second. Retain the package only when exactly one
   correctly directed, stopped position exists in each slot. Flatten all owned
   legs after a second-order or final-composition failure.

## 5. Exit Rules

1. Close both legs on the first tradable D1 bar of the next broker month before
   considering replacement risk.
2. Close both legs after 35 calendar days as a stale guard.
3. Immediately flatten an orphan, duplicate, wrong-symbol, same-direction,
   wrong-magic, or missing-stop package.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because the source hold spans month-end weekends.
6. No take-profit, trail, break-even, partial close, scale-in, grid,
   martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside `XAUUSD.DWX` D1 slot 0 or on unlocked parameters.
- Require synchronized completed timestamps across all four factor members,
  positive closes, finite returns, positive factor variance, valid OLS
  residuals, non-tied ranks, and strict momentum/IVol agreement.
- Require XAU spread in `[0,1500]` points and XAG spread in `[0,3000]` points.
- Require valid ATR, quotes, tick-size/value, volume steps, stops, magics,
  notional match, attempt state, and package state.
- Q02 freezes both news axes and legacy news mode OFF. No external calendar,
  futures chain, inventory, volume, open interest, CSV, API, or file is read.

## 7. Trade Management Rules

- Exactly two opposite positions are permitted: XAU slot 0 and XAG slot 1.
- One shared fixed budget covers the package; each leg retains its server-side
  hard stop.
- Validate composition and stops every tick. Flatten the full package if one
  leg is absent or malformed.
- Close at the next month boundary or 35-day stale limit. A consumed month
  cannot retry after a stop or repair.
- No hedge overlay, averaging, scale-in, pyramiding, grid, martingale, partial
  close, adaptive fit, or random path exists.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_signal_lookback_d1` | 63 | [63] | completed momentum and OLS observations |
| `strategy_atr_period_d1` | 20 | [20] | completed-bar stop volatility |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_notional_mismatch_pct` | 20.0 | [20.0] | rounded neutrality guard |
| `strategy_max_hold_days` | 35 | [35] | stale package guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread cap |
| `strategy_deviation_points` | 20 | [20] | basket order deviation |

Changing the factor, estimator, formation horizon, rank direction, agreement
gate, carrier, cadence, stop, sizing, mismatch guard, retry policy, or risk mode
requires a new card and full pipeline run.

## Risk

The canonical Q02 setfile uses one shared `RISK_FIXED=1000` package budget,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. `RISK_FIXED` is stop-normalized
loss budget, not fixed notional exposure. No live-risk mode is authorized.

Primary risks are two-name breadth, factor self-inclusion, futures-to-CFD
translation, XAG liquidity/gaps, financing, synchronized-history gaps, legging,
lot granularity, residual-volatility instability, agreement sparsity, common
metal beta, and correlation with the existing XAU sleeve. Retire below five
completed packages/year or on nonpositive governed economics, nondeterminism,
invalid basket accounting, aggregate-risk breach, orphan persistence, missing
stops, wrong magic/direction, or later correlation rejection. No parameter
rescue or correlation waiver is authorized.

## Strategy Allowability Check

- [x] R1 reputable: peer-reviewed *Journal of Futures Markets* paper with DOI,
  institutional accepted manuscript, and durable complete review.
- [x] R2 mechanical: fixed factor, 63-return OLS, momentum and IVol ranks,
  agreement mapping, shared risk, stops, attempt state, exit, and repair.
- [x] R3 testable: registered XTI/XNG/XAU/XAG D1 histories; XAU/XAG are traded.
- [x] R4 compliant: deterministic native calendar/OHLC/OLS/ATR arithmetic; no
  trained model, external runtime feed, banned indicator, grid, martingale,
  scale-in, or pyramiding.
- [x] Exact dedup clear; same-source fuzzy matches manually resolved by carrier
  or by the missing momentum/IVol gate.

## Framework Alignment

- no_trade: exact host/timeframe/slot, locked inputs, synchronized history,
  factor variance, ranks, agreement, spread, quote, ATR, metadata, magic,
  notional, package, and attempt guards.
- trade_entry: monthly momentum/IVol agreement, opposite orders, shared
  fixed-risk sizing, hard stops, and atomic repair.
- trade_management: package validation, next-month close, stale close, and
  orphan cleanup.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
logical-basket `RISK_FIXED` backtest setfile, one basket manifest, and one paced
Q02 enqueue. It does not authorize a live/demo/shadow setfile, AutoTrading,
`T_Live` access, a deploy or T_Live manifest, portfolio admission, a
portfolio-gate change, or a correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-03 | initial XAU/XAG momentum-IVol agreement basket | Q02 | ENQUEUED as work item `46fef851-87fd-4e85-adef-554ed0022088` |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-03 | APPROVED; R1-R4 PASS | this card, governed source packet, and durable decision |
| Q01 Build Validation | 2026-08-03 | PASS; 0 errors, 0 warnings, 0 build-check failures | `D:/QM/reports/framework/21/build_check_20260803_011438.json` |
| Q02 Baseline Screening | 2026-08-03 | ENQUEUED; pending, attempt 0, unclaimed at confirmation | work item `46fef851-87fd-4e85-adef-554ed0022088` |
