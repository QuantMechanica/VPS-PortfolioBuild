---
card_schema_version: 2
type: strategy
strategy_id: VILLAR-RAMBERG-OILGAS-2026_S01
variant_id: VILLAR-RAMBERG-OILGAS-2026_S01
source_id: VILLAR-RAMBERG-OILGAS-2026
ea_id: QM5_20237
slug: xtixng-ecm-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20237_xtixng-ecm-rv_card.md
execution_contract_status: DRAFT
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
g0_status: APPROVED
source_authors: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons"
source_citation: "Villar and Joutz (2006), U.S. EIA Office of Oil and Gas; Ramberg and Parsons (2012), The Energy Journal 33(2), 13-35, DOI 10.5547/01956574.33.2.2."
source_citations:
  - type: government_research_report
    citation: "Villar, J. A., and Joutz, F. L. (2006). The Relationship Between Crude Oil and Natural Gas Prices. U.S. Energy Information Administration, Office of Oil and Gas."
    location: "Complete 43-page report; especially pp. 5-10 and 27-41; https://www.eia.gov/naturalgas/archive/reloilgaspri.pdf; governed packet strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: primary_method_and_market
  - type: peer_reviewed_paper
    citation: "Ramberg, D. J., and Parsons, J. E. (2012). The Weak Tie Between Natural Gas and Oil Prices. The Energy Journal 33(2), 13-35."
    location: "Complete MIT author copy; especially journal pp. 21-35; DOI https://doi.org/10.5547/01956574.33.2.2; governed packet strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: primary_regime_and_caveat
  - type: government_market_analysis
    citation: "U.S. Energy Information Administration (2020). Natural gas markets remain regionalized compared with oil markets."
    location: "Complete article; https://www.eia.gov/todayinenergy/detail.php?id=43535"
    quality_tier: A
    role: adverse_modern_context
strategy_mechanic: rolling-trend-augmented-ols-xng-on-xti-log-price-error-correction-residual-crossing-reversion-two-leg-basket
sources:
  - "[[sources/VILLAR-RAMBERG-OILGAS-2026]]"
concepts:
  - "[[concepts/oil-gas-error-correction]]"
  - "[[concepts/time-varying-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/ordinary-least-squares]]"
  - "[[indicators/residual-zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, crude-oil, natural-gas, error-correction, rolling-regression, relative-value, market-neutral-basket, mean-reversion, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20237_XTI_XNG_ECM_D1
symbol: QM5_20237_XTI_XNG_ECM_D1
symbol_slot: 0
magic: 202370000
period: D1
timeframe: D1
expected_trade_frequency: "Estimated 5-12 completed XTI/XNG residual packages/year after 252 synchronized completed D1 bars; Q02 must prove or retire density."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
review_focus: "Falsify a rolling oil-conditioned natural-gas error-correction basket. The state is a trend-augmented XNG-on-XTI log-price residual crossing, not a fixed oil/gas ratio, return shock, breakout, calendar effect, momentum rank, volatility rank, or the incumbent XNG RSI pullback. Only Q09 may establish realized book decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [basket_atomicity, synchronized_completed_history, regression_singularity, aggregate_fixed_risk, frozen_beta_weights, no_excursion_retry, magic_schema, cfd_source_basis, weekend_gap, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-06_qm5_20237_xtixng_ecm_rv_g0.md: R1 complete U.S. EIA report, complete peer-reviewed Energy Journal article, and explicit adverse modern EIA context; R2 locked 252-D1 synchronized trend-augmented OLS, residual crossing, gas-fade direction, frozen beta risk weights, hard stops, convergence/stale exits, and orphan repair; R3 registered XTI/XNG D1 histories; R4 closed-form native arithmetic only. Deterministic dedup scanned 4,294 registry rows and 410 cards with CLEAN exact/fuzzy result; manual mechanic review is clean. Source instability and unexplained gas volatility are binding kill risks, and no efficacy transfers."
---

# QM5_20237 XTI/XNG Rolling Error-Correction Residual Reversion

## Hypothesis

