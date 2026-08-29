---
card_schema_version: 2
type: strategy
strategy_id: VILLAR-YAYA-XTIXNG-FRACD-RV-2026_S01
variant_id: VILLAR-YAYA-XTIXNG-FRACD-RV-2026_S01
source_id: VILLAR-YAYA-XTIXNG-FRACD-RV-2026
ea_id: QM5_41193
slug: xtixng-fracd-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41193_xtixng-fracd-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-29
created_by: Research+Development
last_updated: 2026-08-29
g0_status: APPROVED
g0_decision: decisions/2026-08-29_qm5_41193_xtixng_fractional_difference_reversion_g0.md
source_approval: decisions/2026-08-29_xtixng_fractional_difference_reversion_source_approval.md
source_author: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka"
source_authors: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka"
source_citation: "Villar and Joutz (2006), The Relationship Between Crude Oil and Natural Gas Prices, U.S. EIA; Ramberg and Parsons (2012), The Weak Tie Between Natural Gas and Oil Prices, The Energy Journal 33(2), DOI 10.5547/01956574.33.2.2; governed fixed fractional-difference arithmetic and basket-lifecycle packet."
source_citations:
  - type: government_research
    citation: "Villar, J. A., and Joutz, F. L. (2006). The Relationship Between Crude Oil and Natural Gas Prices. U.S. Energy Information Administration."
    location: "complete-read packet strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A_government
    role: oil_gas_physical_and_economic_linkage_with_instability
  - type: peer_reviewed_energy_paper
    citation: "Ramberg, D. J., and Parsons, J. E. (2012). The Weak Tie Between Natural Gas and Oil Prices. The Energy Journal 33(2), 13-35."
    location: "DOI 10.5547/01956574.33.2.2; complete-read governed parent packet"
    quality_tier: A
    role: adverse_state_dependent_oil_gas_relation_evidence
  - type: governed_method_source
    citation: "QuantMechanica bounded fixed fractional-difference arithmetic and synchronized two-leg lifecycle precedent."
    location: "strategy-seeds/sources/YAYA-CME-XAUXAG-FRACD-RV-2026/source.md"
    quality_tier: internal_governed
    role: fixed_filter_heldout_standardization_and_atomic_monthly_basket_contract
strategy_mechanic: monthly-xtixng-exact-316-synchronized-d1-log-ratios-fixed-d040-k64-fractional-difference-heldout-252-sample-zscore-absolute-050-contrarian-equal-notional-basket
sources:
  - "[[sources/VILLAR-YAYA-XTIXNG-FRACD-RV-2026]]"
concepts:
  - "[[concepts/oil-gas-relative-value]]"
  - "[[concepts/fractional-difference-filter]]"
  - "[[concepts/market-neutral-style-basket]]"
indicators:
  - "[[indicators/fixed-fractional-difference]]"
  - "[[indicators/held-out-standardization]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, natural-gas, relative-value, market-neutral-style, structural-reversion, fractional-difference, monthly-renewal, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41193_XTI_XNG_FRACD_RV_D1
