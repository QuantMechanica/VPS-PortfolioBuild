---
card_schema_version: 2
ea_id: QM5_20233
slug: xauxag-skew-rank
type: strategy
strategy_id: FERNANDEZ-SKEW-2018_XAU_XAG_S02
variant_id: FERNANDEZ-SKEW-2018_XAU_XAG_S02
source_id: FERNANDEZ-SKEW-2018
status: APPROVED
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20233_xauxag-skew-rank_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
source_authors: "Adrian Fernandez-Perez; Bart Frijns; Ana-Maria Fuertes; Joelle Miffre"
strategy_mechanic: monthly-xau-xag-prior-twelve-complete-month-pearson-return-skewness-low-minus-high-rank
source_citation: "Fernandez-Perez, Frijns, Fuertes, and Miffre (2018), The Skewness of Commodity Futures Returns, Journal of Banking & Finance 86, 143-158, DOI 10.1016/j.jbankfin.2017.06.015."
source_citations:
  - type: peer_reviewed_paper
    citation: "Fernandez-Perez, Adrian; Frijns, Bart; Fuertes, Ana-Maria; and Miffre, Joelle (2018). The Skewness of Commodity Futures Returns. Journal of Banking & Finance 86, 143-158."
    location: "Complete 44-page accepted manuscript; Sections 3.1 and 4.1-4.4, Equation 1, Tables I and III-V, and explicit gold/silver universe; DOI https://doi.org/10.1016/j.jbankfin.2017.06.015; governed packet strategy-seeds/sources/FERNANDEZ-SKEW-2018/source.md"
    quality_tier: A
    role: primary_method
sources:
  - "[[sources/FERNANDEZ-SKEW-2018]]"
concepts:
  - "[[concepts/commodity-skewness-premium]]"
  - "[[concepts/precious-metals-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/pearson-skewness]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, realized-skewness, cross-sectional-rank, market-neutral-basket, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
markets: [commodities, precious_metals]
single_symbol_only: false
logical_symbol: QM5_20233_XAU_XAG_SKEW_RANK_D1
symbol: QM5_20233_XAU_XAG_SKEW_RANK_D1
symbol_slot: 0
magic: 202330000
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "One monthly XAU/XAG package after the twelve-complete-month warm-up; approximately 12 completed packages/year before Q02 validation."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify a monthly relative precious-metal third-moment premium rather than outright XAU direction: long the lower-skew metal and short the higher-skew metal with one shared fixed-risk package; Q09 alone may establish book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, completed_month_history, aggregate_fixed_risk, restart_attempt_state, magic_schema, cfd_futures_basis, narrow_cross_section, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under the OWNER 2026-08-06 commodity/energy sleeve mission: R1 complete peer-reviewed JBF source with explicit gold and silver instruments; R2 locked prior-twelve-complete-month Pearson skewness, low-minus-high monthly rank, shared fixed risk, hard stops, consumed attempt, renewal, and orphan repair; R3 registered native XAU/XAG D1 histories; R4 deterministic native arithmetic only. Deterministic dedup found no exact identity and the expected same-source energy fuzzy match; manual carrier and metal-family review is clean."
---

# QM5_20233 XAU/XAG Commodity-Skewness Rank

## Hypothesis

Commodity investors and commercial hedgers can prefer lottery-like positive
skewness and avoid negative skewness, leaving high-skew contracts relatively
overpriced and low-skew contracts with a return premium. A monthly package
that buys the lower-skew of gold and silver and shorts the higher-skew metal
tests that structural third-moment premium while reducing common precious-
metal direction relative to an outright XAU strategy.

Opposite legs and equal fixed-risk halves do not prove dollar, beta,
volatility, market, or portfolio neutrality. Q02 must establish density and
economics. The unchanged Q09 gate alone may measure realized overlap with the
certified XAU/SP500/NDX/XNG book.

## Source Traceability And Claim Boundary

The governed packet is
`strategy-seeds/sources/FERNANDEZ-SKEW-2018/source.md`. Fernandez-Perez,
Frijns, Fuertes, and Miffre (2018) estimate Pearson's moment coefficient of
skewness from each commodity's preceding twelve months of daily log returns,
rank 27 futures monthly, buy the lowest-skew quintile, short the highest-skew
quintile, and hold for one month. Gold and silver are explicit members of the
source metal sector.

