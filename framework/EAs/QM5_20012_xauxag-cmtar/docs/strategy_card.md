---
ea_id: QM5_20012
slug: xauxag-cmtar
type: strategy
strategy_id: MIGHRI-XAUXAG-CMTAR-2018_S01
source_id: MIGHRI-XAUXAG-CMTAR-2018
status: APPROVED
created: 2026-07-20
created_by: Research
last_updated: 2026-07-20
g0_status: APPROVED
g0_approval_reasoning: "OWNER commodity-sleeve mission: R1 tier-B full-text peer-reviewed source; R2 fixed C-MTAR residual/gate and deterministic hedge/risk; R3 synchronized XAU/XAG D1 route; R4 no ML/banned indicators; exact-mechanic audit CLEAN."
source_citation: "Mighri, Z. A. and Al Saggaf, M. I. (2018). Gold - Silver Nexus: A Threshold Cointegration Approach. International Journal of Economics and Financial Issues 8(5), 210-219."
source_citations:
  - type: paper
    citation: "Mighri, Zouheir Ahmed and Al Saggaf, Majid Ibrahim (2018). Gold - Silver Nexus: A Threshold Cointegration Approach. International Journal of Economics and Financial Issues 8(5), 210-219."
    location: "Sections 2.2 and 3.1-3.5; Tables 1, 2, 4, and 5; official article https://www.econjournals.com/index.php/ijefi/article/view/6838; full text https://www.econjournals.com/index.php/ijefi/article/download/6838/pdf/17184"
    quality_tier: B
    role: primary
sources:
  - "[[sources/MIGHRI-XAUXAG-CMTAR-2018]]"
concepts:
  - "[[concepts/asymmetric-threshold-cointegration]]"
  - "[[concepts/precious-metals-relative-value]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [atr-hard-stop, time-stop, symmetric-long-short]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
markets: [commodities, precious_metals]
single_symbol_only: false
logical_symbol: QM5_20012_XAU_XAG_CMTAR_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "One source-gated XAU/XAG package at eligible monthly boundaries; estimate 6-10 completed packages/year after the C-MTAR regime, residual buffer, synchronized-history, and spread gates."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.05
expected_dd_pct: 16.0
risk_class: medium-high
ml_required: false
r1_track_record: TIER_B
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
review_focus: "Verify base-10 residual orientation, load-bearing delta-residual threshold, fixed 0.71970 notional hedge, monthly renewal, and no collision with symmetric gold/silver ratio or spread builds."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, magic_schema, one_position_per_magic_symbol]
---

# Gold-Silver Consistent M-TAR Convergence Basket

## Hypothesis

Mighri and Al Saggaf report that monthly gold and silver log prices share an
asymmetric threshold-cointegrating relation. Their preferred consistent M-TAR
model finds significant convergence only when the month-over-month change in
the equilibrium residual is below `0.021`; the other momentum regime is not
statistically convergent. A fixed XAU/XAG relative-value basket can therefore
test the convergent regime without importing ordinary symmetric ratio
reversion into the portfolio.

The paper does not report a trading backtest. This card is a falsifiable
Darwinex carrier: it preserves the published fixed residual, monthly cadence,
momentum threshold, and elasticity hedge, then adds only explicit execution
and risk controls. The result is cointegration-beta hedged, not strictly
dollar neutral. Portfolio decorrelation is an objective, not a claim; it must
be measured after survival and this card does not alter the portfolio gate.

## Source Citation And Interpretation

The sole source is the 2018 *International Journal of Economics and Financial
Issues* article cited above. Section 3.1 and 581 observations establish monthly
data from January 1968 through May 2016. Table 4 reports the `Silver-gold`
relation with intercept `-0.99823` and slope `0.71970`. Table 2 reports the
preferred consistent M-TAR threshold `0.021`, with `rho2=-0.043`
(`t=-3.716`) below that momentum threshold and a non-significant `rho1=+0.023`
above it.

The paper contains frequency, log-base, and equation-orientation typos. The
implementation locks the interpretation that reproduces its data tables:

`e = log10(XAG month-end) + 0.99823 - 0.71970 * log10(XAU month-end)`

The abstract's weekly label is rejected in favor of Section 3.1's monthly
description and observation count. Base-10 logs are required by the reported
sample means. Silver is the dependent leg because substituting those means
satisfies the `Silver-gold` row; the reversed footnote does not. These are
predeclared source reconciliations, not parameters.

