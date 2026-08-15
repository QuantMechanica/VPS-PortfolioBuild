---
card_schema_version: 2
type: strategy
strategy_id: MEEK-HOELSCHER-XTIXNG-TUE-2026_S01
variant_id: MEEK-HOELSCHER-XTIXNG-TUE-2026_S01
source_id: MEEK-HOELSCHER-XTIXNG-TUE-2026
ea_id: QM5_41015
slug: xtixng-tue-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41015_xtixng-tue-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-15
created_by: Research+Development
last_updated: 2026-08-15
g0_status: APPROVED
g0_decision: decisions/2026-08-15_xtixng_tuesday_relative_value_g0.md
source_approval: decisions/2026-08-15_xtixng_tuesday_relative_value_source_approval.md
source_author: "Andrew C. Meek; Seth A. Hoelscher"
source_authors: "Andrew C. Meek; Seth A. Hoelscher"
source_citation: "Meek, A. C. and Hoelscher, S. A. (2023). Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics & Finance 11(1), 2213876. DOI 10.1080/23322039.2023.2213876."
source_citations:
  - type: peer_reviewed_open_access_paper
    citation: "Meek, Andrew C. and Hoelscher, Seth A. (2023). Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics & Finance 11(1), 2213876."
    location: "WTI Table 2 and natural-gas Table 6; DOI 10.1080/23322039.2023.2213876; complete-paper evidence in strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md"
    quality_tier: A
    role: tuesday_cross_energy_return_differential
strategy_mechanic: genuine-tuesday-short-xti-long-xng-equal-notional-one-session-relative-value-package
sources:
  - "[[sources/MEEK-HOELSCHER-XTIXNG-TUE-2026]]"
concepts:
  - "[[concepts/cross-energy-weekday-relative-value]]"
  - "[[concepts/tuesday-natural-gas-premium]]"
  - "[[concepts/approximately-dollar-neutral-basket]]"
indicators:
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, natural-gas, calendar-seasonality, relative-value, approximately-dollar-neutral-basket, atr-hard-stop, intraday-time-exit, low-frequency]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41015_XTI_XNG_TUE_RV_D1
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410150000
period: D1
timeframe: D1
expected_trade_frequency: "One paired Tuesday-session package per eligible broker week; approximately 45-52 completed logical packages/year before holidays, synchronization, spread, news, and safety gates."
expected_trades_per_year_per_symbol: 48
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
review_focus: "Falsify the source-coefficient Tuesday short-WTI/long-XNG differential after CFD session mapping, costs, synchronized attachment, equal-notional rounding, combined stop risk, and legging. It adds a cross-energy weekday package rather than another index, outright metal, or XNG oscillator; Q09 alone may establish realized book correlation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode_dual, magic_schema, logical_basket_route, one_position_per_magic_symbol, basket_atomicity, exact_tuesday_clock, synchronized_d1_bars, combined_risk_budget, equal_notional_tolerance, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 peer-reviewed complete-read weekday paper; R2 locked Tuesday paired clock, directions, synchronization, joint risk/equal-notional sizing, repair and exits; R3 registered XTI/XNG D1; R4 deterministic native arithmetic only; exact dedup clean and fuzzy siblings manually separated."
---

# XTI/XNG Tuesday Relative-Value Basket

## Hypothesis

Meek and Hoelscher report heterogeneous weekday returns across energy futures.
In their four asymmetric-variance models, WTI's Tuesday coefficient is near
zero while natural gas has a positive Tuesday coefficient of roughly 15-19
basis points. A simultaneous short-WTI/long-natural-gas Tuesday package may
capture the resulting 16-22 basis-point source-defined differential while
targeting zero net dollar notional instead of adding another outright
energy-beta sleeve.

This is a falsification candidate, not a profitability, neutrality, or
decorrelation claim. Equal USD notionals do not neutralize volatility, curve
basis, gaps, financing, or nonlinear CFD behavior.

## Source Traceability And Claim Boundary

The sole governed packet is
`strategy-seeds/sources/MEEK-HOELSCHER-XTIXNG-TUE-2026/source.md`, approved
before extraction at
`decisions/2026-08-15_xtixng_tuesday_relative_value_source_approval.md`.

The complete peer-reviewed paper review is preserved in the parent packet
`strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md`. The paper uses
synchronized front-/second-month futures and ending-weekday close-to-close log
returns from 2002 through 2021. WTI Table 2 and natural-gas Table 6 supply the
Tuesday coefficient signs and magnitudes.

The authors do not test this pair, covariance, equal-notional sizing, combined
fixed risk, hard stops, Darwinex CFDs, or costs. The first-tick-to-21:00 CFD
carrier omits the prior-close-to-first-tick gap. No source return,
significance, profit factor, drawdown, trade count, neutrality, or portfolio
correlation transfers.

## Non-Duplicate Decision

The deterministic pre-allocation checker scanned 4,502 EA-registry rows and
598 root cards. It found no exact identity and two expected fuzzy siblings:
`xtixng-ecm-rv`, whose 252-D1 OLS error-correction residual is mechanically
unrelated, and the opposite-direction Thursday coefficient basket. Manual
review fixes the material boundaries:

