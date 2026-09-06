---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XTIXNG-WCLVDIV-RV-20260906_S01
variant_id: AI-CODEX-XTIXNG-WCLVDIV-RV-20260906_S01
source_id: AI-CODEX-XTIXNG-WCLVDIV-RV-20260906
ea_id: QM5_41364
slug: xtixng-wclv-div-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41364_xtixng-wclv-div-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-06
created_by: Research+Development
last_updated: 2026-09-06
g0_status: APPROVED
g0_decision: decisions/2026-09-06_qm5_41364_xtixng_weekly_close_location_divergence_reversion_g0.md
source_approval: decisions/2026-09-06_xtixng_weekly_close_location_divergence_reversion_source_approval.md
source_authors: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons"
source_citation: "Villar and Joutz (2006), The Relationship Between Crude Oil and Natural Gas Prices, U.S. EIA; Ramberg and Parsons (2012), The Weak Tie Between Natural Gas and Oil Prices, The Energy Journal 33(2), DOI 10.5547/01956574.33.2.2; bounded governed weekly close-location mechanization."
source_citations:
  - type: government_and_peer_reviewed_relationship_source
    citation: "Villar, J. A., and Joutz, F. L. (2006), U.S. EIA; Ramberg, D. J., and Parsons, J. E. (2012), The Weak Tie Between Natural Gas and Oil Prices, The Energy Journal 33(2), 13-35."
    location: "complete-read packet strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md; DOI 10.5547/01956574.33.2.2"
    quality_tier: A_government_and_peer_reviewed
    role: physical_economic_linkage_and_binding_instability
  - type: governed_composite_source
    citation: "OpenAI Codex (2026). XTI/XNG completed-week opposite close-location reversion."
    location: strategy-seeds/sources/AI-CODEX-XTIXNG-WCLVDIV-RV-20260906/source.md
    quality_tier: governed_source
    role: exact_arithmetic_risk_and_lifecycle
strategy_mechanic: synchronized-completed-week-per-leg-close-location-strict-opposite-outer-terciles-fade-high-location-leg-one-week-equal-notional-xti-xng-basket
sources:
  - "[[sources/AI-CODEX-XTIXNG-WCLVDIV-RV-20260906]]"
concepts:
  - "[[concepts/oil-gas-relative-value]]"
  - "[[concepts/completed-week-auction-location-divergence]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-week-close-location]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, oil-gas-relative-value, market-neutral-style, completed-week-close-location-divergence, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil, natural_gas]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41364_XTI_XNG_WCLVDIV_RV_D1
symbol: QM5_41364_XTI_XNG_WCLVDIV_RV_D1
host_symbol: XTIUSD.DWX
companion_symbol: XNGUSD.DWX
symbol_slot: 0
symbol_slots: [0, 1]
magic_numbers: [413640000, 413640001]
period: D1
timeframe: D1
execution_timeframe: D1
signal_timeframe: D1
direction: symmetric_opposed_leg
expected_trade_frequency: "Approximately six to twelve completed paired packages per full post-warm-up year after synchronized completed-week aggregation and strict opposite outer-tercile close locations; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_RULE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
parameters_to_test: "Locked Q02 baseline only: 30 D1 history bars; 3-5 synchronized completed-week sessions; independent CLV; strict 1/3 and 2/3 outer-tercile boundaries; 180-minute entry grace; 3.5*ATR(20,D1) per-leg frozen stops; equal target notionals; 20% mismatch ceiling; 10-day stale exit; 1500/3000-point positive-spread ceilings."
risk_fixed_backtest: 1000
risk_percent_backtest: 0
portfolio_weight_backtest: 1
news_temporal_mode: QM_NEWS_TEMPORAL_OFF
news_compliance_profile: QM_NEWS_COMPLIANCE_NONE
friday_close_enabled: false
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED
force_build: true
review_focus: "Falsify a completed-week XTI/XNG per-leg auction-location divergence fade outside the certified XAU/SP500/NDX/XNG book. Verify synchronized prior-week OHLC, independent CLVs, strict opposite outer terciles, contrarian sides, durable weekly attempt, aggregate fixed risk, atomic basket repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xti_xng_carrier, immediately_preceding_monday_anchor, synchronized_completed_d1_ohlc, three_to_five_week_sessions, independent_per_leg_close_location, strict_opposite_outer_terciles, contrarian_high_location_direction, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-09-06 and the durable source/G0 decisions authorize one new energy sleeve. R1 uses complete U.S. government and peer-reviewed oil/gas evidence while disclosing the untested CLV translation; R2 locks all state, side, risk, and lifecycle rules; R3 uses registered native XTI/XNG D1 data; R4 uses deterministic native arithmetic only. Canonical dedup found one same-mechanic precious-metals sibling, manually resolved as a distinct carrier and return stream rather than an exact duplicate."
---