symbol: QM5_41193_XTI_XNG_FRACD_RV_D1
host_symbol: XTIUSD.DWX
companion_symbol: XNGUSD.DWX
symbol_slots: [0, 1]
magics: [411930000, 411930001]
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: paired_long_short
expected_trade_frequency: "Approximately 6-9 completed XTI/XNG packages per full post-warm-up year after 316 synchronized completed D1 pairs; one consumed attempt per broker month."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_FIXED_FRACDIFF_CROSS_CARRIER_TRANSLATION_RISK
r1_reasoning: "Complete U.S. government and peer-reviewed oil/gas evidence with binding instability findings plus a complete governed peer-reviewed fractional-filter precedent; fractional oil/gas integration and the exact trading conjunction remain untested."
r2_mechanical: PASS
r2_reasoning: "Clock, exact synchronized history, recurrence, fixed order/truncation, held-out baseline, threshold, contrarian sides, consumed attempt, aggregate fixed risk, atomicity, and lifecycle are deterministic and locked."
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r3_reasoning: "Registered XTIUSD.DWX and XNGUSD.DWX D1 histories and native MT5 state supply every runtime input; synchronization and continuous-CFD basis risk remain explicit."
r4_ml_forbidden: PASS
r4_reasoning: "Only timestamps, completed prices, logarithms, a fixed linear recurrence, sample arithmetic, ATR risk controls, and execution state; no trained signal, banned signal, or external runtime feed."
parameters_to_test: "Locked Q02 baseline only: 316 synchronized pairs; d=0.40; 64 coefficients; 252 prior filtered outputs; held-out latest output; inclusive abs(z)>=0.50; 700-D1 copy buffer; 180-minute month-entry grace; 10-day endpoint staleness; ATR(20)*3.5 stops; equal target notionals; 20% notional mismatch ceiling; 40-day stale exit; 1500/3000-point spread ceilings."
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
review_focus: "Falsify a fixed fractional-difference oil/gas ratio-reversion basket outside the directional XAU/SP500/NDX/XNG book. Verify exact synchronization/count, d=0.40 K=64 recurrence, 253 outputs, held-out 252-sample baseline, inclusive abs(z)>=0.50 contrarian sides, consumed attempt, aggregate fixed risk, equal-notional tolerance, atomicity, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_energy_carrier, exact_symbols_period, first_tradable_month_bar, exact_316_synchronized_d1_pairs, completed_bar_only, strictly_chronological_history, fixed_fractional_order_040, exact_64_coefficient_recurrence, exact_253_filter_outputs, heldout_latest_output, sample_sd_denominator_251, sample_sd_floor_1e_12, inclusive_absolute_z_threshold_050, contrarian_pair_sides, monthly_attempt_state, equal_notional_pair, aggregate_fixed_risk, atomic_pair_lifecycle, hard_stops_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-29 and decisions/2026-08-29_qm5_41193_xtixng_fractional_difference_reversion_g0.md: R1 passes with explicit cross-carrier translation risk on complete government, peer-reviewed, and governed method evidence; R2 locks the complete fixed-filter contract; R3 passes registered native XTI/XNG D1 with synchronization/CFD risk; R4 uses deterministic native arithmetic only. The canonical checker returned CLEAN across 4,692 registry identities, 1,343 cards, and 45 Strategy Wiki nodes; semantic review separates the metal sibling, daily pseudomedian, ECM, raw-ratio, robust-slope, rank, calendar, and oscillator builds."
---

# QM5_41193 XTI/XNG Fixed Fractional-Difference Reversion

## Hypothesis

Crude oil and natural gas share production, substitution, drilling,
financing, transport, and LNG links but differ sharply in regional storage,
weather, transport constraints, and short-run volatility. Their relative
price can therefore retain long memory without reverting around one immutable
level. A fixed fractional-difference operator may remove part of that
persistence without fitting a hedge coefficient or memory estimate, leaving
relative shocks that can be faded at a monthly decision clock.

Opposite equal-target-notional legs reduce common outright-energy direction
and form a market-neutral-style stream different from the directional XAU,
SP500, NDX, and XNG book. They do not prove neutrality or decorrelation. Q02
owns density and economics; unchanged Q09 owns realized overlap.

## Source Traceability And Claim Boundary

The governed packet is
`strategy-seeds/sources/VILLAR-YAYA-XTIXNG-FRACD-RV-2026/source.md`, SHA-256
`C485EF239A918AD118C14DD866A41B6B4BD4FDD79DE6B5F68A97AB32A5CE20F8`,
authorized before extraction by
`decisions/2026-08-29_xtixng_fractional_difference_reversion_source_approval.md`.

Villar/Joutz and Ramberg/Parsons supply a weak, changing oil/gas relationship
and adverse evidence against a permanent fixed ratio. The governed method
packet supplies exact fractional-filter arithmetic and atomic monthly basket
mechanics. Its gold/silver fractional-cointegration finding does not transfer.
No source tests this oil/gas filter, threshold, continuous CFDs, or execution
contract.

No source return, alpha, memory estimate, coefficient, probability, p-value,
significance, density, profit factor, drawdown, cost, hedge ratio, neutrality,
CFD equivalence, decorrelation, or portfolio statistic is imported.

## Non-Duplicate Decision

The fail-closed checker returned `CLEAN` across 4,692 registry identities,
1,343 cards, and 45 Strategy Wiki nodes. Receipt:
`artifacts/qm5_xtixng_fracd_rv_preallocation_dedup_20260829.json`.

- `QM5_41185` applies the fixed filter to a precious-metal ratio under
  gold/silver evidence and metal execution contracts.
- `QM5_41192` uses 17-23 adjacent daily relative returns from one completed
  month and an inclusive-pair pseudomedian, not 316 levels and a fixed filter.
