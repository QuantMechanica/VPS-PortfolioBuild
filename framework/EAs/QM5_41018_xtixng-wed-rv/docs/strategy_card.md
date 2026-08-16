---
card_schema_version: 2
type: strategy
strategy_id: LI-BOROWSKI-XTIXNG-WED-2026_S01
variant_id: LI-BOROWSKI-XTIXNG-WED-2026_S01
source_id: LI-BOROWSKI-XTIXNG-WED-2026
ea_id: QM5_41018
slug: xtixng-wed-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41018_xtixng-wed-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-16
created_by: Research+Development
last_updated: 2026-08-16
g0_status: APPROVED
g0_decision: decisions/2026-08-16_xtixng_wednesday_relative_value_g0.md
source_approval: decisions/2026-08-16_xtixng_wednesday_relative_value_source_approval.md
source_author: "Wenhui Li; Qi Zhu; Fenghua Wen; Normaziah Mohd Nor; Krzysztof Borowski"
source_authors: "Wenhui Li; Qi Zhu; Fenghua Wen; Normaziah Mohd Nor; Krzysztof Borowski"
source_citation: "Li et al. (2022), Energy Economics 106, 105817; Borowski (2016), Journal of Management and Financial Sciences 26, 27-44; adverse evidence Meek and Hoelscher (2023), Cogent Economics & Finance 11(1), 2213876."
source_citations:
  - type: peer_reviewed_paper
    citation: "Li, W., Zhu, Q., Wen, F., and Mohd Nor, N. (2022). The evolution of day-of-the-week and the implications in crude oil market. Energy Economics 106, 105817."
    location: "Bounded abstract/highlights review strategy-seeds/sources/LI-WTI-DOW-2022.md; DOI 10.1016/j.eneco.2022.105817."
    quality_tier: A
    role: positive_wti_wednesday_direction
  - type: peer_reviewed_open_access_paper
    citation: "Borowski, K. (2016). Analysis of Selected Seasonality Effects in Markets of Future Contracts. Journal of Management and Financial Sciences 26, 27-44."
    location: "Complete-paper review strategy-seeds/sources/BOROWSKI-COMM-DOW-2016/source.md; natural-gas weekday table."
    quality_tier: B
    role: negative_natural_gas_wednesday_direction
  - type: peer_reviewed_open_access_paper
    citation: "Meek, A. C., and Hoelscher, S. A. (2023). Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics & Finance 11(1), 2213876."
    location: "Complete 21-page review strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md; DOI 10.1080/23322039.2023.2213876; Tables 2 and 6 adverse evidence."
    quality_tier: A
    role: adverse_modern_replication
strategy_mechanic: genuine-wednesday-long-xti-short-xng-equal-notional-one-session-relative-value-package
sources:
  - "[[sources/LI-BOROWSKI-XTIXNG-WED-2026]]"
concepts:
  - "[[concepts/cross-energy-weekday-relative-value]]"
  - "[[concepts/market-neutral-basket]]"
  - "[[concepts/calendar-seasonality]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, energy, relative-value, market-neutral-basket, calendar-seasonality, day-of-week, fixed-direction, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41018_XTI_XNG_WED_RV_D1
symbol: QM5_41018_XTI_XNG_WED_RV_D1
symbol_slot: 0
magic: 410180000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 45-52 completed two-leg Wednesday packages per full year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 48
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CONFLICTING_MODERN_EVIDENCE
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: PENDING
review_focus: "Falsify a jointly risked Wednesday crude-versus-natural-gas differential outside the certified index/metal/XNG book; adverse modern XNG evidence and Q09 correlation are binding downstream tests."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode_dual, magic_schema, one_position_per_magic_symbol, basket_atomicity, synchronized_history, cfd_source_basis, source_return_window_translation, known_component_overlap, dollar_not_beta_neutral, friday_close, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized Wednesday XTI/XNG relative-value candidate: R1 named peer-reviewed sources plus explicit adverse modern evidence; R2 locked weekday, continuity, directions, joint sizing, atomicity, stops, spread and lifecycle; R3 registered synchronized XTI/XNG D1 route; R4 native deterministic arithmetic only. Exact dedup clean and three fuzzy family siblings manually separated."
---

# QM5_41018 XTI/XNG Wednesday Relative-Value Basket

## Hypothesis

A synchronized long-WTI/short-natural-gas Wednesday package can isolate the
cross-energy weekday differential implied by a positive WTI Wednesday lineage
and a negative natural-gas Wednesday lineage without adding a full outright
commodity position. The carrier targets zero net dollar notional, not proven
beta, volatility, factor, market, or portfolio neutrality.

This is a falsification hypothesis. It is not a profitability, significance,
decorrelation, certification, or portfolio-admission claim. The newer adverse
natural-gas evidence makes Q02 a strict kill test rather than a confirmation
exercise.