Crude oil and natural gas share substitution, production, investment, and
contract-pricing channels, but their relationship changes with gas transport,
weather, storage, technology, and regional supply. A rolling regression can
represent a deliberately weak, time-varying tie. When the newest XNG log price
crosses unusually far from that oil-conditioned relationship, a paired fade
tests whether the gas residual partially corrects without taking the common
direction of a standalone energy trade.

The construction does not assert that the CFDs are cointegrated or that the
package is neutral. Opposite directions and beta-weighted stop-risk shares do
not prove dollar, beta, volatility, factor, or portfolio neutrality. Q02 must
establish density and economics; unchanged Q09 alone may measure realized
overlap with the certified XAU/SP500/NDX/XNG book.

## Source Traceability And Evidence Boundary

The governed source packet is
`strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`. Villar and
Joutz's complete 43-page EIA study finds a logged WTI/Henry-Hub long-run
relation with WTI weakly exogenous and gas carrying the statistically
significant adjustment. Ramberg and Parsons' complete peer-reviewed article
reconfirms a weak tie while showing that the relationship changes across
regimes and leaves most short-run gas volatility unexplained. EIA's 2020 note
reports little then-current daily correlation between crude and gas
benchmarks, which is adverse evidence rather than omitted context.

The sources use monthly or weekly spot observations, multivariate models, and
weather, storage, shutdown, or seasonal controls. This card uses synchronized
Darwinex continuous-CFD D1 closes and a closed-form rolling proxy. It does not
import the papers' beta, trend, half-life, significance, fit, return, drawdown,
trade count, transaction cost, or correlation statistics. The source samples
end in 2005 and 2010; all QM history is a later-regime falsification.

## Non-Duplicate Decision

The canonical checker scanned 4,294 EA-registry rows and 410 cards and returned
`CLEAN`, with no exact duplicate and no fuzzy match above threshold. Manual
review resolves the closest strategies:

- `QM5_12578_eia-oilgas-ratio` standardizes a fixed XTI/XNG log ratio. This
  card estimates an intercept, positive oil beta, and deterministic drift on a
  rolling synchronized window.
- `QM5_12608_eia-oilgas-breakout` follows a ratio channel; this card fades a
  regression residual only after a boundary crossing.
- `QM5_12840_xti-xng-rspread` standardizes a fixed-window return difference,
  not a log-price-level error-correction object.
- `QM5_20016_xti-xng-mon-rv` and `QM5_20110_xti-xng-fri-rv` use weekday
  relative returns rather than a structural rolling tie.
- Energy calendar, momentum, tail, higher-moment, volatility, leverage, and
  factor-rank baskets use different states and clocks.
- `QM5_20161_xauxag-ols-rv` uses a precious-metal carrier and a one-regressor
  OLS without the source-required time-varying oil/gas framing or trend term.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only oscillator
  pullback.

The XNG-on-XTI orientation, intercept plus time regressor, 252 synchronized
completed observations, bounded positive beta, residual boundary crossing,
gas-residual fade, frozen beta weights, convergence exit, and no repeated
entry within one extreme are jointly load-bearing. Verdict:
`CLEAN_AFTER_DETERMINISTIC_AND_MANUAL_REVIEW`.

## Concept And Formula

On a new `XTIUSD.DWX` D1 bar, load exactly 252 completed, timestamp-matched
closes from both legs. Index the observations chronologically with centered
time `u_i` and solve the two-regressor OLS in closed form:

```text
y_i = log(XNG_i)
x_i = log(XTI_i)
y_i = alpha + beta * x_i + gamma * u_i + residual_i
```

Using centered sums:

```text
det   = Sxx * Suu - Sxu^2
beta  = (Sxy * Suu - Suy * Sxu) / det
gamma = (Suy * Sxx - Sxy * Sxu) / det
alpha = mean(y) - beta * mean(x) - gamma * mean(u)
```

Reject a singular or ill-conditioned determinant (`det <= 1e-10 * Sxx * Suu`), non-finite values, beta
outside `[0.10,2.00]`, or `abs(gamma)>0.01` log units per D1 observation.
Standardize residuals with regression degrees of freedom:

```text
sigma = sqrt(sum(residual_i^2) / (252 - 3))
z_now = residual_newest / sigma
z_prev = residual_previous / sigma
```

- `z_now > +2.0` after `z_prev <= +2.0`: BUY XTI and SELL XNG.
- `z_now < -2.0` after `z_prev >= -2.0`: SELL XTI and BUY XNG.
- An already-extreme residual, tie, invalid model, missing data, or stale
  endpoint remains flat. Crossing is data-derived and restart-safe.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_20237_XTI_XNG_ECM_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1, magic `202370000`.
- Traded slot 1: `XNGUSD.DWX`, D1, magic `202370001`.
- Formation: exactly 252 synchronized completed D1 closes; current bars are
  excluded and the newest endpoints must be no more than ten calendar days
  old.
- Decision: first tick of each new XTI D1 bar after framework clearance.
- Expected cadence: 5-12 completed packages/year; retire below five per full
  post-warm-up year.
- Runtime data: native MT5 D1 time/close, ATR, spreads, positions, deals,
  broker time, and contract metadata only.

## Rules

### Entry

1. Require exact host `XTIUSD.DWX`, D1, EA ID 20237, and magic slot 0.
2. Require no owned XTI or XNG position, both symbols selected, active magic
   rows, valid quotes/contract metadata, and entry spreads inside both caps.
3. Load 252 completed closes and timestamps per leg. Require every timestamp to
   match, every price to be positive and finite, and the latest endpoint to be
   fresh.
4. Calculate the locked trend-augmented OLS and residual standardization. Fail
   closed on singularity, ill-conditioning, invalid beta/trend/sigma, or a
   non-crossing residual.
5. On a positive crossing, buy XTI and sell XNG; on a negative crossing, sell
   XTI and buy XNG.
6. Freeze entry beta. Give XTI relative risk weight `abs(beta)` and XNG weight
   `1.0`; normalize those weights across one aggregate package budget.
7. ATR-size each risk share independently and attach a frozen
   `3.5 * ATR(20,D1)` hard stop to each leg.
8. Open XTI then XNG. Retain the package only if exactly one correctly directed
   position exists in each slot. If either order or validation fails, flatten
   every owned leg immediately.

### Management And Exit

1. On each new host D1 state, close both legs when `abs(z_now) <= 0.50`.
2. Close both legs if regression state becomes invalid, beta leaves its bound,
   timestamps desynchronize, or the endpoint becomes stale.
3. Close both legs after 60 calendar days.
4. Immediately flatten an orphan, duplicate, same-side, wrong-symbol,
   wrong-magic, or missing-stop composition.
5. Broker hard stops and the framework kill switch remain authoritative.
6. Friday close is disabled to preserve the multiweek error-correction hold;
   weekend gap risk remains explicit.
7. No take profit, trailing stop, break-even, partial close, scale-in, grid,
   martingale, pyramiding, external feed, adaptive PnL fit, or discretionary
   rule is authorized.

### No-Trade And News

- Host, timeframe, slot, source-locked parameter, synchronization, freshness,
  arithmetic, beta, trend, residual variance, crossing, spread, ATR, volume,
  magic, and package checks fail closed.
- News compliance gates new entries for both traded symbols. Lifecycle exits
  and orphan repair remain active. The Q02 setfile disables both news axes.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_ols_lookback_d1` | 252 | [252] | synchronized completed observations |
| `strategy_entry_z` | 2.0 | [2.0] | residual crossing boundary |
| `strategy_exit_z` | 0.5 | [0.5] | convergence boundary |
| `strategy_beta_min` | 0.10 | [0.10] | positive oil-beta floor |
| `strategy_beta_max` | 2.00 | [2.00] | positive oil-beta ceiling |
| `strategy_trend_abs_max` | 0.01 | [0.01] | daily log-drift fail-closed cap |
| `strategy_history_bars` | 300 | [280, 300, 360] | bounded retrieval buffer only |
| `strategy_max_endpoint_gap_days` | 10 | [7, 10] | completed-endpoint freshness |
| `strategy_atr_period_d1` | 20 | [14, 20, 30] | per-leg stop volatility |
| `strategy_atr_sl_mult` | 3.5 | [2.5, 3.5, 5.0] | frozen per-leg stop distance |
| `strategy_max_hold_days` | 60 | [60] | stale package guard |
| `strategy_xti_max_spread_pts` | 1000 | [750, 1000, 1500] | WTI entry spread cap |
| `strategy_xng_max_spread_pts` | 3000 | [2000, 3000, 4500] | gas entry spread cap |
| `strategy_deviation_points` | 20 | [10, 20, 50] | paired order deviation |

Only retrieval/freshness, ATR safety, spread, and order-deviation values may
use their predeclared alternatives. The OLS window, model orientation,
regressors, determinant guard, beta range, residual degrees of freedom,
crossing thresholds, trade direction, beta weights, carrier, and lifecycle are
locked before Q02.

## Risk

- Q02-Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` for one aggregate package. XTI and XNG split that budget
  by frozen beta and unit weights before independent stop sizing.
