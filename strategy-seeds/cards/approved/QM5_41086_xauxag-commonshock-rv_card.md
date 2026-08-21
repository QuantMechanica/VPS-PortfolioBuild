---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026_S01
variant_id: SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026_S01
source_id: SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026
ea_id: QM5_41086
slug: xauxag-commonshock-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41086_xauxag-commonshock-rv_card.md
execution_contract_status: DRAFT
created: 2026-08-21
created_by: Research+Development
last_updated: 2026-08-21
g0_status: APPROVED
g0_decision: decisions/2026-08-21_qm5_41086_xauxag_weekly_common_shock_dispersion_reversion_g0.md
source_approval: decisions/2026-08-21_xauxag_weekly_common_shock_dispersion_reversion_source_approval.md
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; supporting carrier definition from CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete-read governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md; bounded extraction strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026/source.md"
    quality_tier: A
    role: primary_state_dependent_long_run_relation
  - type: exchange_education
    citation: "CME Group, Gold & Silver Ratio Spread."
    location: "Governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: A
    role: supporting_intermarket_carrier_definition
strategy_mechanic: normalized-week-boundary-xau-xag-synchronized-completed-week-individual-log-returns-strict-same-sign-common-shock-relative-outperformer-fade-equal-notional-one-week-hold
sources:
  - "[[sources/SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/completed-week-common-direction-dispersion]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-week-individual-log-return]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, gold-silver-ratio, relative-value-basket, common-direction-dispersion, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41086_XAU_XAG_COMMONSHOCK_RV_D1