- `QM5_20237` fits an intercept, oil beta, and time trend by rolling OLS and
  trades residual crossings; this card fits none of those quantities.
- Raw-ratio, fixed-ratio, return-spread, robust-slope, rank, change-point,
  calendar, weekday, and oscillator builds transform different state.

None applies fixed `(1-L)^0.40` with exactly 64 coefficients to 316
synchronized daily XTI/XNG ratios, standardizes a held-out latest output
against the prior 252 outputs, and fades inclusive `abs(z)>=0.50` for one
broker month. Verdict:
`CLEAN_XTIXNG_FIXED_D040_K64_HELDOUT252_FRACTIONAL_DIFFERENCE_REVERSION`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: exact `XTIUSD.DWX`; companion/traded slot 1: exact
  `XNGUSD.DWX`.
- Logical tester symbol: `QM5_41193_XTI_XNG_FRACD_RV_D1` on the XTI host.
- Timeframe: D1; magics `411930000` and `411930001`.
- Decision: first synchronized executable tick after a genuine broker-month
  transition, within 180 elapsed minutes of raw host D1 bar open.
- Formation: exactly 316 synchronized completed D1 close pairs.
- Hold: next broker-month boundary; forty days is stale repair.
- Expected pre-result cadence: six to nine packages/year after warm-up; Q02
  retires below five in any full post-warm-up year.

## Formula

For chronological synchronized log-ratio levels:

```text
s[t] = ln(XTI_close[t]) - ln(XNG_close[t])
d = 0.40
K = 64
w[0] = 1
w[k] = w[k-1] * (k - 1 - d) / k, k=1..63
fd[t] = sum(k=0..63, w[k] * s[t-k])
```

Exactly 253 outputs exist. Define `mu` and sample `sd` from outputs 0..251
only, with variance denominator 251. Output 252 is held out:

```text
z = (fd[252] - mu) / sd
z >= +0.50 => SELL XTI / BUY XNG
z <= -0.50 => BUY XTI / SELL XNG
otherwise  => FLAT
```

Reject non-finite state or `sd<=1e-12`. The latest output never enters its own
baseline. Signal magnitude never changes risk.

## Rules

These rules are the complete locked baseline. No fitted memory order, hedge
coefficient, trend, p-value, stationarity test, raw-ratio fallback, momentum,
seasonal, event, inventory, curve, volume, volatility, optimizer, prior-result,
or external-data filter is authorized.

## 4. Entry Rules

1. Evaluate only on exact `XTIUSD.DWX`, D1, EA ID 41193, slot 0, with exact
   companion `XNGUSD.DWX` in slot 1.
2. Process malformed and later-month owned exposure before every entry gate.
3. Enter only on the first synchronized D1 bar after a genuine broker-month
   transition and within 180 elapsed minutes of the raw host bar open. A late
   attachment consumes the month flat.
4. Persist broker `yyyymm` before history, signal, news, spread, quote, ATR,
   sizing, margin, or submission. Never retry the month.
5. Exact-join 316 completed synchronized close pairs from a bounded 700-bar
   buffer. Require positive finite prices, strict chronological timestamps,
   identical newest timestamps, and endpoint staleness no greater than ten
   calendar days.
6. Generate exactly 64 finite weights by the locked recurrence, exactly 253
   finite filtered outputs, and the held-out z-score with the specified
   baseline and variance denominator.
7. Inclusive positive threshold sells XTI/buys XNG; inclusive negative
   threshold buys XTI/sells XNG. Interior or invalid state consumes the month.
8. Require valid completed-bar ATR(20,D1) on both legs, frozen `3.5*ATR` hard
   stops, valid quotes, and spreads not above 1,500/3,000 points.
9. Split one aggregate fixed-cash risk budget equally across stop risks,
   target equal absolute USD notionals, and reject more than 20% realized
   notional mismatch.
10. Submit XTI first and XNG second. If the second leg or final composition
    fails, flatten all owned exposure immediately. No retry or pending order.

## 5. Exit Rules

1. Close both owned legs at the first tick in a later broker `yyyymm`.
2. Close both after forty elapsed calendar days as a final stale guard.
3. Immediately flatten orphaned, duplicated, same-side, wrong-symbol/magic,
   stopless, invalid-volume, invalid-open-time, or notional-invalid exposure.
4. Frozen broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled for the monthly package.
6. No target, residual convergence exit, reversal, trailing stop, break-even
   move, partial close, scale-in, grid, martingale, or pyramid is authorized.