- `QM5_41014_xtixng-thu-rv` trades the opposite long-WTI/short-XNG package
  on Thursday from natural gas's significant Thursday discount.
- `QM5_20110_xti-xng-fri-rv` trades long WTI and short gas on Friday from
  WTI's significant Friday premium.
- `QM5_20016_xti-xng-mon-rv` trades the same short-WTI/long-XNG directions
  for Monday's return clock and closes at Tuesday's first tick, before this
  Tuesday-session package can open.
- `QM5_12610_wti-tue-fade` and `QM5_12818_xng-tue-prem` are standalone
  legs without the joint risk budget, equal-notional contract, or atomic
  two-leg lifecycle.
- `QM5_12608`, `QM5_12733`, `QM5_12813`, and `QM5_20237` require ratio,
  relative momentum, physical-season, or error-correction price states and
  hold beyond one session.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon oscillator pullback, not a
  weekday relative-value package.

Verdict: `CLEAN_TUESDAY_XTI_XNG_SOURCE_DIFFERENTIAL_AFTER_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Host: exact `XTIUSD.DWX`, D1, magic slot 0, SELL.
- Paired leg: exact `XNGUSD.DWX`, D1, magic slot 1, BUY.
- Logical tester symbol: `QM5_41015_XTI_XNG_TUE_RV_D1`.
- Decision: first executable tick within five minutes of a genuine broker
  Tuesday D1 bar immediately following a completed Monday host bar.
- Normal exit: broker Tuesday at hour 21.
- Maximum cadence: one consumed attempt per Monday-anchored broker week.
- Planning cadence: approximately 45-52 completed logical packages/year.
- Entire-package backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

Standalone XTI or XNG tests are invalid. Both current D1 bars must be
synchronized to the host decision date.

## Rules

The entry, exit, filter, and lifecycle rules below are the complete authorized
baseline. No weekday port, directional fallback, single-leg rescue, signal
filter, or parameter sweep is authorized.

## 4. Entry Rules

1. Require exact `XTIUSD.DWX` D1 host, magic slot offset 0, and all locked
   inputs.
2. Evaluate only on a current broker Tuesday whose immediately prior
   completed host D1 bar is Monday. Missing or holiday-shifted Tuesdays
   never move to another day.
3. Require the first observed host tick within five minutes of the Tuesday D1
   open and require both symbols' current D1 bar-open timestamps to equal the
   host bar-open timestamp. A late or unsynchronized attachment consumes the
   week and remains flat.
4. Persist the Monday-anchored broker-week key before history, quote, spread,
   news, sizing, or order gates. Never retry the week after a block, reject,
   stop, repair, or restart.
5. Require no owned leg or owned entry deal for the current broker week.
6. Require positive finite completed `ATR(20,D1)` on both symbols, valid
   executable quotes, and nonnegative spreads no wider than 1,500 XTI points
   and 3,000 XNG points. A zero modeled `.DWX` spread is valid.
7. Build exactly one package: SELL XTI and BUY XNG. Attach a frozen
   `3.5 * ATR(20,D1)` hard stop to each leg and no take-profit.
8. Solve both volumes jointly so the two stop losses consume one combined
   `RISK_FIXED` budget and rounded absolute USD notionals are within 15% of
   each other. Each leg must receive positive risk and valid broker volume.
9. Open XTI first, then XNG. If the second leg fails, immediately close the
   first leg; an incomplete package is never held intentionally.
10. Signal magnitude never scales risk. No pending order, extra position,
    scale-in, pyramid, grid, martingale, or directional fallback exists.

## 5. Exit Rules

1. At broker Tuesday hour 21 or later, close every owned leg and retry on
   later ticks until flat.
2. Close both legs at the first current D1 bar that is not the entry Tuesday;
   this is a stale repair, not the normal hold.
3. Close both legs after three elapsed calendar days as a final stale guard.
4. Close every owned leg immediately when composition is orphaned, duplicated,
   same-sided, wrong-symbol, wrong-magic, or outside the 15% entry-notional
   tolerance.
5. A hard stop on either leg makes the surviving leg an orphan and triggers
   immediate package repair.
6. The framework kill switch and server-side stops remain authoritative.
7. No target, opposite-signal exit, trailing stop, break-even move, partial
   close, discretionary close, or re-entry exists.

## 6. Filters (No-Trade Module)

- Exact host contract: `XTIUSD.DWX`, D1, slot offset 0.
- Current host date must be Tuesday and the completed predecessor Monday.
- Both current symbol bars must be synchronized exactly.
- History, calendar, parameter, ATR, quote, spread, volume, risk, attempt, and
  package-composition state fail closed.
- Framework kill switch remains authoritative.
- Both news axes are OFF because the source signal is the native weekday
  return differential; management and repair remain reachable regardless of
  entry clearance.
- No external futures, inventory, storage, weather, curve, volume, open
  interest, file, API, analyst forecast, or discretionary state is read.

## 7. Trade Management Rules

- Exactly zero or two valid owned legs; every other state is flattened.
- One combined package and one consumed attempt per broker week.
- Persist the attempt before every fallible entry gate.
- Repair is every-tick and precedes entry-only news and spread gates.
- No scale-in, pyramid, grid, martingale, partial close, adaptive parameter,
  PnL-dependent state, or trained output.

## Parameters To Test

| parameter | default | declared range | role |
|---|---:|---|---|
| `strategy_entry_dow` | 2 | [2] | broker Tuesday, Sunday=0 |
| `strategy_entry_grace_minutes` | 5 | [5] | first-tick attachment bound |
| `strategy_exit_hour_broker` | 21 | [21] | same-session normal flatten |
| `strategy_atr_period` | 20 | [20] | completed D1 hard-stop estimate |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard-stop distance |
| `strategy_notional_tolerance_pct` | 15.0 | [15.0] | maximum rounded notional mismatch |
| `strategy_max_hold_days` | 3 | [3] | stale package guard |
| `strategy_xti_max_spread_points` | 1500 | [1500] | XTI entry spread ceiling |
| `strategy_xng_max_spread_points` | 3000 | [3000] | XNG entry spread ceiling |

Every value is locked. A later phase may test only a separately approved,
predeclared variant; a failed Q02 baseline may not be rescued by widening this
card.

## Author Claims

The source supplies the Tuesday coefficient inputs and cross-energy weekday
heterogeneity. The paired trade, risk, execution, and CFD mapping are QM
choices. No source performance claim is imported.

## Initial Risk Profile

- `expected_pf: 1.01` is a conservative queue-ordering estimate, not evidence.
- `expected_dd_pct: 25.0` reflects natural-gas gap and legging risk.
- Expected cadence is approximately 45-52 logical packages per full year.
- `risk_class: high`.
- `ml_required: false`.

## Risk

Backtests use one logical-package budget: `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The budget is split across the two
frozen stop risks while the volume solver targets equal absolute USD
notionals. Equal notional is not beta neutrality.