# QM5_41364 XTI/XNG Weekly Close-Location Divergence Reversion

## Hypothesis

Oil and natural gas retain physical and economic links but respond differently
to regional storage, transport, weather, refining, and production shocks. When
they finish the same completed broker week at opposite extremes of their own
weekly auction ranges, fading the high-location leg against the low-location
leg for one week may capture relative re-convergence without taking a single
outright energy direction.

Opposed equal-notional legs are an execution target, not proof of beta, market,
factor, volatility, or portfolio neutrality. Q02 owns density and economics;
unchanged Q09 alone may establish realized book correlation.

## Source Traceability And Claim Boundary

The approved source is
`strategy-seeds/sources/AI-CODEX-XTIXNG-WCLVDIV-RV-20260906/source.md`,
authorized before extraction in
`decisions/2026-09-06_xtixng_weekly_close_location_divergence_reversion_source_approval.md`
at commit `9170cf4d10`.

Villar/Joutz and Ramberg/Parsons support an oil/gas relative-value carrier and
make its weak, shifting relationship binding adverse evidence. No source tests
the CLV conjunction or transfers a return, density, cost, CFD-equivalence,
neutrality, or correlation claim.

## Non-Duplicate Decision

The corrected-root checker scanned 4,844 registry rows and 1,457 cards. It
found no exact identity and one expected fuzzy match,
`QM5_41088_xauxag-wclv-div-rv`. That sibling applies the same transparent
statistic to gold and silver; this candidate owns the oil/gas physical thesis,
energy contracts, cost surface, and realized return stream. No result or
parameter was imported.

Existing XTI/XNG systems use ratio levels, fitted residuals, fixed-window
returns, robust monthly statistics, weekdays/calendars, common shocks, flow
decomposition, or weekly path changes. None classifies both legs independently
inside their completed-week ranges. The carrier, synchronized OHLC package,
strict opposite outer-tercile state, contrarian side, weekly attempt, aggregate
risk, and next-week exit are jointly load-bearing. This is an identity ruling,
not a correlation claim.

## Markets, Timeframe, And Cadence

- Host `XTIUSD.DWX`, D1, slot 0; companion `XNGUSD.DWX`, D1, slot 1.
- Logical symbol `QM5_41364_XTI_XNG_WCLVDIV_RV_D1`.
- Decide once within 180 minutes of the first synchronized tradable D1 bar in
  a new Monday-anchored broker week.
- Form the signal from the exact immediately preceding completed broker week.
- Hold until the first later broker week, with a ten-day stale repair.
- Expected cadence six to twelve packages/year; retire below five.

## Formula

For each leg `j` in `{XTI,XNG}`:

```text
range_j = week_high_j - week_low_j
clv_j   = (week_close_j - week_low_j) / range_j

clv_XTI > 2/3 and clv_XNG < 1/3 => SELL XTI, BUY XNG
clv_XTI < 1/3 and clv_XNG > 2/3 => BUY XTI, SELL XNG
otherwise                         => FLAT
```

Every endpoint is completed before the decision week. Equality, invalid range,
interior state, or asynchronous/missing history is flat. Magnitude never
changes side or risk.

## Rules

The following entry, exit, filter, management, and risk clauses are the entire
locked baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact XTI D1 host bar under EA 41364, slot zero.
2. Repair malformed, orphaned, duplicated, same-side, stopless, notional-
   invalid, later-week, or stale owned exposure before entry-only gates.
3. Require synchronized current XTI/XNG bars and the first tradable bar of a
   new broker week. Reject attachment later than 180 elapsed minutes.
4. Persist the week attempt before history, signal, spread, quote, ATR, sizing,
   news, margin, or order gates. Never retry that week.
5. From a bounded 30-bar buffer, collect every synchronized OHLC pair in the
   immediately preceding Monday-anchored week. Require three to five unique
   sessions, identical timestamps, and no current-week observation.
6. Aggregate per-leg high, low, and chronological final close. Require finite
   positive prices and strict positive ranges; compute each CLV independently.
7. Qualify only the two strict opposite outer-tercile states in the formula.
8. Sell the upper-location leg and buy the lower-location leg.
9. Require side-specific quotes and positive spreads no wider than 1,500 XTI
   points and 3,000 XNG points. A modeled zero `.DWX` spread is valid.
10. Attach frozen `3.5*ATR(20,D1)` hard stops. Size both legs so combined
    normalized stop risk cannot exceed one `RISK_FIXED=1000` budget.
11. Target one-to-one absolute entry notional, round down only, and reject
    mismatch above 20 percent. Use no take-profit.
