---
card_schema_version: 2
type: strategy
strategy_id: CHAN-SCHWEIKERT-XAUXAG-CADF-2026_S01
variant_id: CHAN-SCHWEIKERT-XAUXAG-CADF-2026_S01
source_id: CHAN-SCHWEIKERT-XAUXAG-CADF-2026
ea_id: QM5_21526
slug: xau-xag-cadf
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_21526_xau-xag-cadf_card.md
execution_contract_status: APPROVED
created: 2026-08-15
created_by: Research+Development
last_updated: 2026-08-15
g0_status: APPROVED
g0_decision: decisions/2026-08-15_qm5_21526_xau_xag_cadf_g0.md
source_author: "Ernest P. Chan; Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_authors: "Ernest P. Chan; Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_citation: "Chan (2009), Quantitative Trading, Wiley; Schweikert (2018), Journal of Banking & Finance 88; Yaya, Vo, and Olayinka (2021), Resources Policy 72; CME Group Gold & Silver Ratio Spread."
source_citations:
  - type: book
    citation: "Chan, E. P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley."
    location: "Complete bounded Examples 3.6, 7.2, 7.3, and 7.5 extraction at strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md; ISBN 978-0-470-28488-9."
    quality_tier: A
    role: ols_cadf_frozen_training_zscore_and_half_life_method
  - type: peer_reviewed_papers
    citation: "Schweikert (2018), Journal of Banking & Finance 88, DOI 10.1016/j.jbankfin.2017.11.010; Yaya, Vo, and Olayinka (2021), Resources Policy 72, DOI 10.1016/j.resourpol.2021.102045."
    location: "Governed bounded packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md."
    quality_tier: A
    role: gold_silver_long_run_relation_and_state_dependence
  - type: exchange_research
    citation: "CME Group. Gold & Silver Ratio Spread."
    location: "Governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md."
    quality_tier: B
    role: precious_metals_intermarket_carrier
strategy_mechanic: annual-frozen-252d-log-xau-on-xag-ols-residual-one-lag-cadf-qualified-fresh-cross-reversion-fitted-half-life-two-leg-basket
sources:
  - "[[sources/CHAN-SCHWEIKERT-XAUXAG-CADF-2026]]"
concepts:
  - "[[concepts/cointegration-pair-trade]]"
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/ordinary-least-squares]]"
  - "[[indicators/cointegrating-augmented-dickey-fuller]]"
  - "[[indicators/ornstein-uhlenbeck-half-life]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, relative-value, cointegration-pair-trade, annual-walk-forward, mean-reach-exit, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals, gold, silver]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_21526_XAU_XAG_CADF_D1