## 6. Filters (No-Trade Module)

- Exact host, companion, D1 period, EA ID, slots, and registered magics.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and the legacy news mode are OFF.
- Genuine month boundary, durable attempt, exact synchronized history,
  recurrence, output count, held-out baseline, variance floor, threshold,
  quote, spread, ATR, sizing, notional, and stop geometry must be valid.
- Failure after attempt persistence consumes the month.

## 7. Trade Management Rules

- Own exactly zero or two positions under magics `411930000/411930001`.
- A valid package has opposite sides, one stopped leg per registered slot,
  and no more than 20% absolute-notional mismatch.
- Freeze original hard stops; never widen, trail, or remove them.
- Run malformed, later-month, and stale repair on every tick before entries.
- Persist last attempted broker `yyyymm` in terminal global state so restart
  cannot create a second attempt.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Split aggregate stop risk 50/50; target equal absolute USD notionals.
- Frozen hard stop: `3.5*ATR(20,D1)` per leg; no take-profit.
- Reject invalid tick value, tick size, volume step/minimum, computed lots,
  stop geometry, price, margin, spread, or post-rounding notional balance.
- This card creates no live, demo, shadow, stress, or optimization preset.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_pair_count_d1` | 316 | exact synchronized completed pairs |
| `strategy_frac_lags` | 64 | exact finite recurrence length |
| `strategy_baseline_outputs` | 252 | baseline outputs excluding latest |
| `strategy_frac_order` | 0.40 | fixed non-fitted filter order |
| `strategy_entry_abs_z` | 0.50 | inclusive absolute entry boundary |
| `strategy_history_bars_d1` | 700 | bounded join buffer per leg |
| `strategy_entry_grace_minutes` | 180 | month-boundary entry window |
| `strategy_max_endpoint_stale_days` | 10 | newest completed-pair freshness |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_notional_mismatch_pct` | 20.0 | realized package tolerance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_xti_max_spread_points` | 1500 | XTI entry cost guard |
| `strategy_xng_max_spread_points` | 3000 | XNG entry cost guard |

## Data Requirements

Registered `XTIUSD.DWX` and `XNGUSD.DWX` D1 OHLC/timestamps, broker clock,
quotes, symbol contract properties, ATR, positions, deals, and terminal-global
attempt state only. No futures curve, inventory, storage, weather, volume,
open interest, event feed, API, CSV, optimizer artifact, or manual signal.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, month boundary, attempt, synchronized history, filter, z-score, side, spread, ATR, sizing | Trade Entry | `Strategy_EntrySignal` and deterministic helpers |
| malformed package, later-month exit, stale repair | Trade Management | `Strategy_ManageOpenPosition` and package helpers |
| monthly renewal and survivor repair | Trade Close | lifecycle helper; Friday close disabled |
| kill switch, ownership, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hook | `Strategy_NewsFilterHook` returns false; both axes OFF |

## Falsification And Requalification

Q02 retires the identity on zero trades, fewer than five completed packages
per full post-warm-up year, nonpositive governed economics, wrong history or
output count, look-ahead, fitted parameter, wrong recurrence or variance
denominator, latest-output leakage, wrong threshold/side, retry, missing stop,
legging residue, wrong lifecycle, nondeterminism, or risk mismatch.

Any change to carrier, ratio orientation, pair count, filter order, lag count,
baseline, variance formula, threshold, direction, risk, stop, or hold creates
a new identity. No weak result may be rescued by changing one of those rules.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-29 | initial XTI/XNG fractional-difference card | G0 | APPROVED; build pending |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-29 | APPROVED; R1-R4 PASS | `decisions/2026-08-29_qm5_41193_xtixng_fractional_difference_reversion_g0.md` |
| Q01 Build Validation | 2026-08-29 | NOT_BUILT | deterministic build pending |
| Q02 Baseline Screening | 2026-08-29 | NOT_ENQUEUED_Q01_PENDING | no work item before compile/review PASS |

## Safety Boundary

This card authorizes deterministic magic allocation for slots 0 and 1, one
branch-only non-live V5 build, exact D1 `RISK_FIXED` backtest presets, strict
compile/Q01, and one paced logical-basket Q02 enqueue after prerequisites and
a non-binding CPU check. It does not authorize a manual backtest,
live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`, deploy or
live manifest, portfolio-gate change, portfolio admission, correlation waiver,
terminal control, or component-leg Q02 row.