The source does not test a two-metal Darwinex CFD carrier, equal fixed-risk
halves, ATR stops, broker-month reconstruction, legging, financing, or the QM
portfolio. Its broad-universe returns, significance, risk-adjusted results,
cost estimates, and correlations do not transfer to this candidate.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,290 registry rows and 406
cards. It found no exact identity and one expected fuzzy same-source match,
`QM5_13118_energy-skew-rank`. Manual review fixes the boundary:

- `QM5_13118` trades XTI/XNG. This card locks its source estimator, direction,
  formation, and hold but tests the explicitly sourced XAU/XAG carrier under
  the governed carrier-port rule.
- Existing XAU/XAG ratio and OLS baskets trade level convergence or return-
  spread reversion. This card never calculates a price ratio, regression
  residual, spread z-score, or mean-reversion threshold.
- `QM5_13205_xau-xag-qc` fits asymmetric conditional price envelopes;
  `QM5_20192_xauxag-ivol` ranks factor-residual volatility; and
  `QM5_20206_xauxag-momivol` requires momentum/IVol agreement. None uses the
  standardized third moment of each metal's own completed returns.
- XAU/XAG calendar, weekend, shock, and relative-momentum builds use different
  information objects and clocks.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only oscillator
  pullback, not a paired monthly cross-sectional moment rank.