## Concept And Non-Duplicate Boundary

The load-bearing signal is `delta(e) < 0.021` on two synchronized completed
monthly endpoints. Only then may the signed residual be faded toward zero:

- `e > +entry_buffer`: silver is rich; SELL XAG and BUY XAU.
- `e < -entry_buffer`: silver is cheap; BUY XAG and SELL XAU.
- otherwise: remain flat.

This is not a rolling ratio z-score (`QM5_12577`), ratio breakout
(`QM5_12724`), return-spread z-score (`QM5_12862`), rolling OLS/half-life
spread (`QM5_11241`), stochastic ratio (`QM5_1256`), or conditional-quantile
envelope (`QM5_13205`). The fixed published residual, monthly change, and
one-sided convergence-regime gate are jointly required. The source gate cannot
be removed or inverted in later tuning.

## Target Symbols And Timeframe

- Logical basket: `QM5_20012_XAU_XAG_CMTAR_D1`.
- Host and slot 0: `XAUUSD.DWX`, D1.
- Foreign leg and slot 1: `XAGUSD.DWX`, D1.
- Signal endpoints: synchronized completed broker-calendar month-end D1
  closes; no MN1-series dependency.
- Expected frequency: approximately 6-10 completed packages/year, capped at
  one attempt per broker month. Q02 must prove or kill the cadence.
- Q02 synchronized multi-symbol window: `2018.07.02` through `2024.12.31`;
  do not extend beyond the validated XAG endpoint or fall back to 2022.
- Backtest risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Rules

### Entry

- Evaluate entries only on the first tradable `XAUUSD.DWX` D1 bar of a new
  broker month.
- Reconstruct the latest two consecutive, synchronized XAU and XAG month-end
  closes from completed D1 bars. Require the exact same D1 endpoint timestamp
  on both legs; reject stale, skipped-month, or mismatched endpoints.
- Calculate `e0` at the just-completed month end and `e1` at the preceding
  month end using the fixed formula above; calculate `delta_e=e0-e1`.
- Require `delta_e < strategy_mtar_delta_threshold`, locked at `0.021`.
- Require `abs(e0) >= strategy_entry_abs_residual`, default `0.010` base-10
  log units. This cost-aware buffer is a declared QM adaptation.
- For positive `e0`, BUY XAU and SELL XAG. For negative `e0`, SELL XAU and
  BUY XAG.
- Target XAU:XAG dollar notionals of exactly `0.71970:1` before lot rounding.
  Compute both lots jointly so total ATR-stop risk does not exceed the one
  framework risk budget; reject post-rounding or actual-filled hedge error
  above the cap.
- Record the monthly attempt before order submission. If either leg fails,
  close the other leg immediately and do not retry that month.

### Exit

- At the next broker-month boundary, close both legs before evaluating a new
  package. If the new signal remains eligible, it may open one freshly sized
  package for the new monthly observation.
- Close both legs immediately if package composition, direction, or actual
  filled-volume hedge is invalid, or if one leg is missing.
- Per-leg broker-side hard stop: frozen D1 ATR(`strategy_atr_period_d1`) times
  `strategy_atr_sl_mult` from entry.
- Close any residual package after `strategy_max_hold_days=40` calendar days.
- Friday close is disabled because the monthly source observation necessarily
  spans weekends; this is a documented research-only exception.

### Filters

- Exact host, timeframe, and slot guard: `XAUUSD.DWX`, D1, slot 0.
- Both symbols must be selected, synchronized, tradable, inside their spread
  caps, and have valid ATR/contract/tick/volume metadata before either order.
- Fixed source constants must equal `-0.99823`, `0.71970`, and `0.021`.
- One position per registered magic/symbol and exactly two opposite-direction
  positions per valid package.
- Kill switch and news compliance cover both magic slots and both symbols.
- No external data, rolling regression, z-score, ratio band, ML, adaptive PnL
  fitting, grid, martingale, pyramiding, partial close, trailing stop, or
  discretionary switch.

## Trade Management Rules

- Orphan and malformed-package repair runs before all entry filters.
- Restart state is recovered from owned positions and the persisted monthly
  attempt marker; a mid-month attach never creates late exposure.