12. Submit both legs once. If either fails or package composition is invalid,
    flatten all owned exposure; no single-leg fallback exists.

## 5. Exit Rules

- Broker hard stops and framework kill-switch closure are authoritative.
- Immediately flatten orphan, duplicate, same-side, wrong-symbol, wrong-magic,
  stopless, invalid-volume, or notional-invalid exposure.
- Close both legs on the first tick whose broker-week anchor is later than the
  package entry anchor, or after ten elapsed calendar days.
- No Friday close, target, signal flip, trail, break-even, partial, scale-in,
  pyramid, grid, martingale, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

Exact identity, symbols, D1, magics, fixed risk, both news axes OFF, Friday
close OFF, synchronized bars, completed-week membership, finite positive OHLC,
strict CLV state, durable attempt, spreads, quotes, ATR, stop geometry, and
notional match all fail closed. Runtime may not read external files, APIs,
futures chains, inventory, volume, open interest, forecasts, fitted models,
optimizer output, portfolio state, or trained artifacts.

## 7. Trade Management Rules

Own exactly one XTI leg under magic `413640000` and one opposite XNG leg under
magic `413640001`, or flatten all owned exposure. Persist the last attempted
week across restart. Preserve original hard stops and the atomic package. Do
not retry, add, reverse, trail, partially close, or hold beyond the lifecycle.

## Parameters To Test

Q02 has one locked baseline: 30-bar history buffer; 3-5 sessions; strict
`1/3` and `2/3` boundaries; 180-minute grace; `3.5*ATR(20,D1)` stops; equal
notionals; 20% mismatch ceiling; 10-day stale guard; and 1,500/3,000-point
positive-spread ceilings. No search or post-result tuning is authorized.

## Author Claims

The cited sources document physical/economic oil-gas linkage and binding
instability. They do not claim that this conjunction works or that the package
is neutral, profitable, or decorrelated.

## Risk

Risk is high: persistent oil/gas decoupling, regional gas shocks, energy gaps,
one-leg fills, lot-step mismatch, continuous-CFD basis and financing, spread,
low density, and overlap with the incumbent XNG sleeve can dominate. Each leg
has a frozen hard stop and the package shares one fixed-dollar budget.

## Strategy Allowability Check

- [x] R1 passes with explicit rule and CFD translation risk.
- [x] R2 passes: all endpoints, states, sides, attempt, risk, and lifecycle are fixed.
- [x] R3 passes for registered native XTI/XNG D1 data with synchronization risk.
- [x] R4 passes: deterministic native arithmetic; no banned signal or ML logic.
- [x] Dedup is resolved as a distinct energy-carrier port, not an exact identity.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| week clock, synchronization, CLV, state, attempt, costs, ATR | Trade Entry | deterministic helpers and basket order helper |
| orphan/notional, later-week, stale repair | Trade Management | atomic package lifecycle helper |
| framework reason mapping | Trade Close | no separate signal exit |
| kill switch, ownership, magics, aggregate risk | Framework No-Trade | standard framework plus foreign magic |
| news OFF | News hooks | both axes locked OFF |

## Validation Plan

Q01 must prove week anchors across month/year boundaries, synchronized OHLC,
3-5 session acceptance, strict boundary and side fixtures, no current-week
leakage, durable attempts, aggregate-risk sizing, equal-notional rounding,
atomic repair, next-week/stale exits, card lint, strict compile, set schema,
basket manifest, resolver identity, and static artifact validation.

Q02 alone measures density and economics. Q09 alone may establish correlation.

## Failure Conditions And Safety Boundary

Retire on zero packages, fewer than five packages in any full post-warm-up
year, nonpositive governed economics, formula or leakage defect, invalid risk,
missing stop, broken atomicity, wrong lifecycle, or nondeterminism. No tuning.

Authorized: deterministic allocation, branch-only non-live build, reference
tests, strict Q01, and one paced fixed-risk logical Q02 enqueue below the CPU
ceiling. Forbidden: manual backtests, terminal control, live/demo/shadow/stress/
optimization presets, portfolio-gate edits, correlation waivers, portfolio
admission, deploy/live manifests, `T_Live`, AutoTrading, or live use.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-09-06 | initial XTI/XNG weekly close-location divergence card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Source Approval | 2026-09-06 | APPROVED_SOURCE | `decisions/2026-09-06_xtixng_weekly_close_location_divergence_reversion_source_approval.md` |
| G0 Research Intake | 2026-09-06 | APPROVED | `decisions/2026-09-06_qm5_41364_xtixng_weekly_close_location_divergence_reversion_g0.md` |
| Q01 Build Validation | TBD | PENDING | TBD |
| Q02 Baseline Screening | TBD | NOT_ENQUEUED | TBD |