symbol: QM5_21526_XAU_XAG_CADF_D1
symbol_slot: 0
magic: 215260000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eight to twenty completed gold/silver packages per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.05
expected_dd_pct: 24.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify a stationarity-qualified annual gold/silver residual stream designed to remove common precious-metal direction from the certified XAU/SP500/NDX/XNG book; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [annual_anchor_reconstruction, exact_synchronized_history, cadf_critical_boundary, fitted_half_life, basket_atomicity, aggregate_fixed_risk, no_excursion_retry, magic_schema, friday_close_disabled, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized XAU/XAG market-neutral candidate: R1 CEO-ratified complete Wiley extraction plus governed peer-reviewed gold/silver and CME carrier packets; R2 locked annual anchor, OLS, one-lag CADF, half-life, fresh crossing, paired lifecycle, stops, and aggregate risk; R3 registered XAU/XAG D1; R4 deterministic native arithmetic; exact dedup clean and the one CADF-family fuzzy match manually separated."
---

# QM5_21526 XAU/XAG Annual CADF Residual Reversion

## Hypothesis

Gold and silver share a source-supported but state-dependent long-run
relationship. A gold/silver package should therefore fade deviations only
when a pre-signal residual rejects a unit root and exhibits economically
bounded mean-reversion speed. Freezing one model for each broker calendar year
tests the source's train/test discipline without letting every new price
rewrite the equilibrium being traded.

The candidate buys one metal and sells the other. That removes some common
precious-metal direction but does not prove dollar, beta, volatility, factor,
market, or portfolio neutrality. Q02 owns density and economics; unchanged
Q09 alone owns realized book correlation.

## Source Traceability And Claim Boundary

The approved composite packet is
`strategy-seeds/sources/CHAN-SCHWEIKERT-XAUXAG-CADF-2026/source.md`, approved
under `decisions/2026-08-15_xau_xag_cadf_source_approval.md`.

Chan supplies the OLS/CADF/frozen-training/z-score/half-life method on GLD and
GDX. Schweikert and Yaya, Vo, and Olayinka supply bounded peer-reviewed
gold/silver relationship context, and CME supplies the intermarket carrier.
No source tests this Darwinex CFD package, annual reconstruction, parameter
set, hard-stop translation, fixed-risk sizing, costs, density, or QM book.
No source performance or decorrelation statistic transfers.

## Source-Defined Rules

- Chan defines the two-step pair method: estimate the hedge relationship on a
  bounded training sample, test the fitted residual for stationarity, measure
  deviations in residual standard deviations, fade sufficiently large
  deviations, and exit toward the fitted mean.
- Chan distinguishes cointegration from correlation and uses a separate
  training/test discipline plus fitted mean-reversion half-life.
- Schweikert and Yaya, Vo, and Olayinka support only a state-dependent
  long-run gold/silver relationship. CME supports only gold and silver as an
  intermarket ratio/spread carrier.
- No source defines this Darwinex CFD pair, broker-year anchor, exact critical
  value implementation, entry threshold, ATR stop, spread cap, risk split,
  atomic order sequence, or persistent attempt state.

## QM Interpretations

- `XAUUSD.DWX` and `XAGUSD.DWX` are spot-CFD carriers, not the source ETFs or
  matched futures. Their price levels, financing, contract sizes, calendars,
  and execution costs are separate empirical questions.
- The first broker D1 bar of each year is the walk-forward boundary. The
  nearest 252 synchronized observations strictly before it are formation;
  every later current-year observation is out of sample for that frozen fit.
- The log-gold-on-log-silver orientation, intercept, one residual-difference
  lag, `-3.343` boundary, OU half-life formula, `[2,30]` admission range,
  fresh `1.0` crossing, `0.5` convergence, beta-weighted risk split, and
  `3.5*ATR(20,D1)` stops are fixed pre-result QM translations.
- Opposing legs are an exposure construction, not a claim of dollar, beta,
  volatility, factor, market, or portfolio neutrality.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,398 registry rows and 534 root
cards. It found no exact identity and one expected fuzzy match,
`QM5_21525_wti-xcu-cadf`. Manual review fixes the boundaries:

- `QM5_20161_xauxag-ols-rv` slides a 120-D1 OLS fit every bar, does not run a
  CADF admission test or fit mean-reversion speed, enters any extreme, and
  uses a fixed sixty-day exit. This card freezes one pre-year 252-observation
  model, requires the locked 5% one-lag CADF and half-life gates, and enters
  only a fresh excursion.
- `QM5_12577_cme-xauxag-ratio` uses a fixed-beta raw log ratio; it has no
  fitted hedge, residual unit-root test, or fitted half-life.
- `QM5_13205_xau-xag-qc` uses monthly conditional-quantile envelopes rather
  than a frozen OLS/CADF residual.
- `QM5_1017_chan_pairs_stat_arb` supplies the approved method lineage but its
  concrete basket is AUDUSD/NZDUSD. This is the separately declared
  gold/silver carrier, with its own magics, contract sizes, spreads, and
  physical return driver.
- `QM5_21525_wti-xcu-cadf` fits a rolling WTI/copper model with a distinct
  energy/industrial-metal carrier and a different stationarity proxy. It does
  not carry the annual precious-metals equilibrium or Chan's 5% one-lag form.

Verdict:
`CLEAN_XAU_XAG_ANNUAL_CADF_HALFLIFE_RESIDUAL_REVERSION_AFTER_FAMILY_REVIEW`.

## Rules

These rules are the complete authorized baseline. No alternate carrier,
model window, anchor, critical value, threshold, sizing scheme, or fallback is
authorized.

## Markets, Clock, And Model Formula

- Logical basket: `QM5_21526_XAU_XAG_CADF_D1`.
- Host/traded slot 0: `XAUUSD.DWX`, D1, magic `215260000`.
- Companion/traded slot 1: `XAGUSD.DWX`, D1, magic `215260001`.
- Decision clock: first tick of each new host D1 bar after framework
  lifecycle clearance.
- Model anchor: the first host D1 bar of each broker calendar year.
- Formation: exactly 252 synchronized completed D1 observations strictly
  before that anchor. The first eligible signal observation is the first
  completed host D1 bar on or after the anchor.

For chronological training observations:

```text
y_i = log(XAU_i)
x_i = log(XAG_i)
y_i = alpha + beta*x_i + residual_i

delta_residual_i = c + rho*residual_(i-1)
                   + psi*delta_residual_(i-1) + error_i
ou_delta_i = theta*(residual_(i-1) - mean_residual) + noise_i

half_life = -log(2) / theta
z_t = (log(XAU_t) - alpha - beta*log(XAG_t) - mean_residual)
      / sample_std(residual)
```

Require finite nonsingular arithmetic, beta in `[0.10,3.00]`, lagged-level
`t_rho <= -3.343`, `theta < 0`, and half-life in `[2,30]`. Freeze alpha, beta,
residual mean, residual sample standard deviation, CADF statistic, and
half-life for the entire broker year. The model must reconstruct from the
same calendar anchor after a midyear restart; it may never slide intrayear.

## 4. Entry Rules

1. Require EA ID 21526, host `XAUUSD.DWX`, D1, slot 0, and active magics
   `215260000` and `215260001`.
2. Process orphan, malformed-package, and annual-rollover exits before every
   entry-only gate.
3. Reconstruct or retain the current year's frozen model exactly as defined
   above. Require exact timestamp matching, strict chronological order,
   positive finite closes, and a newest signal endpoint no more than ten
   calendar days stale.
4. Compute frozen-model z-scores for the latest two synchronized completed
   observations. Do not use either observation in the training sample.
5. A fresh cross above `+1.0` (`z_prev < +1.0` and `z_now >= +1.0`) opens
   SELL XAU / BUY XAG. A fresh cross below `-1.0` (`z_prev > -1.0` and
   `z_now <= -1.0`) opens BUY XAU / SELL XAG. Exact non-crossing or invalid
   state remains flat.
6. Persist the latest completed host D1 signal timestamp as consumed before
   history, news, spread, quote, ATR, sizing, or order gates. A broker reject,
   stop, restart, or partial failure may not retry the same signal bar.
7. Require no owned exposure or same-signal entry deal, both entry spreads in
   `[0,1500]` points, executable quotes, completed `ATR(20,D1)` for each leg,
   valid contract metadata, and the fixed-risk contract.
8. Split one aggregate `RISK_FIXED=1000` budget by normalized relative
   weights `1.0` for XAU and `abs(beta)` for XAG. ATR-size each risk share
   independently and attach a frozen `3.5*ATR(20,D1)` broker hard stop. There
   is no take-profit.
9. Open XAU first and XAG second. Retain the package only if exactly one
   correctly directed position with a valid stop exists in each slot. On any
   order or final validation failure, flatten every owned leg immediately.

## 5. Exit Rules

1. Close both legs when the frozen-model residual reaches
   `abs(z_now) <= 0.5`.
2. Close both legs after `ceil(frozen_half_life)` elapsed calendar days.
3. Close both legs before replacing the frozen model at a broker-calendar-
   year transition.
4. Close both legs when signal timestamps desynchronize, the endpoint becomes
   stale, a frozen parameter becomes invalid, or the package composition is
   wrong.
5. Immediately flatten an orphan, duplicate, same-side, wrong-symbol,
   wrong-magic, or missing-stop composition.
6. Broker hard stops and the framework kill switch remain authoritative.
7. Friday close is disabled for the fitted multi-session hold. There is no
   target, trailing stop, break-even, partial close, scale-in, grid,
   martingale, pyramid, or discretionary exit.

## 6. Filters (No-Trade Module)

- Fail closed outside exact host, timeframe, EA ID, slots, active magic rows,
  risk mode, news mode, Friday mode, or locked strategy inputs.
- Reject a consumed signal, owned exposure, same-signal deal, missing anchor,
  wrong training count, timestamp mismatch, nonchronological or stale data,
  nonpositive close, singular OLS/CADF arithmetic, beta or half-life outside
  bounds, nonpassing CADF statistic, non-fresh crossing, excessive spread,
  invalid quote, missing ATR, invalid stop, or invalid contract metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  and package repair run before entry-only gates.
- Runtime may not read an external file or API, futures chain, analyst input,
  optimizer result, trained output, or portfolio state.

## 7. Trade Management Rules

- Maintain at most one two-leg package and one consumed attempt per completed
  host signal timestamp.
- Preserve each original broker hard stop; never modify a stop or position
  size after entry.
- Recompute current z with frozen annual parameters only; do not refit until
  the next broker-year anchor.
- Restart recovery combines a terminal-persistent consumed-signal marker with
  owned position and deal history. Tester initialization clears a future
  marker so historical runs remain deterministic.
- Process annual rollover, convergence, fitted time stop, invalid data/model,
  and malformed-package repair before any new entry.
- No randomness, adaptive PnL fitting, external state, partial close,
  scale-in, grid, martingale, or pyramiding is allowed.

## Framework Execution Overrides

- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode: OFF.
- Friday close: disabled for the fitted multi-session hold.
- Stress rejection: zero for the Q02 baseline.
- Framework kill switch and server-side broker hard stops: authoritative.
- Forced session flatten: none; annual rollover, fitted time stop, convergence,
  invalid state, and malformed-package repair are strategy-owned exits.

## Exit Precedence

1. Framework kill switch and each server-side hard stop.
2. Malformed, orphaned, duplicated, wrong-side, wrong-symbol/magic, or
   missing-stop package repair.
3. Broker-calendar-year rollover before any replacement model or new entry.
4. Invalid frozen model or synchronized signal state.
5. `ceil(frozen_half_life)` calendar-day time stop.
6. Frozen-model convergence at `abs(z) <= 0.5`.
7. No Friday, news, target, trailing, break-even, partial, or discretionary
   exit is added.

## Runtime Data Dependencies

- Exact chart route: `XAUUSD.DWX`, D1; synchronized companion route:
  `XAGUSD.DWX`, D1.
- Native tester data: D1 timestamps and closes, completed `ATR(20,D1)`,
  executable bid/ask, spread, contract and volume metadata, broker calendar,
  positions, deals, and terminal-persistent global variables.
- The terminal marker and exact entry-deal tag provide restart-safe
  no-retry state. Historical tester initialization removes only a marker that
  lies in the future of the restarted test clock.
- No external file, API, event calendar, futures chain, trained artifact,
  analyst input, optimizer output, or portfolio state is read at runtime.
- Tester account currency and fixed-risk lot sizing remain framework-owned.

## Parameters To Test

Q02 uses only the locked defaults. The table records the contract and does not
authorize a rescue sweep after failure.

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_training_bars` | 252 | [252] | exact pre-year synchronized training observations |
| `strategy_cadf_critical` | -3.343 | [-3.343] | governed 5% two-variable one-lag boundary |
| `strategy_entry_z` | 1.0 | [1.0] | fresh residual crossing boundary |
| `strategy_exit_z` | 0.5 | [0.5] | convergence boundary |
| `strategy_beta_min` | 0.10 | [0.10] | positive hedge-ratio floor |
| `strategy_beta_max` | 3.00 | [3.00] | positive hedge-ratio ceiling |
| `strategy_half_life_min` | 2.0 | [2.0] | fitted D1 lower bound |
| `strategy_half_life_max` | 30.0 | [30.0] | fitted D1 upper bound and deployment cap |
| `strategy_history_bars_d1` | 900 | [900] | bounded reconstruction buffer per symbol |
| `strategy_max_endpoint_gap_days` | 10 | [10] | completed-signal freshness guard |
| `strategy_atr_period_d1` | 20 | [20] | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard-stop multiple |
| `strategy_xau_max_spread_points` | 1500 | [1500] | gold entry spread ceiling |
| `strategy_xag_max_spread_points` | 1500 | [1500] | silver entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | paired order deviation |

All values, timestamp matching, annual anchor, sample inclusion, estimator
degrees of freedom, critical comparison, direction, risk split, hard stops,
and no-retry policy are locked.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for one aggregate package. Gold and silver split the
budget by frozen beta and unit weights before independent stop sizing.

Risk is high: current CFDs may not be cointegrated; a one-year in-sample test
can be unstable; annual freezing can retain a broken model; spot CFDs differ
from source ETFs and futures; gold and silver contract sizes, gaps, spreads,
financing, lot granularity, stop slippage, and legging can break neutrality;
and the stream may remain correlated with the certified XAU sleeve.

Retire on zero trades, fewer than five completed packages per full post-
warm-up year, persistent CADF/half-life failure, wrong annual reconstruction,
wrong direction, aggregate-risk breach, nondeterminism, nonpositive governed
economics, or later portfolio-correlation rejection. Do not slide the model,
loosen the critical value, remove the half-life gate, lower the crossing, or
retry a consumed excursion to rescue results.

## Reputable-Source Criteria And Allowability

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS | CEO-ratified complete Wiley extraction, OWNER-approved peer-reviewed gold/silver packet, and governed CME carrier evidence. |
| R2 | PASS | Anchor, samples, estimators, statistical gates, entries, exits, stops, sizing, attempt state, and repair are fixed. |
| R3 | PASS | Registered XAUUSD.DWX and XAGUSD.DWX D1 histories supply every runtime field; Q02 must prove synchronized support and fills. |
| R4 | PASS | Deterministic native arithmetic only, without trained output, banned signal indicator, external runtime feed, grid, or martingale. |

## Framework Alignment

- no_trade: exact host/timeframe/ID/slots, locked inputs, risk/news/Friday
  contract, annual reconstruction, synchronized completed history, OLS/CADF/
  half-life gates, consumed signal, spreads, quotes, ATR, stops, and package
  guards.
- trade_entry: frozen-model fresh residual crossing, persistent attempt,
  opposite paired orders, beta-weighted shared risk, frozen hard stops, and
  second-leg rollback.
- trade_management: annual rollover, malformed-package repair, frozen-model
  validity, convergence, and fitted time-stop processing before entry gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Falsification And Requalification

Retire at Q02 on zero trades, fewer than five completed packages per full
post-warm-up year, or nonpositive governed economics. Invalid anchor
reconstruction, any formation/signal overlap, timestamp mismatch, wrong CADF
degrees of freedom or comparison, intrayear refit, wrong direction,
same-signal retry, malformed package retention, aggregate-risk breach, or
nondeterminism is an implementation failure rather than a tunable result.

Any change to the carrier, orientation, annual anchor, synchronized sample,
training count, OLS/CADF/OU formula, critical value, beta or half-life gate,
entry/exit threshold, stop, spread cap, risk split, attempt lifecycle, symbol,
timeframe, news/Friday mode, or risk mode requires a new binary and full
pipeline requalification. Realized diversification may only be assessed at
the unchanged portfolio-correlation gate; a correlation failure receives no
waiver here.

## Safety Boundary

This card authorizes only deterministic allocation, one branch build, strict
compile/Q01, one logical D1 `RISK_FIXED` backtest setfile, and one paced
non-live Q02 enqueue if CPU capacity permits. It does not authorize a manual
backtest; live, demo, shadow, stress, or optimization setfile; AutoTrading;
`T_Live`; deploy or T_Live manifest; portfolio-gate mutation; portfolio
admission; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-15 | initial annual XAU/XAG CADF residual card | G0 | APPROVED; build pending |
| v2 | 2026-08-15 | implement annual reconstruction, CADF/OU gates, and atomic basket lifecycle | Q01 | PASS; Q02 not enqueued |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-15 | APPROVED; R1-R4 PASS | `decisions/2026-08-15_qm5_21526_xau_xag_cadf_g0.md`; approved composite packet |
| Q01 Build Validation | 2026-08-15 | PASS | strict compile 0/0; build check 0/0; fourteen reference tests; P1 artifact PASS |
| Q02 Baseline Screening | - | NOT ENQUEUED | paced logical-basket enqueue pending capacity check |
