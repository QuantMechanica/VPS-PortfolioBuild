---
card_schema_version: 2
type: strategy
strategy_id: YAYA-CME-XAUXAG-FRACD-RV-2026_S01
variant_id: YAYA-CME-XAUXAG-FRACD-RV-2026_S01
source_id: YAYA-CME-XAUXAG-FRACD-RV-2026
ea_id: QM5_41185
slug: xauxag-fracd-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41185_xauxag-fracd-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-27
created_by: Research+Development
last_updated: 2026-08-27
g0_status: APPROVED
g0_decision: decisions/2026-08-27_qm5_41185_xauxag_fractional_difference_reversion_g0.md
source_approval: decisions/2026-08-27_xauxag_fractional_difference_reversion_source_approval.md
source_author: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; Yaya, Vo, and Olayinka (2021), Resources Policy 72, 102045, DOI 10.1016/j.resourpol.2021.102045; official CME Group Gold & Silver Ratio Spread research."
source_citations:
  - type: peer_reviewed_relationship_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; governed parent packet"
    quality_tier: A
    role: state_dependent_gold_silver_relation_and_adverse_evidence
  - type: peer_reviewed_fractional_cointegration_paper
    citation: "Yaya, O. S., Vo, X. V., and Olayinka, H. A. (2021). Gold and silver prices, their stocks and market fear gauges: Testing fractional cointegration using a robust approach. Resources Policy 72, 102045."
    location: "DOI 10.1016/j.resourpol.2021.102045; governed parent packet"
    quality_tier: A
    role: gold_silver_fractional_cointegration_context
  - type: official_exchange_carrier_research
    citation: "CME Group, Gold & Silver Ratio Spread."
    location: "official CME Group research preserved in governed parent packet"
    quality_tier: A_official
    role: intermarket_ratio_carrier_and_distinct_metal_drivers
  - type: governed_composite_source
    citation: "QuantMechanica bounded XAU/XAG fixed fractional-difference ratio-reversion packet."
    location: "strategy-seeds/sources/YAYA-CME-XAUXAG-FRACD-RV-2026/source.md"
    quality_tier: internal_governed
    role: exact_filter_baseline_threshold_calendar_risk_atomicity_and_lifecycle
strategy_mechanic: monthly-xauxag-exact-316-synchronized-d1-log-ratios-fixed-d040-k64-fractional-difference-heldout-252-sample-zscore-absolute-050-contrarian-equal-notional-basket
sources:
  - "[[sources/YAYA-CME-XAUXAG-FRACD-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/fractional-difference-filter]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/fixed-fractional-difference]]"
  - "[[indicators/held-out-standardization]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, market-neutral-style, relative-value, structural-reversion, fractional-difference, monthly-rebalance, equal-notional-basket, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals, gold_silver_relative_value]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41185_XAU_XAG_FRACD_RV_D1
