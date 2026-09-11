---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CRABEL-CME-XAUXAG-WR2-CLV-RV-20260912_S01
variant_id: SCHWEIKERT-CRABEL-CME-XAUXAG-WR2-CLV-RV-20260912_S01
source_id: SCHWEIKERT-CRABEL-CME-XAUXAG-WR2-CLV-RV-20260912
ea_id: QM5_41448
slug: xauxag-wr2-clv-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41448_xauxag-wr2-clv-rv.md
execution_contract_status: APPROVED
created: 2026-09-12
created_by: Research+Development
last_updated: 2026-09-12
g0_status: APPROVED
g0_decision: decisions/2026-09-12_qm5_41448_xauxag_wr2_clv_reversion_g0.md
source_approval: decisions/2026-09-12_xauxag_wr2_clv_reversion_source_approval.md
source_author: "Karsten Schweikert; Toby Crabel; CME Group; OpenAI Codex"
source_authors: "Karsten Schweikert; Toby Crabel; CME Group; OpenAI Codex"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; CME Group Gold & Silver Ratio Spread; governed Crabel range-state lineage."
source_citations:
  - type: peer_reviewed_exchange_and_reputable_bounded_mechanization
    citation: "Peer-reviewed gold/silver relation evidence, CME ratio-spread carrier, and governed reputable range-state lineage."
    location: strategy-seeds/sources/SCHWEIKERT-CRABEL-CME-XAUXAG-WR2-CLV-RV-20260912/source.md
    quality_tier: A_and_B_lineages_with_cross_source_and_weekly_translation_risk
    role: gold_silver_relative_carrier_weekly_range_expansion_and_reversion_lineage