symbol: QM5_41086_XAU_XAG_COMMONSHOCK_RV_D1
host_symbol: XAUUSD.DWX
companion_symbol: XAGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [410860000, 410860001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately fifteen to thirty-five completed paired packages per full post-warm-up year after synchronized completed-week, strict same-sign individual-return, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 24
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_COMMON_SHOCK_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q00_APPROVED
q01_status: NOT_STARTED
q02_status: NOT_STARTED
review_focus: "Falsify a completed-week gold/silver same-direction dispersion fade outside the certified XAU/SP500/NDX/XNG book. Verify exact prior-two-week membership, synchronized three-to-five-session close pairs, week-end endpoint selection, strict same-sign individual returns, symmetric relative-outperformer fade, durable weekly attempt, aggregate fixed risk, atomic basket repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xau_xag_carrier, immediately_preceding_two_monday_anchors, synchronized_completed_d1_closes, three_to_five_week_sessions, exact_week_end_endpoints, strict_individual_leg_same_sign, strict_relative_return_inequality, contrarian_relative_outperformer_direction, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses one bounded child source with named peer-reviewed DOI and official exchange lineage while disclosing the completed-week same-direction fade as an untested QM translation; R2 locks synchronized consecutive weeks, endpoint selection, individual log-return orientation, strict shared sign, strict relative inequality, contrarian sides, durable attempt, aggregate fixed risk, equal notional, hard stops, spreads, and next-week lifecycle; R3 uses registered native XAU/XAG D1 histories with synchronization and CFD-basis risks explicit and requires active slots 0/1 before build; R4 is deterministic timestamp, price, logarithm, comparison, ATR, quote, position, deal, and terminal-state arithmetic without a banned signal, trained output, external feed, grid, or martingale; canonical dedup and manual family review found no exact identity."
---

# QM5_41086 XAU/XAG Weekly Common-Shock Dispersion Reversion

## Hypothesis

Gold and silver share a precious-metals factor but have different monetary,
safe-haven, and industrial sensitivities. When both metals move in the same
strict direction over one synchronized completed broker week, treat the shared
sign as a common-shock admission state. Fade the relative dispersion by
selling the metal with the larger completed return and buying the metal with
the smaller return as one equal-notional package for the following week.

The source supports testing a state-dependent gold/silver relationship and the
ratio as an intermarket spread. It does not establish that same-direction
weekly returns identify a common shock, that their dispersion reverts, or that
equal-notional CFDs are neutral. Those are falsifiable QM interpretations; no
ex-ante profitability, neutrality, or decorrelation claim is made.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026/source.md`,
approved before card extraction in
`decisions/2026-08-21_xauxag_weekly_common_shock_dispersion_reversion_source_approval.md`
at commit `ff0d62e6d`.

Schweikert documents state-dependent gold/silver cointegration evidence, and
CME defines the gold/silver ratio and intermarket spread carrier. Neither
source tests strict same-sign individual weekly returns, a symmetric relative-
outperformer fade, continuous-CFD labels, equal-notional fixed-dollar risk, or
a one-week hold. All clock, endpoint, signal, execution, and risk choices below
are declared QM interpretations. No source return, density, hedge ratio, cost,
or correlation result transfers.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,573 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review fixes
the load-bearing boundaries:

- `QM5_41031_xauxag-goldlead` is a one-D1 asymmetric gold-lead event. Gold
  alone must exceed 75 basis points and silver must remain below half of
  gold's move. This card is symmetric, weekly, threshold-free, and permits
  either leg to lead after both individual returns share a strict sign.
- `QM5_41083_xauxag-wlegdiv-rv` admits only opposite-sign individual weekly
  returns. This card admits only same-sign individual weekly returns; their
  signal state spaces are disjoint.
- `QM5_41066` and `QM5_41075` through `QM5_41078` classify multiweek paths of
  the gold-minus-silver return. This card uses one weekly return per
  individual leg and no multiweek relative-return path.
- `QM5_41057_xauxag-wflow-agree-fade` decomposes close-to-open and open-to-
  close relative flows. This card uses only final completed-week endpoints.
- `QM5_41085_xauxag-wdaybreadth-rv` counts five within-week relative-return
  signs. This card counts none and accepts synchronized three-to-five-session
  completed weeks.
- rolling ratio/residual cards estimate a center, regression, scale, score,
  or tail; this card estimates none.
- `QM5_12533` contributes only the validated logical-basket manifest/order
  recipe. `QM5_12567` is a single-symbol long-only two-day oscillator
  pullback, not a paired intermetal state.

The paired carrier, exact consecutive synchronized completed-week endpoints,
strict same-sign individual returns, symmetric relative-outperformer fade,
persistent weekly attempt, equal-notional aggregate-risk package, and next-
week exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_SAME_DIRECTION_WEEKLY_COMMON_SHOCK_RELATIVE_OUTPERFORMER_FADE_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host: exact `XAUUSD.DWX`; companion: exact `XAGUSD.DWX`.
- Logical basket: `QM5_41086_XAU_XAG_COMMONSHOCK_RV_D1`.
- Timeframe: exact D1; slots 0 and 1; magics `410860000` and `410860001`.
- Decision: first tradable synchronized D1 bar of a new Monday-anchored broker
  week, within 180 elapsed raw-session minutes.
- Formation: final synchronized close pair from the immediately completed week
  and from its consecutive parent week, with three to five sessions per week.
- Signal: individual weekly gold and silver returns must share a strict sign;
  fade the strict relative outperformer.
- Normal exit: first tick whose broker Monday anchor is later than the package
  entry anchor.
- Expected cadence: approximately 15-35 completed packages/year.
- Q02 risk: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `G0/S0` be the synchronized parent-week final closes and `G1/S1` the
immediately completed week final closes:

```text
g = ln(G1 / G0)
s = ln(S1 / S0)

g > 0 and s > 0 and g > s  => SELL XAU, BUY XAG
g > 0 and s > 0 and g < s  => BUY XAU, SELL XAG
g < 0 and s < 0 and g > s  => SELL XAU, BUY XAG
g < 0 and s < 0 and g < s  => BUY XAU, SELL XAG
otherwise                   => FLAT
```

Zero, mixed signs, equality within `1e-10`, invalid arithmetic, or missing
endpoints consume the week flat. No current decision-week price enters either
return, and return magnitude never scales risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XAUUSD.DWX` D1 bar under EA 41086 and
   magic slots zero and one.
2. Repair malformed, orphaned, same-side, duplicated, notional-invalid, later-
   week, or stale owned exposure before entry-only gates.
3. Require current XAU and XAG D1 timestamps to be identical and to represent
   the current broker date and Monday-anchored week.
4. Require the immediately prior synchronized completed bar to have an older
   week anchor, proving this is the first tradable bar of the new week.
5. Require attachment within 180 elapsed minutes of the raw host D1 bar open.
   Persist the current Monday anchor attempt before endpoint validation,
   signal, spread, quote, ATR, sizing, news, or order gates. Never retry that
   week.
6. Require no owned position and no same-magic entry deal already recorded in
   the current broker week.
7. Within the fixed 30-bar buffer, require strict host/companion timestamp
   synchronization and reverse-time chronology. Reconstruct the immediately
   completed week and its consecutive parent week, each containing three to
   five synchronized sessions. Select only each week's newest final close
   pair. An invalid session count, nonconsecutive week, timestamp mismatch,
   missing endpoint, or invalid price fails closed.
8. Compute individual completed weekly log returns. Require both strictly
   positive or both strictly negative and require `abs(g-s) > 1e-10`.
9. If `g>s`, sell XAU and buy XAG. If `g<s`, buy XAU and sell XAG. Mixed signs,
   zero, equality, or every other state stays flat.
10. Require valid executable quotes and no genuinely positive spread wider
    than 1,500 XAU points or 500 XAG points. Modeled zero `.DWX` spread is
    valid.
11. Attach one frozen hard stop at `3.5 * ATR(20,D1)` to each leg. Choose lots
    so aggregate normalized stop risk is at most one `RISK_FIXED=1000` budget
    and absolute USD notionals target 1:1 within 20 percent. Use no target.
12. Submit the two market legs once. If the second leg or final package
    validation fails, flatten any opened leg immediately. No pending order,
    retry, scale-in, grid, martingale, pyramid, hedge overlay, or second entry
    exists.

## 5. Exit Rules

1. Broker hard stops and framework kill-switch closure remain authoritative.
2. Immediately flatten an orphaned, duplicated, same-side, wrong-symbol,
   wrong-magic, missing-stop, invalid-volume, or notional-invalid package.
3. Close both legs on the first tick whose broker Monday anchor is later than
   the package-entry Monday anchor.
4. Close both legs after ten elapsed calendar days as a stale safety repair.
5. No Friday close, target, signal exit, trail, break-even move, partial exit,
   discretionary close, or intentional hold beyond the next week.

## 6. Filters (No-Trade Module)

- Exact host/companion, D1, EA 41086, slots zero/one, and registered magics.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF; Friday close is OFF.
- Synchronized first-week-bar clock, 180-minute grace, consecutive completed-
  week endpoints, session counts, individual-return signs, strict inequality,
  durable attempt, spreads, quotes, ATRs, sizing, and stop geometry all fail
  closed.
- No fitted center, futures chain, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, oscillator, or manual signal is read.

## 7. Trade Management Rules

- Own exactly zero or two positions: one `XAUUSD.DWX` leg under magic
  `410860000` and one `XAGUSD.DWX` leg under magic `410860001`.
- The legs must be opposite side, have positive stops, and remain within the
  20-percent absolute-notional mismatch cap.
- Persist the last attempted Monday anchor across restart.
- Manage malformed, later-week, stale, and kill-switch exits before entry.
- Freeze original hard stops; never widen, trail, or remove them.
- Do not retry, add, pyramid, grid, martingale, partially close, overlay a
  hedge, or reverse inside the week.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_history_bars_d1` | 30 | synchronized endpoint buffer |
| `strategy_min_sessions_per_week` | 3 | completed-week lower bound |
| `strategy_max_sessions_per_week` | 5 | completed-week upper bound |
| `strategy_signal_epsilon` | `1e-10` | strict equality deadband |
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg stop distance |
| `strategy_notional_ratio` | 1.0 | target XAU/XAG absolute notional ratio |
| `strategy_max_notional_mismatch_pct` | 20.0 | package rejection cap |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_xau_max_spread_points` | 1500 | host cost guard |
| `strategy_xag_max_spread_points` | 500 | companion cost guard |
| `strategy_deviation_points` | 20 | market-order deviation cap |
| `qm_friday_close_enabled` | false | full-week identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive value |

## Source-Defined Rules

Schweikert supplies evidence for testing a state-dependent gold/silver
relationship. CME supplies the ratio definition and intermarket spread
carrier. Neither supplies this same-direction weekly dispersion signal.

## QM Interpretations

`SCHWEIKERT-CME-XAUXAG-COMMONSHOCK-RV-2026_S01` fixes the synchronized week
clock, consecutive parent/newest endpoints, three-to-five-session validation,
strict same-sign individual returns, equality deadband, symmetric relative-
outperformer fade, continuous-CFD mapping, durable attempt, equal-notional
aggregate fixed risk, spread caps, atomic repair, and one-week lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stops and framework kill switch.
2. Malformed, orphaned, or unsafe package repair.
3. Later broker-week closure.
4. Ten-calendar-day stale repair.

## Runtime Data Dependencies

Exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX` native D1 timestamps and
closes, broker time, symbol metadata, quotes, completed-bar ATRs, framework
position/deal state, and persistent terminal global-variable attempt state.
No finite external dataset or calendar exists.

## Risk

- Backtest only: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stops: `3.5 * ATR(20,D1)` independently on both legs.
- Lots target equal absolute USD notionals while aggregate normalized stop
  risk remains at or below the single fixed-dollar budget.
- No target and no signal-strength sizing.
- Major risks are non-convergence, common-shock misclassification, persistent
  relative trends, leg-basis drift, unequal CFD contract behavior, holiday-
  week endpoints, synchronization, financing, paired costs, minimum-lot
  mismatch, density below the floor, and realized book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, wrong or
mixed labels, asynchronous endpoints, invalid session counts, missing or
wrong week endpoints, wrong return orientation, accepting mixed signs, zero,
or equality, wrong package side, late or repeated attempt, incomplete
aggregate-risk sizing, orphan exposure, missing hard stop, wrong next-week
close, or nondeterminism.

Changing the carrier, endpoint count, session-count bounds, individual-return
orientation, same-sign condition, equality deadband, side, attempt clock,
risk, notional target, stops, or lifecycle requires a new identity, binary,
complete stream reconciliation, and portfolio requalification. A failed
result may not be rescued by accepting mixed signs, adding a magnitude
threshold, changing direction or hold, or adding a fitted center, volatility,
volume, calendar, or external-data filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact carrier/period, synchronized week clock, endpoints, individual returns, strict same-sign state, attempt, spreads, ATRs | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| equal-notional aggregate-risk two-leg open and orphan rollback | Trade Entry | basket-order helper called from `Strategy_EntrySignal` |
| malformed, later-week, and stale package repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helpers |
| no discretionary signal exit | Trade Close | `Strategy_ExitSignal` returns `QM_EXIT_NONE` |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove synchronized first-week-bar and 180-minute clock; consecutive
parent/newest completed weeks; three/four/five-session acceptance and two/six-
session rejection; latest endpoint selection; both positive same-sign and both
negative same-sign directions; symmetric gold and silver leadership; mixed-
sign, zero, equality, asynchronous, missing-parent, and nonconsecutive-week
flat states; no current-week leakage; persistent weekly attempts; aggregate
fixed-risk and equal-notional sizing; second-leg rollback; malformed package
repair; next-week and stale exits; card lint; strict compile; setfile schema;
resolver identity; basket manifest; reference tests; and static artifact
validation.

Q02 alone may measure frequency and baseline combined economics. Q09 alone
may establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-21 | initial XAU/XAG weekly common-shock dispersion reversion card | Q00 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| Q00 Research Intake | 2026-08-21 | APPROVED | `decisions/2026-08-21_qm5_41086_xauxag_weekly_common_shock_dispersion_reversion_g0.md` |
| Q01 Build Validation | 2026-08-21 | NOT_STARTED | pending build |
| Q02 Baseline Screening | 2026-08-21 | NOT_STARTED | enqueue only after Q01 PASS and capacity check |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
logical-basket `RISK_FIXED` backtest setfile, and one paced target-only Q02
enqueue only below tester and whole-host CPU ceilings. It does not authorize a
manual backtest, terminal control, live/demo/shadow/stress/optimization preset,
AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio-gate change,
portfolio admission, decorrelation claim, or correlation waiver.