symbol: XAUUSD.DWX
host_symbol: XAUUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic: 411850000
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 6-9 completed XAU/XAG packages per full post-warm-up year after 316 synchronized completed D1 pairs; one consumed attempt per broker month."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_FIXED_FRACDIFF_TRANSLATION_RISK
r1_reasoning: "Two named peer-reviewed gold/silver relationship papers include fractional-cointegration evidence, and official CME research supports the ratio carrier; the fixed-filter trading conjunction remains an untested QM hypothesis."
r2_mechanical: PASS
r2_reasoning: "Clock, exact synchronized history, recurrence, fixed order/truncation, held-out baseline, threshold, contrarian sides, consumed attempt, aggregate fixed risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r3_reasoning: "Registered XAUUSD.DWX and XAGUSD.DWX D1 histories and native MT5 state supply every runtime input; synchronization and continuous-CFD basis risk remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, a fixed linear recurrence, sample arithmetic, ATR risk controls, and execution state; no trained signal or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 316 synchronized pairs; d=0.40; 64 coefficients; 252 prior filtered outputs; held-out latest output; inclusive abs(z)>=0.50; 700-D1 copy buffer; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/500-point spread ceilings."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED_Q01_PENDING
force_build: true
review_focus: "Falsify a fixed fractional-difference gold/silver ratio-reversion basket outside the directional XAU/SP500/NDX/XNG book. Verify exact synchronization/count, d=0.40 K=64 recurrence, 253 outputs, held-out 252-sample baseline, inclusive abs(z)>=0.50 contrarian sides, consumed attempt, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbols_period, first_tradable_month_bar, exact_316_synchronized_d1_pairs, completed_bar_only, strictly_chronological_history, fixed_fractional_order_040, exact_64_coefficient_recurrence, exact_253_filter_outputs, heldout_latest_output, sample_sd_denominator_251, sample_sd_floor_1e_12, inclusive_absolute_z_threshold_050, contrarian_pair_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-27 and decisions/2026-08-27_qm5_41185_xauxag_fractional_difference_reversion_g0.md: R1 passes with explicit translation risk on peer-reviewed gold/silver and official CME evidence; R2 locks the complete fixed-filter contract; R3 passes registered native XAU/XAG D1 with synchronization/CFD risk; R4 uses deterministic native arithmetic only. The canonical checker returned CLEAN across 4,684 registry identities, 1,335 cards, and 45 Strategy Wiki nodes; semantic review separates raw ratio, OLS, CADF/OU, threshold-cointegration, return-spread, rank, robust-location, quantile, channel, stochastic, and seasonal builds."
---

# QM5_41185 XAU/XAG Fixed Fractional-Difference Reversion

## Hypothesis

Gold and silver share precious-metal and USD drivers but differ in monetary,
safe-haven, industrial, and business-cycle exposure. Their relationship can
retain long memory rather than reverting around one immutable level. A fixed
fractional-difference operator may remove part of that persistence without
fitting a hedge coefficient or memory estimate, leaving relative shocks that
can be faded at a monthly decision clock.

Opposite equal-target-notional legs reduce common outright-metal direction and
form a market-neutral-style stream different from the directional XAU,
SP500, NDX, and XNG book. They do not prove neutrality or decorrelation. Q02
owns density and economics; unchanged Q09 owns realized overlap.

## Source Traceability And Claim Boundary

The governed packet is
`strategy-seeds/sources/YAYA-CME-XAUXAG-FRACD-RV-2026/source.md`, SHA-256
`CEC08E0FB0C040227A52053A7051F64CF5D530B2D68C67B8DD87851970B7E4DE`,
authorized before extraction by
`decisions/2026-08-27_xauxag_fractional_difference_reversion_source_approval.md`.

Schweikert supplies related but state-dependent gold/silver evidence and
adverse evidence against a universal constant vector. Yaya, Vo, and Olayinka
supply fractional-cointegration context. CME supplies the intermarket carrier
and distinct metal drivers. None tests this fixed filter, held-out z-score,
threshold, continuous CFDs, or execution contract.

No source return, alpha, memory estimate, coefficient, probability, p-value,
significance, density, profit factor, drawdown, cost, hedge ratio, neutrality,
CFD equivalence, decorrelation, or portfolio statistic is imported.

## Non-Duplicate Decision

The fail-closed checker returned CLEAN across 4,684 registry identities, 1,335
cards, and 45 Strategy Wiki nodes. Receipt:
`artifacts/qm5_xauxag_fracd_rv_preallocation_dedup_20260827.json`.

- `QM5_20157` standardizes a raw rolling log ratio.
- `QM5_20161` fits a rolling OLS hedge relation.
- `QM5_21526` fits and gates an annual CADF/OU model and half-life.
- `QM5_20012` uses a published monthly threshold-error equation.
- Return-spread, quantile, stochastic, channel, seasonal, rank, sign, robust-
  location, daily-path, and calendar baskets transform different state.