- Risk class is high: the relationship is historically unstable; modern
  correlation evidence is adverse; XNG has large idiosyncratic jumps; D1 CFD
  levels are not source spot series; a trend regressor can absorb drift without
  proving stationarity; and gaps, financing, lot granularity, and legging can
  break neutrality.
- Retire below five completed packages per full post-warm-up year, on zero
  trades, wrong regression orientation/direction, nondeterminism, stale or
  unsynchronized history, persistent orphan exposure, aggregate-risk breach,
  nonpositive governed economics, or later portfolio-correlation rejection.
- Do not remove the trend, switch to a fixed ratio or return spread, reverse
  the gas fade, loosen the beta/model guard, add an outright filter, or retry an
  already-extreme residual to rescue results.

## Strategy Allowability Check

- [x] Structural energy relative-value thesis with D1 low-frequency cadence.
- [x] Complete government report, complete peer-reviewed paper with DOI and
      author copy, reproducible retrieval hashes, and modern adverse context.
- [x] Deterministic closed-form native arithmetic; no banned indicator,
      external runtime dependency, grid, martingale, pyramiding, or adaptive
      fitting to realized PnL.
- [x] Registered XTIUSD.DWX and XNGUSD.DWX D1 inputs.
- [x] Expected density targets the binding five-package/year floor.
- [x] One fixed-risk basket setfile; no live artifact is authorized.
- [x] Exact/fuzzy dedup clean and nearest mechanics manually resolved.

## Framework Alignment

- no_trade: exact host/timeframe/slot, locked core parameters, synchronized
  completed history, endpoint freshness, finite regression, beta/trend/sigma,
  crossing, spreads, ATR, volume, magic, and package guards.
- trade_entry: trend-augmented residual crossing, source-consistent gas fade,
  paired opposite orders, beta-weighted shared risk, frozen hard stops, and
  second-leg rollback.
- trade_management: composition validation, endpoint/model validation,
  convergence close, 60-day stale close, and orphan repair.
- trade_close: framework close helper plus broker-side hard stops and kill
  switch.

No live setfile, T_Live action, AutoTrading change, deploy manifest, portfolio
gate edit, portfolio admission, or correlation waiver is authorized.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-06 | initial approved XTI/XNG rolling error-correction basket | G0 | APPROVED |
| v1.1 | 2026-08-06 | trend-augmented ECM implementation, strict compile, and build validation | Q01 | PASS |
| v1.2 | 2026-08-06 | one paced logical-basket baseline item enqueued below the terminal ceiling | Q02 | ENQUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | APPROVED | `decisions/2026-08-06_qm5_20237_xtixng_ecm_rv_g0.md` |
| Q01 Build Validation | 2026-08-06 | PASS | `framework/build/compile/20260806_025118/QM5_20237_xtixng-ecm-rv.compile.log`; `D:/QM/reports/framework/21/build_check_20260806_025118.json` (0 errors, 0 warnings, 0 gate failures) |
| Q02 Baseline Screening | 2026-08-06 | ENQUEUED | work item `2e79b80d-2942-491a-a440-4ab92a7c642f`; `docs/ops/evidence/2026-08-06_qm5_20237_xtixng_ecm_rv_build_q02_enqueue.md` |
