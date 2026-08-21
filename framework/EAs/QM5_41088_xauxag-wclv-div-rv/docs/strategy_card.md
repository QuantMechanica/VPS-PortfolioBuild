---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026_S01
variant_id: SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026_S01
source_id: SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026
ea_id: QM5_41088
slug: xauxag-wclv-div-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41088_xauxag-wclv-div-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-21
created_by: Research+Development
last_updated: 2026-08-21
g0_status: APPROVED
g0_decision: decisions/2026-08-21_qm5_41088_xauxag_weekly_close_location_divergence_reversion_g0.md
source_approval: decisions/2026-08-21_xauxag_weekly_close_location_divergence_reversion_source_approval.md
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; supporting carrier definition from CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete-read governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md; bounded extraction strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026/source.md"
    quality_tier: A
    role: primary_state_dependent_long_run_relation
  - type: exchange_education
    citation: "CME Group, Gold & Silver Ratio Spread."
    location: "Governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: A
    role: supporting_intermarket_carrier_definition
strategy_mechanic: synchronized-completed-week-per-leg-close-location-strict-opposite-outer-terciles-fade-high-location-leg-one-week-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/completed-week-auction-location-divergence]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-week-close-location]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, gold-silver-ratio, relative-value-basket, completed-week-close-location-divergence, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41088_XAU_XAG_WCLVDIV_RV_D1
symbol: QM5_41088_XAU_XAG_WCLVDIV_RV_D1
host_symbol: XAUUSD.DWX
companion_symbol: XAGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [410880000, 410880001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately six to twelve completed paired packages per full post-warm-up year after exact synchronized completed-week aggregation, strict opposite outer-tercile close locations, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_CLOSE_LOCATION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: NOT_ENQUEUED
q01_build_report: D:/QM/reports/framework/21/build_check_20260821_095406.json
q01_p1_evidence: D:/QM/reports/pipeline/QM5_41088/P1/P1_QM5_41088_result.json
review_focus: "Falsify a completed-week gold/silver per-leg auction-location divergence fade outside the certified XAU/SP500/NDX/XNG book. Verify exact prior-week membership, synchronized three-to-five-session OHLC aggregation, independent CLV orientation, strict opposite outer terciles, contrarian high-location sides, durable weekly attempt, aggregate fixed risk, atomic basket repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xau_xag_carrier, immediately_preceding_monday_anchor, synchronized_completed_d1_ohlc, three_to_five_week_sessions, independent_per_leg_close_location, strict_opposite_outer_terciles, contrarian_high_location_direction, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses one bounded child source with named peer-reviewed DOI and official exchange lineages while disclosing the completed-week opposite-leg CLV fade as an untested QM translation; R2 locks synchronized week membership, OHLC aggregation, independent CLV orientation, strict tercile boundaries, contrarian sides, durable attempt, aggregate fixed risk, equal notional, hard stops, spreads, and next-week lifecycle; R3 uses registered native XAU/XAG D1 histories with synchronization and CFD-basis risks explicit and requires active slots 0/1 before build; R4 is deterministic timestamp, OHLC, division, comparison, ATR, quote, position, deal, and terminal-state arithmetic without a banned signal, trained output, external feed, grid, or martingale; canonical dedup and manual family review found no exact identity."
---

# QM5_41088 XAU/XAG Weekly Close-Location Divergence Reversion

## Hypothesis

When gold and silver finish the same completed broker week at opposite extremes
of their own weekly auction ranges, the intermetal move reflects a location
disagreement rather than a shared precious-metal close. Selling the upper-
location metal and buying the lower-location metal for the next broker week
may capture re-convergence in their state-dependent long-run relation without
taking one outright directional signal.

The candidate is one logical two-leg relative-value package intended to add a
different return driver outside the certified XAU/SP500/NDX/XNG book. Equal
notional and opposite legs are execution targets, not proof of beta, factor,
market, volatility, or portfolio neutrality. Q02 owns density and economics;
unchanged Q09 alone may establish realized book correlation.

## Source Traceability And Claim Boundary

The approved source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026/source.md`,
authorized before card extraction in
`decisions/2026-08-21_xauxag_weekly_close_location_divergence_reversion_source_approval.md`
at commit `2b66172a6`.

Schweikert supplies named peer-reviewed evidence for a potentially state-
dependent gold/silver relationship. CME defines the gold/silver ratio and
supports treating the instruments as one intermarket spread carrier. Neither
source tests opposite per-leg weekly close locations, their contrarian side, a
continuous-CFD package, equal-notional sizing, fixed cash risk, ATR stops, or
a one-week hold.

No source return, profit factor, risk-adjusted return, drawdown, trade count,
transaction cost, hedge ratio, CLV boundary, CFD equivalence, neutrality, or
portfolio-correlation statistic transfers. Every implementation choice below
is a pre-result QM falsification choice.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,577 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual semantic
review fixes the boundaries:

- `QM5_41083_xauxag-wlegdiv-rv` requires opposite signed completed-week leg
  returns. This card ignores week open and return sign and classifies each
  final close inside its own completed-week high-low range.
- `QM5_41079_xauxag-wclose-extreme-rv` ranks the final synchronized ratio close
  against earlier ratio closes in the same week. This card ranks no ratio
  level and uses one independently normalized auction location per metal.
- `QM5_41086_xauxag-commonshock-rv` requires same-sign weekly leg returns and
  strict magnitude dispersion. This card uses neither return sign nor return
  magnitude.
- `QM5_41030`, `QM5_41040`, and `QM5_41057` classify relative session and
  overnight flow. This card does not decompose open/close flow.
- `QM5_41060_xauxag-week-nr7-brk` ranks completed relative ranges and waits for
  a current-week breakout. This card enters a first-bar fade from one
  completed-week location state.
- `QM5_41062_xauxag-wgap-fade` uses opposed weekend gaps rather than completed-
  week auction locations.
- `QM5_12533` supplies the validated logical-basket manifest/order recipe but
  its signal is an EURJPY/GBPJPY cointegration spread.
- `QM5_12567_cum-rsi2-commodity` is a single-symbol long-only two-day XNG
  oscillator pullback and has no intermetal, weekly, or paired logic.

The exact XAU/XAG carrier, synchronized immediately completed week, strict
opposite per-leg outer-tercile close locations, contrarian high-location side,
durable weekly attempt, equal-notional aggregate-risk package, and next-week
exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_WEEK_OPPOSITE_LEG_CLOSE_LOCATION_TERCILE_REVERSION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host: `XAUUSD.DWX`, D1, slot 0, planned magic `410880000`.
- Exact companion: `XAGUSD.DWX`, D1, slot 1, planned magic `410880001`.
- Logical symbol: `QM5_41088_XAU_XAG_WCLVDIV_RV_D1`.
- Formation: every synchronized D1 OHLC pair in the immediately preceding
  completed Monday-anchored broker week.
- Decision: first tradable bar of a new Monday-anchored broker week, within
  180 elapsed raw-session minutes.
- Signal: one leg's final close is strictly above two-thirds of its own weekly
  range while the other is strictly below one-third; fade the high-location
  leg.
- Ordinary exit: first tick whose broker Monday anchor is later than the
  package-open anchor.
- Expected cadence: six to twelve completed packages/year; retire below five.
- Q02 risk: aggregate-package `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

For each leg `j` in `{gold,silver}`, aggregate the exact same completed broker
week and define:

```text
range_j = week_high_j - week_low_j
clv_j   = (week_close_j - week_low_j) / range_j

clv_gold > 2/3 and clv_silver < 1/3
    => SELL XAU, BUY XAG

clv_gold < 1/3 and clv_silver > 2/3
    => BUY XAU, SELL XAG

otherwise
    => FLAT
```

All OHLC inputs complete before the decision week begins. The current D1 open,
high, low, or close never enters the calculation. Equality at either boundary,
zero or invalid range, or an interior state is flat. CLV distance never changes
signal or risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XAUUSD.DWX` D1 bar under EA 41088 and
   host magic slot zero.
2. Repair malformed, orphaned, duplicated, same-side, stopless, notional-
   invalid, later-week, or stale owned exposure before entry-only gates.
3. Require exact host D1 and companion D1 timestamps. Derive the current
   Monday anchor from broker time and prove the current bar is the first
   tradable D1 bar carrying that new anchor. Reject attachment later than 180
   elapsed minutes after the raw host bar open.
4. Persist the current Monday anchor attempt before history, signal, spread,
   quote, ATR, sizing, news, or order gates. Never retry that week.
5. Within a fixed 30-bar buffer, collect every positive finite synchronized
   OHLC pair belonging to the immediately preceding Monday anchor. Require
   exactly three to five pairs, identical timestamps across legs, unique
   increasing timestamps, and no pair from another anchor.
6. For each leg aggregate the maximum high, minimum low, and chronologically
   final close. Require finite positive values, strict positive ranges, and a
   finite CLV. Compute each CLV independently.
7. Require strict gold-above-two-thirds with silver-below-one-third, or strict
   gold-below-one-third with silver-above-two-thirds. Equality, an interior
   location, invalid arithmetic, missing session, or more than five sessions
   remains flat.
8. SELL the upper-location leg and BUY the lower-location leg. CLV distance
   never changes eligibility, direction, or risk.
9. Require no owned exposure, no same-magic entry deal already recorded in the
   current broker week, executable side-specific quotes, and no genuinely
   positive spread wider than 1,500 XAU points or 500 XAG points. Modeled zero
   `.DWX` spread is valid.
10. Require valid completed-bar `ATR(20,D1)` for both legs and attach one frozen
    hard stop at `3.5*ATR` on each. Size the package so combined normalized stop
    risk cannot exceed the single `RISK_FIXED=1000` budget.
11. Target one-to-one absolute entry notional. Round down only and reject a
    resulting mismatch above 20 percent. Use no take-profit.
12. Submit the two market legs once. If either leg fails or the resulting
    composition/notional contract is invalid, immediately flatten all owned
    exposure. No pending order, retry, one-leg fallback, scale-in, grid,
    martingale, pyramid, hedge overlay, or second entry exists.

## 5. Exit Rules

1. Broker hard stops and framework kill-switch closure remain authoritative.
2. Immediately flatten an orphan, duplicate, same-side, wrong-symbol, wrong-
   magic, missing-stop, invalid-volume, or notional-invalid package.
3. Close both legs on the first tick whose broker Monday anchor is later than
   the package-open Monday anchor.
4. Close after ten elapsed calendar days as a final stale guard.
5. No Friday close, target, fitted-mean exit, signal reversal, trailing stop,
   break-even move, partial exit, discretionary close, or intentional hold
   beyond the next broker week is authorized.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41088, slot zero, and both governed magics.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes, legacy news mode, and Friday close are OFF for Q02;
  lifecycle repair is never delayed by an entry-only gate.
- First-week-bar clock, exact prior anchor, synchronized timestamps, three-to-
  five session count, unique OHLC pairs, positive finite prices, strict
  positive ranges, strict opposite outer-tercile CLVs, durable attempt, side-
  specific trade mode, spread, quote, ATR, sizing, stop geometry, and notional
  match all fail closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, rolling center, fitted hedge ratio, or
  manual signal is read at runtime.

## 7. Trade Management Rules

- Own exactly one `XAUUSD.DWX` position under active magic `410880000` and one
  opposite-side `XAGUSD.DWX` position under active magic `410880001`.
- Persist the last attempted Monday anchor across restart.
- Manage malformed, later-week, stale, and kill-switch exits on every tick
  before entry evaluation.
- Freeze both original hard stops; never widen, trail, or remove them.
- Do not retry, add, pyramid, grid, martingale, partially close, add a third
  hedge, or reverse inside the week.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_history_bars_d1` | 30 | bounded prior-week buffer |
| `strategy_min_week_sessions` | 3 | holiday-week lower bound |
| `strategy_max_week_sessions` | 5 | broker-week upper bound |
| `strategy_clv_lower` | `0.333333333333` | strict lower-tercile boundary |
| `strategy_clv_upper` | `0.666666666667` | strict upper-tercile boundary |
| `strategy_entry_grace_minutes` | 180 | first-week-bar window |
| `strategy_atr_period_d1` | 20 | completed-bar per-leg range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal absolute notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | lot-step mismatch ceiling |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_xau_max_spread_points` | 1500 | XAU cost guard |
| `strategy_xag_max_spread_points` | 500 | XAG cost guard |
| `strategy_deviation_points` | 20 | bounded market-order deviation |
| `qm_friday_close_enabled` | false | full-week identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive value |

## Source-Defined Rules

Schweikert supplies state-dependent gold/silver relationship lineage. CME
supplies the gold/silver ratio definition and relative-value carrier. Neither
source supplies independent weekly CLVs, tercile boundaries, or a one-week
fade.

## QM Interpretations

`SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026_S01` fixes the exact prior week,
synchronized per-leg OHLC aggregation, strict independent outer-tercile CLVs,
contrarian sides, continuous-CFD clock, durable attempt, equal-notional
aggregate risk, spread caps, stops, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. The companion magic must be registered as a foreign
owned magic before build. No live execution override exists.

## Exit Precedence

1. Broker hard stops and framework kill switch.
2. Malformed or unsafe owned-package repair.
3. Later broker-week closure.
4. Ten-calendar-day stale repair.

## Runtime Data Dependencies

Exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX` native D1 timestamps and OHLC,
broker time, symbol metadata, quotes, completed-bar ATR, framework position/
deal state, and persistent terminal global-variable attempt state. No finite
external dataset or calendar exists.

## Risk

- Backtest only: aggregate-package `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data on each leg.
- Combined normalized stop risk may not exceed one fixed-risk budget.
- No target and no signal-strength sizing.
- Major risks are non-convergence, persistent macro divergence, one-leg fills,
  stop-risk asymmetry, lot-step notional mismatch, gold/silver beta drift,
  week-end gaps, continuous-CFD basis, financing, spread, density below the
  floor, source translation, and realized overlap with the XAU book.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, wrong or
asynchronous prior-week timestamps, invalid session count, current-week
leakage, accepting equality or an interior CLV, wrong contrarian side,
duplicate weekly attempt, unbounded combined risk, missing stops, broken
atomicity, or nondeterminism.

Requalification requires a new OWNER-approved card version before moving a
tercile boundary, accepting a same-side or interior state, changing direction
or hold, changing the history or session bounds, fitting a center or hedge
ratio, or adding a return, volatility, volume, calendar, external-data, or
prior-result gate. No post-result parameter salvage is authorized.

## Framework Alignment

| Card rule | V5 owner | Implementation target |
|---|---|---|
| exact carrier, timeframe, input, and week-anchor lock | No-Trade | `Strategy_NoTradeFilter` and `OnInit` |
| synchronized prior-week OHLC, independent CLVs, strict terciles, sides, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus package helper |
| next-week and survivor repair | Trade Close | `Strategy_ExitSignal` plus package helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; first-week-bar
and 180-minute clock; Monday anchors across year boundaries; exact completed
week with three-to-five synchronized sessions; correct high, low, and final-
close aggregation; both valid opposite-tercile directions; boundary equality,
interior, same-tercile, zero-range, asynchrony, and incomplete-week flat states;
no current-bar leakage; persistent weekly attempts; fixed-risk frozen-stop
sizing; atomic repair; next-week and stale exits; card lint; strict compile;
setfile schema; resolver identity; basket manifest; and static artifact
validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-21 | initial XAU/XAG completed-week close-location divergence reversion card | G0 | APPROVED |
| v1-build | 2026-08-21 | deterministic implementation, 10-test reference suite, strict compile/build checks, and static artifact validation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-21 | APPROVED | `decisions/2026-08-21_qm5_41088_xauxag_weekly_close_location_divergence_reversion_g0.md` |
| Q01 Build Validation | 2026-08-21 | PASS | `D:/QM/reports/framework/21/build_check_20260821_095406.json`; `D:/QM/reports/pipeline/QM5_41088/P1/P1_QM5_41088_result.json` |
| Q02 Baseline Screening | 2026-08-21 | NOT_ENQUEUED | gated by paced terminal/CPU preflight |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` logical-basket backtest setfile, and one paced target-only Q02
enqueue only below tester and CPU ceilings. It does not authorize a manual
backtest, terminal control, live/demo/shadow/stress/optimization preset,
AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio-gate change,
portfolio admission, decorrelation claim, or correlation waiver.