None applies fixed `(1-L)^0.40` with exactly 64 coefficients to 316 synchronized
daily ratios, standardizes a held-out latest output against the prior 252
outputs, and fades the inclusive `abs(z)>=0.50` state for one broker month.
Verdict:
`CLEAN_XAUXAG_FIXED_D040_K64_HELDOUT252_FRACTIONAL_DIFFERENCE_REVERSION`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XAUUSD.DWX`; companion/traded slot 1: exact
  `XAGUSD.DWX`.
- Logical tester symbol: `QM5_41185_XAU_XAG_FRACD_RV_D1` on the XAU host.
- Timeframe: D1; intended magics `411850000` and `411850001`.
- Decision: first synchronized executable tick after a genuine broker-month
  transition, within 180 elapsed minutes of raw host D1 bar open.
- Formation: exactly 316 synchronized completed D1 close pairs.
- Hold: next broker-month boundary; forty days is stale repair.
- Expected pre-result cadence: six to nine packages/year; Q02 retires below
  five in any full post-warm-up year.

## Formula

For chronological synchronized completed D1 close pairs `t=0..315`:

```text
s[t] = ln(XAU_close[t]) - ln(XAG_close[t])
d = 0.40
w[0] = 1
w[k] = w[k-1] * (k - 1 - d) / k, k=1..63
fd[j] = sum(k=0..63, w[k] * s[j-k]), j=63..315

baseline = fd[63..314]                 # exactly 252 outputs
latest = fd[315]                        # held out
mu = mean(baseline)
sd = sample_std(baseline, denominator=251)
require sd > 1e-12
z = (latest - mu) / sd