- No intramonth signal recalculation or same-month re-entry.
- Both legs use a common order reason and deterministic slot mapping.
- The monthly close/reopen boundary intentionally converts a potentially
  multi-month convergence episode into non-overlapping source-period packages
  so costs and risk are measured once per monthly observation.

## Parameters To Test

- name: strategy_entry_abs_residual
  default: 0.010
  sweep_range: [0.000, 0.010, 0.020]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 4.0
  sweep_range: [3.0, 4.0, 5.0]
- name: strategy_max_hold_days
  default: 40
  sweep_range: [35, 40]
- name: strategy_xau_max_spread_pts
  default: 1500
  sweep_range: [1000, 1500, 2500]
- name: strategy_xag_max_spread_pts
  default: 500
  sweep_range: [300, 500, 800]
- name: strategy_max_hedge_error_pct
  default: 20.0
  sweep_range: [10.0, 20.0, 30.0]

The intercept, elasticity, M-TAR threshold, monthly cadence, convergence-gate
direction, residual fade directions, and two-leg construction are locked.

## Author Claims

The source reports “substantially faster convergence for negative (below
threshold) deviations” and rejects both no threshold cointegration and
symmetric adjustment in its preferred C-MTAR model. It reports no transaction-
cost-aware trading performance, Darwinex CFD test, or portfolio correlation.
The signed residual fade and monthly close/reopen carrier are disclosed QM
trading translations, not source-authored rules. No source performance
statistic is used as a gate or forecast.

## Risk

- `expected_pf: 1.05` and `expected_dd_pct: 16.0` are conservative queue-order
  priors, not evidence.
- Risk class: medium-high because the fixed 1968-2016 LBMA relation may drift,
  XAG can gap, CFD financing differs from futures/spot research, and two orders
  can fill asynchronously.
- Total package stop risk is capped by one `RISK_FIXED=1000` budget and checked
  after lot rounding. Opposite legs and the published elasticity create a
  cointegration-beta hedge, not strict dollar neutrality or guaranteed market
  neutrality.
- Kill criteria include fewer than five completed packages/year, persistent
  hedge-error rejection, symbol-history failure, transaction-cost collapse,
  unstable fixed-relation behavior, or correlation that fails the later
  portfolio-diversification requirement.
- The tester counts two legs per package. Its automatic 35-trade Q02 floor is
  not density proof: this card requires at least 35 completed paired packages
  (approximately 70 leg trades) across the seven Q02 year labels.

## Strategy Allowability Check

- [x] R1 reputable source: tier-B peer-reviewed, named-author journal article
  with official page and complete open text; inconsistencies disclosed.
- [x] R2 mechanical: fixed equation, source threshold, monthly endpoints,
  directions, joint sizing, ATR stops, renewal, and stale exit.
- [x] R3 testable: XAUUSD.DWX and XAGUSD.DWX are registered and used by prior
  logical-basket builds; Q02 validates synchronized history and economics.
- [x] R4 compliant: deterministic arithmetic and framework controls only; no
  ML, banned indicator, external runtime feed, grid, or martingale.
- [x] Non-duplicate: no existing build uses a fixed C-MTAR residual and its
  asymmetric residual-momentum regime.

## Framework Alignment

- no_trade: host/timeframe/slot, fixed-constant, synchronization, spread,
  metadata, monthly-attempt, news, and kill-switch guards.
- trade_entry: source-gated signed residual fade with joint fixed-risk,
  elasticity-notional sizing and atomic package repair.
- trade_management: orphan/composition/actual-hedge repair and retrying
  month-boundary renewal.
- trade_close: per-leg ATR stops and forty-day stale guard.

`friday_close`, `risk_mode_dual`, `magic_schema`, and
`one_position_per_magic_symbol` require explicit Q01/Q02 verification. No
T_Live preset, deploy manifest, AutoTrading action, or portfolio-gate change is
authorized by this card.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-20 | initial asymmetric C-MTAR basket extraction | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-20 | APPROVED | this card and source packet |
| Q01 Build Validation | TBD | TBD | TBD |
| Q02 Baseline Screening | TBD | TBD | TBD |

## Lessons Captured

- 2026-07-20: Table values, not contradictory prose labels, must lock the
  source's sampling frequency, logarithm base, and equation orientation.