Q02 must retire on zero packages, fewer than five completed logical packages
per full year, wrong weekday or late entries, unsynchronized bars, repeated
weeks, single-leg exposure, material notional imbalance, risk-mode mismatch,
or nonpositive governed economics. Q09 alone may establish realized
correlation with XAU, SP500, NDX, and XNG.

## Strategy Allowability Check

- [x] R1: one peer-reviewed open paper with DOI, complete-paper evidence, and
  exact WTI/natural-gas Tuesday table inputs.
- [x] R2: weekday, predecessor, synchronization, directions, attempt, joint
  sizing, stops, spread caps, repair, and exit are deterministic.
- [x] R3: registered native XTI/XNG D1 history supplies every runtime input.
- [x] R4: native arithmetic and framework state only; no runtime econometric
  model, trained output, banned signal indicator, grid, or martingale.
- [x] Exact/fuzzy dedup completed and the Thursday/ECM siblings manually
  separated.

## Framework Alignment

- no_trade: exact host/D1/slot, locked inputs, synchronized bars, weekday,
  predecessor, attempt, quote, spread, ATR, and composition guards.
- trade_entry: source-fixed short-XTI/long-XNG package, joint risk/equal-
  notional volume solve, frozen hard stops, and atomic second-leg rollback.
- trade_management: every-tick malformed-package repair, Tuesday 21:00
  flatten, first-non-Tuesday repair, and three-day stale close.
- trade_close: framework close API for both registered magics plus server hard
  stops.
- news hook: source-only metadata and no management suspension.

## Implementation Notes

- Build one logical basket hosted on `XTIUSD.DWX` D1. Slot 0 is XTI and slot 1
  is XNG; register both before compilation.
- Follow the `QM5_12533` basket-manifest and package-lifecycle recipe and the
  current V5 framework close/risk APIs.
- Use the framework new-bar gate only in the entry path. Management and repair
  run every tick before the news/entry gate.
- Persist the Monday-anchored attempt via the terminal global-variable and
  corroborating deal-history pattern.
- Create exactly one logical-basket D1 `backtest` setfile. Do not create
  standalone XTI/XNG, demo, shadow, live, stress, or optimization setfiles.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-15 | initial Tuesday XTI/XNG source-differential card | G0 | APPROVED |
| v1-q01 | 2026-08-15 | strict compile, build guardrails, reference tests, and P1 validation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-15 | APPROVED | `decisions/2026-08-15_xtixng_tuesday_relative_value_g0.md` |
| Q01 Build Validation | 2026-08-15 | PASS | `D:/QM/reports/pipeline/QM5_41015/P1/P1_QM5_41015_result.json` |
| Q02 Baseline Screening | 2026-08-15 | PENDING | enqueue only after Q01 PASS |

## Safety Boundary

Research/backtest only. This card does not authorize a manual tester; live,
demo, shadow, stress, or optimization setfiles; AutoTrading; `T_Live`; a
deploy or T_Live manifest; portfolio admission; a portfolio-gate edit; or a
correlation waiver.