The exact twelve-complete-month return window, Pearson third standardized
moment, lower-skew long/higher-skew short direction, monthly lifecycle, and
XAU/XAG carrier are jointly load-bearing. Verdict:
`CLEAN_CARRIER_EXTENSION_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_20233_XAU_XAG_SKEW_RANK_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1, magic `202330000`.
- Traded slot 1: `XAGUSD.DWX`, D1, magic `202330001`.
- Decision: first tradable XAU D1 bar of each broker-calendar month.
- Formation: daily log returns wholly inside the twelve complete broker months
  immediately preceding the decision month; current-month data excluded.
- Hold: next broker-month transition, with a 35-calendar-day stale guard.
- Expected cadence: approximately 12 paired packages/year after warm-up;
  retire below five completed packages per full post-warm-up year.

## Rules

For each leg `i`, calculate all valid consecutive daily log returns in the
completed formation window. Require at least 180 returns and strictly positive
population variance. With `mu_i` the arithmetic mean:

`skew_i = mean((r_i - mu_i)^3) / mean((r_i - mu_i)^2)^(3/2)`

- `skew_XAU < skew_XAG`: BUY XAU and SELL XAG.
- `skew_XAU > skew_XAG`: SELL XAU and BUY XAG.
- Difference within `1e-12`, invalid arithmetic, or invalid history: consume
  the month and stay flat.

No price ratio, OLS beta, momentum, calendar direction, volatility rank,
adaptive threshold, or single-leg fallback enters the signal.

## 4. Entry Rules

1. Require exact EA ID `20233`, XAU host D1, slot 0, and the frozen input
   contract below.
2. Process lifecycle exits before entry gates and evaluate only on a genuine
   broker-month transition.
3. Persist the month attempt before history, signal, spread, quote, news,
   sizing, or order gates; same-month deal history is a second no-retry guard.
4. Require no owned leg, reconstruct the exact completed formation window,
   and compute valid Pearson skewness for both metals.
5. Select opposite directions using the strict low-skew-versus-high-skew rank.
6. Require both spreads within caps, valid quotes, completed `ATR(20,D1)`,
   symbol metadata, fixed-risk mode, and news gates.
7. Split one `RISK_FIXED` package budget equally across the legs and place a
   frozen `3.5 * ATR(20,D1)` server-side hard stop on each leg.
8. If the second order fails, immediately flatten the first leg. No one-leg
   strategy position is authorized.

## 5. Exit Rules

1. Close both legs on the first tradable XAU D1 bar of the next broker month
   before considering a replacement package.
2. Close the package after 35 calendar days as a stale guard.
3. Flatten an orphan, duplicate leg, same-side pair, wrong symbol, or wrong
   magic immediately.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled to preserve the source's one-month hold.
6. No intramonth rank flip, target, trail, break-even, partial close, scale-in,
   hedge overlay, grid, martingale, pyramid, or discretionary exit exists.

## 6. Filters (No-Trade Module)

- Fail closed outside the exact host, timeframe, EA ID, slots, symbols, and
  frozen parameter contract.
- Reject malformed formation bounds, insufficient observations, nonpositive
  closes or variance, nonfinite moments, a numerical tie, invalid ATR/quote/
  lot metadata, excessive spread, consumed attempt, same-month deal, or an
  existing owned leg.
- Q02 freezes both news axes and legacy news mode OFF. Runtime reads no
  external file, API, futures chain, volume, open interest, option surface,
  forecast, or trained output.

## 7. Trade Management Rules

- Exactly one logical two-leg package and one consumed attempt per broker
  month.
- Close before renewal, on stale age, invalid composition, orphaning, hard
  stop, or framework safety action.
- Terminal-global attempt state plus owned deal history survives restart and
  prevents same-month re-entry after a rejected or stopped package.
- No averaging, scale-in, pyramiding, grid, martingale, partial close,
  adaptive fitting, or random path exists.

## Parameters To Test

| parameter | baseline | authorized values | role |
|---|---:|---|---|
| `strategy_lookback_months` | 12 | [12] | source-defined complete-month formation |
| `strategy_history_bars` | 500 | [500] | bounded D1 reconstruction buffer |
| `strategy_min_return_observations` | 180 | [180] | fail-closed data sufficiency |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 35 | [35] | monthly stale guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | basket-order deviation |

Changing the formation, estimator, rank direction, carrier, package sizing,
hold, stop, or retry policy requires a new card and full pipeline run.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for the complete package. Each leg receives one half of
the fixed stop-risk budget. `RISK_FIXED` is a stop-normalized loss budget, not
fixed notional exposure. No live-risk mode is authorized.

Primary risks are the 27-future-to-two-CFD narrowing, skew-estimator noise,
gold/silver regime change, residual common-metal beta, unequal notionals,
futures-to-CFD basis, gaps, financing, legging, orphan repair, warm-up loss,
and later portfolio correlation. Retire below five packages/year or on
nonpositive governed economics, wrong rank direction, current-month leakage,
duplicate entry, restart nondeterminism, missing stop, broken basket
accounting, risk mismatch, or later correlation rejection. No rescue or
waiver is allowed.

## Strategy Allowability Check

- [x] R1 reputable: named-author peer-reviewed JBF paper with DOI, complete
  institutional accepted manuscript, and explicit gold/silver instruments.
- [x] R2 mechanical: fixed completed-month Pearson skewness, strict rank,
  monthly renewal, attempt state, package repair, hard stops, and stale exit.
- [x] R3 testable: registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 data.
- [x] R4 compliant: deterministic native arithmetic only; no trained output,
  banned indicator, external runtime feed, grid, martingale, scale-in, or
  pyramiding.
- [x] No exact identity; the same-source energy carrier and all metal-family
  fuzzy neighbors are manually resolved.

## Framework Alignment

- no_trade: exact host/slots, frozen inputs, completed-window history,
  arithmetic, spread, attempt, package, and framework gates.
- trade_entry: Pearson-skewness rank, opposite paired orders, equal fixed-risk
  halves, frozen ATR stops, and second-leg rollback.
- trade_management: next-month renewal, stale close, composition validation,
  and orphan cleanup.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Safety Boundary

This card authorizes one branch-only research build, strict compile, one
logical-basket `RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It
does not authorize a manual backtest; live, demo, or shadow setfiles;
AutoTrading; `T_Live`; a deploy or T_Live manifest; portfolio admission; a
portfolio-gate change; or a correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-06 | initial XAU/XAG skewness-rank carrier card | G0 | APPROVED |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | `decisions/2026-08-06_qm5_20233_xauxag_skew_rank_g0.md` |
| Q01 Compile / Static Validation | 2026-08-06 | NOT RUN | pending build |
| Q02 Baseline Screening | 2026-08-06 | NOT ENQUEUED | pending Q01 |