## Source Traceability And Claim Boundary

The approved packet is
`strategy-seeds/sources/LI-BOROWSKI-XTIXNG-WED-2026/source.md`, approved under
`decisions/2026-08-16_xtixng_wednesday_relative_value_source_approval.md`.

Li et al. (2022) supply the positive WTI Wednesday direction and warn that
weekday efficiency changes through time. Borowski (2016) supplies the negative
natural-gas Wednesday direction and reports `-0.2664%` with `p=0.0136` in its
sample. Meek and Hoelscher (2023) are adverse evidence: their natural-gas
Wednesday coefficients are positive and insignificant.

The papers do not test this pair, combined risk, equal-notional sizing,
Darwinex CFDs, broker sessions, ATR stops, costs, or the QM book. Source
statistics are not sizing inputs or expected returns.

## Non-Duplicate Decision

The canonical pre-card checker found no exact identity across 4,505 registry
rows and 601 root cards. Its fuzzy hits were manually resolved:

- `QM5_20022_wti-wed-long` and `QM5_20018_xng-wed-short` are known standalone
  components without one combined risk budget, package invariant, atomic
  repair, or paired equity stream. Neither leg is authorized alone here.
- `QM5_41014_xtixng-thu-rv` shares the leg direction but owns a disjoint
  Thursday source coefficient and session.
- `QM5_41015_xtixng-tue-rv` owns Tuesday and the opposite package direction.
- Monday and Friday XTI/XNG baskets own different information clocks.
- `QM5_20237_xtixng-ecm-rv` is a rolling error-correction residual strategy.
- `QM5_12567_cum-rsi2-commodity` is an outright oscillator pullback.

Verdict:
`CLEAN_WEDNESDAY_XTI_XNG_JOINT_PACKAGE_WITH_KNOWN_COMPONENT_OVERLAP`.

## Markets, Timeframe, And Cadence

- Host/traded slot 0: `XTIUSD.DWX`, D1, BUY.
- Foreign/traded slot 1: `XNGUSD.DWX`, D1, SELL.
- Logical tester symbol: `QM5_41018_XTI_XNG_WED_RV_D1`.
- Decision cadence: one consumed attempt per Monday-anchored broker week.
- Normal entry: first tradable tick of a genuine broker Wednesday D1 bar.
- Normal exit: broker Wednesday 21:00.
- Expected frequency: approximately 45-52 completed packages/year.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1` for the entire package.

Standalone XTI or XNG tests are invalid. Both current D1 bars must be
synchronized and the previous completed host bar must be Tuesday.

## rules

- Trade exactly one Wednesday logical package: BUY XTI and SELL XNG.
- Open neither component alone; roll back immediately if the second leg fails.
- Target 1:1 absolute USD notional within ten-percent relative tolerance while
  keeping both frozen ATR-stop losses inside one fixed-cash package budget.
- Close the package at Wednesday 21:00 and repair it sooner if composition is
  partial, wrong, duplicated, same-sided, or materially imbalanced.
- Never retry a consumed broker week and never shift the signal to another day.

## 4. Entry Rules

- Evaluate entry only on a new host D1 bar with broker `day_of_week == 3`.
- Require the immediately prior completed host D1 bar to be Tuesday and both
  symbols' current D1 timestamps to match the host timestamp.
- Require the first observed host tick within five minutes of D1 open.
- Persist the Monday-anchored week attempt before history, news, spread,
  quote, ATR, sizing, or order gates.
- Require exact symbols, D1, slot 0/1 magic rows, no owned exposure, and no
  same-week entry history.
- Require nonnegative spreads no greater than 2,500 points on both legs.
- Read completed-bar `ATR(20,D1)` for each leg and freeze a
  `3.5 * ATR` broker hard stop; no take-profit.
- Solve volumes jointly under the aggregate fixed-cash budget and notional
  tolerance. Open XTI BUY first, XNG SELL second, and roll back XTI if XNG
  fails. A failed or rejected package cannot retry that week.

## 5. Exit Rules

- Close both legs at or after broker Wednesday hour 21.
- Also close at the first D1 bar whose timestamp differs from the entry bar,
  after three calendar days, or immediately on malformed composition.
- Retry rejected close requests on subsequent ticks until flat.
- Framework Friday close remains enabled at broker hour 21 as a fail-safe.
- Both frozen broker hard stops remain active; there is no target, trailing,
  break-even, partial profit, discretionary exit, or direction flip.

## 6. Filters (No-Trade Module)

- Exact host `XTIUSD.DWX`, foreign leg `XNGUSD.DWX`, D1, and slots 0/1.
- Locked Wednesday, prior-Tuesday continuity, five-minute grace, ATR 20,
  multiplier 3.5, Wednesday close hour 21, three-day stale guard, 2,500-point
  spread caps, and ten-percent notional tolerance.
- One package and one attempt per broker week, including restart.
- Fail closed on missing or unsynchronized bars, invalid metadata, price, ATR,
  stop, risk, volume, spread, or notional arithmetic.
- Both news axes and legacy news mode are OFF in the baseline.
- No external feed, trained output, adaptive parameter, or PnL fit.

## 7. Trade Management Rules

- Lifecycle and composition repair run before all entry-only gates on every
  tick and may not be delayed by news.
- Own only the registered symbols and magics; never touch another EA's trade.
- Immediately flatten orphaned, duplicated, wrong-symbol, wrong-magic,
  same-direction, or materially imbalanced exposure.
- Do not modify frozen stops and do not scale, pyramid, grid, or replace a
  stopped/rejected package during the same broker week.

## Parameters To Test

| parameter | default | authorized baseline | role |
|---|---:|---:|---|
| `strategy_xng_symbol` | `XNGUSD.DWX` | locked | paired symbol |
| `strategy_entry_dow` | 3 | 3 | broker Wednesday, Sunday=0 |
| `strategy_entry_grace_minutes` | 5 | 5 | first-tick tolerance |
| `strategy_atr_period_d1` | 20 | 20 | completed D1 stop estimate |
| `strategy_atr_sl_mult` | 3.5 | 3.5 | frozen per-leg stop distance |
| `strategy_exit_hour_broker` | 21 | 21 | Wednesday package close |
| `strategy_max_hold_days` | 3 | 3 | stale repair limit |
| `strategy_xti_max_spread_pts` | 2500 | 2500 | host spread cap |
| `strategy_xng_max_spread_pts` | 2500 | 2500 | foreign spread cap |
| `strategy_notional_ratio` | 1.0 | 1.0 | absolute USD notional target |
| `strategy_max_notional_error_pct` | 10.0 | 10.0 | rounded 1:1 tolerance |

No sweep is authorized. Changing the weekday, direction, component set,
hold, sizing, or risk rule requires a new approved card.

## Author Claims

The source packet preserves only bounded author findings. Li et al. identify
a positive WTI Wednesday effect and time-varying efficiency. Borowski reports
a negative natural-gas Wednesday mean and the stated unadjusted test result.
Meek and Hoelscher report conflicting modern natural-gas evidence. No author
claims that this paired CFD package is profitable or market neutral.

## risk

- One logical package uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`; signal and source magnitude never scale risk.
- Primary risks are conflicting source signs, multiple testing, decay,
  settlement/broker-day mapping, futures/CFD basis, legging, natural-gas gaps,
  financing, rounded notional imbalance, and costs.