strategy_mechanic: normalized-week-boundary-xau-xag-two-synchronized-completed-weeks-newest-strict-wider-log-ratio-close-range-strict-outer-quartile-final-ratio-close-contrarian-equal-notional-one-week-basket
sources: ["[[sources/SCHWEIKERT-CRABEL-CME-XAUXAG-WR2-CLV-RV-20260912]]"]
concepts: ["[[concepts/gold-silver-relative-value]]", "[[concepts/completed-week-range-expansion]]", "[[concepts/market-neutral-basket]]"]
indicators: ["[[indicators/completed-week-ratio-close-range]]", "[[indicators/completed-week-ratio-close-location]]", "[[indicators/atr-risk-stop]]"]
strategy_type_flags: [commodity, precious-metals, gold-silver-relative-value, market-neutral-basket, weekly-range-expansion, close-location, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41448_XAU_XAG_WR2_CLV_RV_D1
symbol: QM5_41448_XAU_XAG_WR2_CLV_RV_D1
host_symbol: XAUUSD.DWX
companion_symbol: XAGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [414480000, 414480001]
period: D1
timeframe: D1
direction: symmetric_long_short
expected_trade_frequency: "Approximately eight to sixteen completed paired packages per full post-warm-up year; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_CROSS_SOURCE_AND_WEEKLY_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: D1; input-bound synchronized XAU/XAG labels; two immediately completed consecutive weeks with 3-5 sessions each; log-ratio close range; newest range strictly wider than prior; newest CLV strictly above 0.75 or below 0.25; contrarian equal-notional package; 45 D1 bars; 180-minute grace; aggregate fixed risk; 3.5*ATR(20,D1) frozen stops; 20% notional mismatch cap; 10-day stale repair; XAU/XAG spread ceilings 1500/500."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q02_READY
q01_status: PASS
q01_compile_work_item: d487948f-d410-4722-999b-c8f1282984b2
q01_build_report: D:/QM/reports/work_items/d487948f-d410-4722-999b-c8f1282984b2/QM5_41448/COMPILE_EA/compile_evidence.json
q02_status: NOT_ENQUEUED
force_build: true
review_focus: "Falsify a two-week XAU/XAG ratio-close range-expansion and outer-quartile reversion basket outside the certified directional XAU/SP500/NDX/XNG book. Verify synchronized ratio ranges, strict inequalities, contrarian package, durable weekly attempt, aggregate fixed risk, atomic repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [input_bound_xau_xag_carrier, immediately_preceding_two_monday_anchors, synchronized_completed_d1_closes, bounded_week_session_counts, positive_ratio_close_ranges, strict_newest_range_expansion, strict_outer_quartile_ratio_close, contrarian_package_direction, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 complete peer-reviewed, exchange, and governed reputable lineage with explicit translation risk; R2 exact mechanical two-week ratio WR2/CLV reversion basket; R3 registered XAU/XAG D1; R4 deterministic non-ML; no exact duplicate after canonical and manual family review."
---

# QM5_41448 XAU/XAG Weekly WR2 CLV Reversion

## Hypothesis

When the synchronized gold/silver log-ratio close range expands from one completed broker week to
the next and the newest week settles in an outer quartile, the relative move may mean-revert over
the following week. Fade the settlement extreme through an opposed XAU/XAG package. Equal
notional is a construction target, not proof of neutrality; Q09 alone may establish realized
portfolio correlation.

## Source Traceability And Non-Duplicate Decision

The approved complete-read packet is
`strategy-seeds/sources/SCHWEIKERT-CRABEL-CME-XAUXAG-WR2-CLV-RV-20260912/source.md`.
Schweikert and CME supply gold/silver relation and ratio-spread lineage; the governed Crabel
record supplies range-state and completed-week construction lineage. None validates this weekly
ratio-range expansion and outer-quartile fade.

The canonical scan found no exact identity. `QM5_41079` is a one-week newest-close rank with no
range comparison; `QM5_41060` uses seven weekly ranges and a later breakout; `QM5_41088` compares
the two legs' individual close locations; `QM5_41417/41418` use weekly endpoint-return signs; and
`QM5_41440/41442` are directional seasonal WTI systems. The paired carrier, two synchronized
weeks, ratio-close WR2 state, ratio CLV threshold, contrarian side, and one-week hold are jointly
load-bearing.

## Rules

The numbered execution sections are the complete locked contract.

## 4. Entry Rules

1. Run only from the setfile-bound `XAUUSD.DWX` D1 host with input-bound `XAGUSD.DWX` companion,
   EA 41448, slots zero/one, registered magics, and fixed-risk backtest mode.
2. At the first tradable D1 bar of a normalized Monday-anchored week, persist the attempt before
   history, signal, news, spread, quote, ATR, sizing, margin, or order gates. Never retry.
3. Enter only within 180 elapsed minutes and reconstruct exactly the two immediately completed
   consecutive normalized weeks, each with three through five valid synchronized sessions.
4. For every session compute `s=ln(XAU_close)-ln(XAG_close)`. For each week compute
   `R=max(s)-min(s)`. Require positive finite ranges and newest `R` strictly greater than prior
   `R`; equality or contraction is flat.
5. Compute newest-week `CLV=(s_final-min(s))/R`. If `CLV>0.75`, SELL XAU and BUY XAG. If
   `CLV<0.25`, BUY XAU and SELL XAG. Equality or an interior value is flat.
6. Require allowed spreads, executable quotes, completed ATR(20,D1) on both legs, valid metadata,
   independent frozen `3.5*ATR` hard stops, and an equal-notional package under one aggregate
   fixed-risk budget with at most 20% notional mismatch.

## 5. Exit Rules

Close both legs on the first processed tick in the next normalized broker week. Ten elapsed days
is stale repair. Broker hard stops and the framework kill switch remain authoritative. There is
no target, signal-flip exit, Friday exit, or intentional carry beyond the next week.

## 6. Filters (No-Trade Module)

Fail closed on wrong host/period/identity/slot/risk mode, unlocked `strategy_*` configuration,
late restart, consumed week, malformed or asynchronous packages, nonexpanding range, interior
CLV, spread, quote, ATR, stop, sizing, or order state. Framework RNG, news, and Friday-close
inputs remain configurable and are never equality-pinned. Stress rejection is checked only for
finiteness and inclusive `0..1` range.

## 7. Trade Management Rules

Immediately flatten orphaned, duplicate, wrong-symbol, wrong-magic, same-direction, missing-stop,
take-profit-bearing, future-dated, or invalid-volume exposure, and packages above the 20% notional
mismatch cap. No trail, break-even, partial close, scale-in, pyramid, grid, martingale, hedge,
reversal, or re-entry is allowed.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| param | default |
|---|---:|
| `strategy_host_symbol` | `XAUUSD.DWX` via setfile |
| `strategy_companion_symbol` | `XAGUSD.DWX` via setfile |
| `strategy_history_bars_d1` | 45 |
| `strategy_required_weeks` | 2 |
| `strategy_min_sessions_per_week` | 3 |
| `strategy_max_sessions_per_week` | 5 |
| `strategy_clv_lower` | 0.25 |
| `strategy_clv_upper` | 0.75 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_notional_ratio` | 1.0 |
| `strategy_max_notional_mismatch_pct` | 20.0 |
| `strategy_max_hold_days` | 10 |
| `strategy_host_max_spread_points` | 1500 |
| `strategy_companion_max_spread_points` | 500 |
| `strategy_deviation_points` | 20 |

Changing the carrier, synchronization, weekly construction, range comparison, CLV thresholds,
direction, stop, hold, spread, or retry contract requires a new identity.

## Source-Defined Rules

Schweikert and CME supply structural gold/silver relative-value lineage. Governed Crabel records
supply broad range-state lineage. They do not supply this exact weekly conjunction or thresholds.

## QM Interpretations

Monday anchors, two completed weeks, ratio-close rather than per-leg ranges, strict expansion,
outer-quartile thresholds, contrarian side, equal-notional target, one-week hold, retry semantics,
and every numeric threshold are QM choices.

## Framework Execution Overrides

Q02 keeps both news axes off and Friday close disabled so the weekly package lifecycle is intact.
Those framework inputs and RNG seed remain configurable and unpinned. Stress rejection receives
only range/finiteness validation.

## Exit Precedence

1. framework kill switch and broker hard stops;
2. malformed or mismatched package repair;
3. first processed tick of the next normalized week;
4. ten-calendar-day stale repair.

## Runtime Data Dependencies

Configured-symbol D1 OHLC/timestamps, broker clock, quotes, symbol properties, positions, deal
history, ATR, and terminal-global attempt state only. No futures curve, inventory, volume,
open-interest, file, API, optimizer, trained output, or portfolio state.

## Risk

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`. Relative-price breaks,
CFD roll/basis and financing, synchronization, paired costs, minimum-lot mismatch, stop slippage,
sparse samples, and overlap with the directional XAU sleeve can dominate. Q02 owns economics;
unchanged Q09 alone owns realized portfolio correlation.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| host, identity, risk, locked `strategy_*`; framework inputs unpinned | No Trade | `Strategy_NoTradeFilter` |
| week clock, synchronization, ratio ranges, CLV, attempt, spread, ATR, pair | Trade Entry | `Strategy_EntrySignal` and helpers |
| malformed package, next-week, and stale closure | Trade Management | `Strategy_ManageOpenPosition` |
| framework reason mapping and broker hard stops | Trade Close | `Strategy_ExitSignal` and framework helper |

## Falsification And Requalification

Q01 must verify year-boundary adjacency, synchronized 3-5-session weeks, current-week exclusion,
positive ranges, strict expansion and tie, strict upper/lower CLV boundaries, both contrarian
packages, interior flat state, durable attempt, aggregate fixed-risk stops, atomic repair,
next-week exit, card lint, resolver, PACER audit, reference tests, and strict compile/build checks.
Q02 retires on zero packages, fewer than five completed packages in a full scored year,
nonpositive governed economics, or contract mismatch. No weak result may be tuned into survival.

## Safety Boundary

Authorized: deterministic allocation, branch-only non-live Q01 build, one fixed-risk logical
basket set, and one paced Q02 enqueue below the CPU ceiling. Forbidden: manual backtests,
optimization, portfolio-gate edits or admission, correlation waivers, deploy/live manifests,
`T_Live`, AutoTrading, terminal control, or live use.

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-12 | APPROVED_SOURCE | source decision above |
| G0 Research Intake | 2026-09-12 | APPROVED | G0 decision above |
| Q01 Build Validation | 2026-09-12 | PASS | governed T2 compile; zero compiler errors/warnings; strict build check PASS; 6 reference tests; PACER audit zero hits |
| Q02 Baseline Screening | - | NOT_ENQUEUED | only after Q01 PASS and deterministic intake guards |