SELL XAU / BUY XAG iff z >= +0.50
BUY XAU / SELL XAG iff z <= -0.50
FLAT otherwise
```

The 64 recurrence coefficients, filter order, baseline and latest output are
all finite. The latest value never enters its own mean or standard deviation.
There is no fitted `d`, coefficient pruning, alternate normalization, p-value,
or signal-strength sizing.

## Rules

- Exact EA ID, symbols, D1, slots, magics, risk/news/Friday contract, and every
  locked input are mandatory.
- Consume the broker month before every fallible entry gate.
- Use only completed exact-timestamp-matched pairs in strict chronological
  order; current open bars never enter the filter.
- Reject wrong counts, stale endpoints, nonpositive closes, nonfinite weights
  or outputs, sample deviation at or below `1e-12`, or threshold/side mismatch.
- Both news axes, legacy news mode, and Friday close are OFF.

## 4. Entry Rules

1. Require EA ID 41185, exact host and companion, D1, slots 0/1, active
   magics `411850000`/`411850001`, fixed-risk framework inputs, and every
   singleton strategy input.
2. Process malformed-package repair and prior-month/stale exits before any
   entry-only gate.
3. Require a genuine new broker month within 180 minutes of raw host bar open;
   persist `yyyymm` before history, signal, news, spread, quote, ATR, sizing,
   margin, or orders. Never retry that month.
4. Reject owned exposure or same-magic current-month entry deals.
5. Exact-join 316 completed XAU/XAG D1 pairs from bounded histories. Require
   exact pair count, strictly increasing unique timestamps, exact latest
   endpoint agreement, endpoint age no more than ten calendar days, positive
   finite closes, and finite log ratios.
6. Build exactly 64 fixed fractional-difference weights with the locked
   recurrence, then exactly 253 filtered outputs. Standardize only the held-
   out latest output against the preceding 252 using sample denominator 251;
   require sample deviation strictly above `1e-12`.
7. Require finite `z>=+0.50` or `z<=-0.50`, mapping to the exact contrarian
   package sides. An interior or invalid state consumes the month flat.
8. Require XAU/XAG spreads no greater than 1,500/500 points, valid executable
   quotes, completed `ATR(20,D1)` for both legs, and valid contract metadata.
9. Split one aggregate `RISK_FIXED=1000` stop budget equally. Jointly round
   down lots to target equal absolute USD notionals while keeping combined
   frozen `3.5*ATR` stop risk within budget and notional mismatch within 20%.
10. Open XAU first and XAG second. Keep the package only if exactly one valid,
    stopped, correctly directed position exists in each slot. On any order or
    final validation failure, flatten every owned leg immediately.

## 5. Exit Rules

1. Close both legs on the first observed tick whose broker `yyyymm` is later
   than the package entry month.
2. Close both legs after forty elapsed calendar days as stale repair.
3. Immediately close all owned legs when the package is orphaned, duplicated,
   same-side, wrong-symbol/magic, missing a hard stop, nonfinite, or outside
   the 20% notional mismatch ceiling.
4. Broker hard stops and the framework kill switch remain authoritative.
5. There is no convergence recheck, target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, discretionary exit, or Friday flatten.

## 6. Filters (No-Trade Module)

- Fail closed outside exact host/timeframe/ID/slots/magics, risk mode,
  news/Friday modes, or locked strategy inputs.
- Reject a consumed month, late monthly tick, owned exposure, same-month deal,
  missing or stale history, wrong pair count/order, timestamp mismatch,
  nonpositive close, invalid ratio/weight/output, wrong output count, sample
  deviation at or below `1e-12`, sub-threshold z, excessive spread, invalid quote, missing
  ATR, invalid stop, invalid contract metadata, or invalid sizing solution.
- Lifecycle exits and package repair run before entry-only filters.
- Runtime may not read an external file/API, futures chain, paper estimate,
  optimizer output, trained artifact, prior result, or portfolio state.

## 7. Trade Management Rules

- Maintain at most one complete two-leg package and one consumed attempt per
  broker month.
- Preserve original broker hard stops and lots; never modify either after
  entry.
- On trade-state change or each new completed host D1 bar, repair malformed
  exposure and enforce month/stale exits before checking new entry state.
- Restart recovery combines a persistent month marker with owned position and
  deal history. Tester initialization clears only a marker dated after the
  restarted test clock.
- No randomness, adaptive parameter fit, external state, partial close,
  scale-in, grid, martingale, or pyramiding is allowed.

## Framework Execution Overrides

- News temporal mode: OFF.
- News compliance profile: NONE.
- Legacy news mode: OFF.
- Friday close: disabled for the multi-session paired hold.
- Stress rejection: zero for Q02 baseline.
- Framework kill switch and server-side hard stops: authoritative.

## Exit Precedence

1. Framework kill switch and each server-side hard stop.
2. Malformed, orphaned, duplicated, wrong-side, wrong-symbol/magic, stopless,
   or notional-invalid package repair.
3. Broker-month transition.
4. Forty-calendar-day stale repair.
5. No Friday, news, target, trail, break-even, partial, or discretionary exit.

## Runtime Data Dependencies

- Exact chart route `XAUUSD.DWX`, D1; synchronized companion
  `XAGUSD.DWX`, D1.
- Native completed D1 times/closes, completed `ATR(20,D1)`, bid/ask, spreads,
  contract/volume metadata, broker calendar, positions, deals, and one
  terminal-persistent month marker.
- No external file, API, futures curve, inventory series, macro series,
  analyst input, optimizer output, trained artifact, or portfolio state.

## Parameters To Test

Q02 uses only locked defaults; this table does not authorize rescue tuning.

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_pair_count_d1` | 316 | [316] | exact synchronized completed pairs |
| `strategy_frac_order` | 0.40 | [0.40] | fixed fractional-difference order |
| `strategy_frac_lags` | 64 | [64] | exact recurrence coefficient count |
| `strategy_baseline_outputs` | 252 | [252] | prior filtered outputs only |
| `strategy_entry_abs_z` | 0.50 | [0.50] | inclusive held-out extreme boundary |
| `strategy_history_bars_d1` | 700 | [700] | bounded copy buffer per leg |
| `strategy_month_entry_grace_minutes` | 180 | [180] | first-month-tick deadline |
| `strategy_max_endpoint_gap_days` | 10 | [10] | endpoint freshness cap |
| `strategy_atr_period_d1` | 20 | [20] | completed-D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard-stop multiple |
| `strategy_xau_max_spread_points` | 1500 | [1500] | XAU entry spread ceiling |
| `strategy_xag_max_spread_points` | 500 | [500] | XAG entry spread ceiling |
| `strategy_max_notional_mismatch_pct` | 20.0 | [20.0] | rounded package mismatch cap |
| `strategy_max_hold_days` | 40 | [40] | stale package repair |
| `strategy_deviation_points` | 20 | [20] | paired order deviation |

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1` for one aggregate package. The legs split the stop-risk
allowance equally and are jointly reduced until rounded target notionals are
within 20 percent while combined frozen-stop risk remains at or below budget.

Risk is high: the chosen order/truncation may not isolate a reverting shock;
fractional cointegration in source instruments may not survive in these CFDs;
the filter may remain nonstationary; monthly entry can lag a shock; XAG gaps,
contract-size asymmetry, spreads, financing, lot granularity, stop slippage,
and legging can break neutrality; and realized returns may remain correlated
with the certified XAU sleeve.

## Reputable-Source Criteria And Allowability

| gate | verdict | evidence |
|---|---|---|
| R1 | PASS_WITH_FIXED_FRACDIFF_TRANSLATION_RISK | Peer-reviewed gold/silver relationship evidence includes fractional cointegration; official CME research supports the ratio carrier; exact trading conjunction untested. |
| R2 | PASS | Exact clock, samples, recurrence, held-out baseline, threshold, direction, attempt, risk, atomicity, and lifecycle fixed. |
| R3 | PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered XAU/XAG D1 routes and native MT5 state supply all runtime fields. |
| R4 | PASS | Fixed deterministic arithmetic only, without trained output, banned signal, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Framework Alignment

- no_trade: exact host/timeframe/ID/slots, locked inputs, risk/news/Friday
  contract, month/attempt, history, synchronization, filter/baseline,
  threshold, spreads, quotes, ATR, stops, sizing, and package guards.
- trade_entry: held-out fractional-difference z state, persistent attempt,
  exact opposite legs, equal-notional shared risk, frozen hard stops, and
  second-leg rollback.
- trade_management: month/stale exit and malformed-package repair before
  every new entry decision.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Falsification And Requalification

Retire at Q02 on zero trades, fewer than five completed packages in any full
post-warm-up year, or nonpositive governed economics. Any wrong pair count or
timestamp, current-bar leak, recurrence/index defect, latest-output baseline
leak, variance-denominator error, wrong threshold/direction, same-month retry,
malformed package retention, aggregate-risk breach, or nondeterminism is an
implementation failure rather than a tunable result.

Changing the carrier, ratio orientation, clock, pair count, order,
truncation, recurrence, baseline, standard-deviation convention, threshold,
sides, stops, risk split, mismatch limit, lifecycle, symbols, timeframe,
news/Friday mode, or risk mode requires a new identity and full pipeline
qualification. Realized diversification is assessed only at unchanged Q09.

## Safety Boundary

This card authorizes deterministic allocation, one branch-only build, strict
compile/Q01, three backtest-only `RISK_FIXED` setfiles (logical and two
component warm-up routes), and one paced logical-basket Q02 enqueue if CPU
capacity permits. It does not authorize a manual backtest; live, demo,
shadow, stress, or optimization setfile; AutoTrading; `T_Live`; deploy or
live manifest; portfolio-gate mutation; portfolio admission; correlation
waiver; terminal control; or component-leg Q02 rows.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-27 | initial fixed fractional-difference XAU/XAG card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-27 | APPROVED; R1-R4 PASS with named risks | source approval, governed packet, clean dedup receipt, and G0 decision |
| Q01 Build Validation | - | NOT BUILT | no compile claim |
| Q02 Baseline Screening | - | NOT ENQUEUED | Q01 and capacity gates pending |