- Retire at Q02 for zero trades, fewer than five completed packages/year,
  wrong-day or standalone entries, repeated attempts, orphan exposure,
  invalid risk mode, nondeterminism, or failed governed PF/DD criteria.
- Q09 alone may measure realized book correlation; equal notional is not a
  correlation waiver.

## Strategy Allowability Check

- [x] R1: named peer-reviewed lineages with precise DOI/table boundaries and
  explicit adverse modern evidence.
- [x] R2: exact weekday, directions, package sizing, stops, repair, and exit.
- [x] R3: registered synchronized XTI/XNG D1 logical route.
- [x] R4: deterministic native runtime data only; no banned signal method,
  grid, martingale, scale-in, or pyramid.
- [x] Exact identity dedup clean; component overlap and fuzzy siblings are
  disclosed and manually separated.

## Framework Alignment

- no_trade: exact symbols/timeframe/slots, locked inputs, synchronized bars,
  weekly attempt/history, spread, metadata, and validation gates.
- trade_entry: fixed Wednesday directions, aggregate fixed-risk and
  equal-notional volume solve, frozen stops, and partial-open rollback.
- trade_management: every-tick composition/orphan repair, timed close,
  next-D1 repair, stale close, and foreign-magic ownership.
- trade_close: framework close API, broker stops, and Friday fail-safe.

## Implementation Notes

- Use the current V5 basket lifecycle and `QM_Magic(41018, slot)`; never
  calculate a magic by hand.
- `basket_manifest.json` must declare the logical symbol and both slots.
- Emit one logical package equity stream and make standalone leg setfiles
  invalid by construction.
- `framework_alignment` must remain card-exact; no entry filter is added by
  Development.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-16 | initial Wednesday cross-energy relative-value build | G0 | APPROVED |

## Safety Boundary

This card authorizes one branch-only non-live build, strict Q01, one
`RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It authorizes no
manual backtest, live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy/T_Live manifest, portfolio admission, portfolio-gate change,
or correlation waiver.
