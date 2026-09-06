---
card_schema_version: 2
type: strategy
strategy_id: AI-CODEX-XTIXNG-COMMONSHOCK-RV-20260906_S01
variant_id: AI-CODEX-XTIXNG-COMMONSHOCK-RV-20260906_S01
source_id: AI-CODEX-XTIXNG-COMMONSHOCK-RV-20260906
ea_id: QM5_41361
slug: xtixng-commonshock-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41361_xtixng-commonshock-rv_card.md
execution_contract_status: APPROVED
created: 2026-09-06
created_by: Research+Development
last_updated: 2026-09-06
g0_status: APPROVED
g0_decision: decisions/2026-09-06_qm5_41361_xtixng_weekly_common_shock_dispersion_reversion_g0.md
source_approval: decisions/2026-09-06_xtixng_weekly_common_shock_dispersion_reversion_source_approval.md
source_author: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons"
source_authors: "Jose A. Villar; Frederick L. Joutz; David J. Ramberg; John E. Parsons"
source_citation: "Villar, J. A. and Joutz, F. L. (2006), The Relationship Between Crude Oil and Natural Gas Prices, U.S. EIA; Ramberg, D. J. and Parsons, J. E. (2012), The Weak Tie Between Natural Gas and Oil Prices, The Energy Journal 33(2), 13-35."
source_citations:
  - type: government_research
    citation: "Villar, J. A. and Joutz, F. L. (2006). The Relationship Between Crude Oil and Natural Gas Prices. U.S. Energy Information Administration."
    location: "Complete-read governed packet strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: oil_gas_physical_economic_link_and_instability
  - type: peer_reviewed_paper
    citation: "Ramberg, D. J. and Parsons, J. E. (2012). The Weak Tie Between Natural Gas and Oil Prices. The Energy Journal 33(2), 13-35."
    location: "DOI 10.5547/01956574.33.2.2; complete-read governed packet strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md"
    quality_tier: A
    role: weak_time_varying_oil_gas_relationship_and_adverse_evidence
strategy_mechanic: normalized-week-boundary-xti-xng-synchronized-completed-week-individual-log-returns-strict-same-sign-common-shock-relative-outperformer-fade-equal-notional-one-week-hold
sources:
  - "[[sources/AI-CODEX-XTIXNG-COMMONSHOCK-RV-20260906]]"
concepts:
  - "[[concepts/oil-gas-relative-value]]"
  - "[[concepts/completed-week-common-direction-dispersion]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-week-individual-log-return]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, oil-gas-relative-value, market-neutral-basket, common-direction-dispersion, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy]
timeframes: [D1]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41361_XTI_XNG_COMMONSHOCK_RV_D1
symbol: QM5_41361_XTI_XNG_COMMONSHOCK_RV_D1
host_symbol: XTIUSD.DWX
companion_symbol: XNGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [413610000, 413610001]
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
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: COMPILE_OK
q02_status: ENQUEUED_PENDING
review_focus: "Falsify a completed-week WTI/natural gas same-direction dispersion fade outside the certified XAU/SP500/NDX/XNG book. Verify exact prior-two-week membership, synchronized three-to-five-session close pairs, week-end endpoint selection, strict same-sign individual returns, symmetric relative-outperformer fade, durable weekly attempt, aggregate fixed risk, atomic basket repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xti_xng_carrier, immediately_preceding_two_monday_anchors, synchronized_completed_d1_closes, three_to_five_week_sessions, exact_week_end_endpoints, strict_individual_leg_same_sign, strict_relative_return_inequality, contrarian_relative_outperformer_direction, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses complete U.S. government and peer-reviewed oil/gas evidence, retains adverse instability, and discloses the common-shock fade as an untested QM translation; R2 locks synchronized consecutive weeks, endpoint selection, individual log-return orientation, strict shared sign, strict relative inequality, contrarian sides, durable attempt, aggregate fixed risk, hard stops, spreads, and next-week lifecycle; R3 uses registered native XTI/XNG D1 histories with synchronization and CFD-basis risks explicit; R4 is deterministic native arithmetic without a banned signal, trained output, or external feed; canonical dedup and manual carrier-family review found no exact identity."
---

# QM5_41361 XTI/XNG Weekly Common-Shock Dispersion Reversion

## Hypothesis

WTI crude oil and natural gas share broad energy-demand, production, drilling,
financing, and substitution channels while gas also carries large regional,
weather, storage, and transport shocks. When both contracts move in the same
strict direction over one synchronized completed broker week, treat the shared
sign as a common-shock admission state. Fade the relative dispersion by selling
the energy contract with the larger completed return and buying the one with
the smaller return as one equal-notional package for the following week.

The government and peer-reviewed sources support testing a weak, time-varying
oil/gas relationship. They do not establish this weekly signal, efficacy, or
neutrality. No ex-ante profitability, neutrality, or decorrelation claim is
made.

## Source Traceability And Claim Boundary

The approved source of record is
`strategy-seeds/sources/AI-CODEX-XTIXNG-COMMONSHOCK-RV-20260906/source.md`,
authorized before extraction in
`decisions/2026-09-06_xtixng_weekly_common_shock_dispersion_reversion_source_approval.md`.

Villar/Joutz and Ramberg/Parsons supply government and peer-reviewed evidence
for a weak, time-varying oil/gas relationship, including binding adverse
instability evidence. The governed parent supplies only the exact completed-
week common-direction arithmetic. No source tests this energy CFD
implementation, and no return, frequency, cost, hedge-ratio, neutrality, or
correlation statistic transfers.

## Non-Duplicate Decision

The canonical checker scanned 4,841 registry rows and 1,454 cards, found no
exact identity, and surfaced only the expected `QM5_41086_xauxag-commonshock-rv`
arithmetic parent. The optional external Wiki root was unavailable and this
coverage limit remains explicit.

- `QM5_41086` owns the same event arithmetic on XAU/XAG; this card owns the
  economically distinct WTI/natural-gas carrier and its contract/cost risks.
- `QM5_41357_xtixng-mwinsor2-rv` uses twelve monthly ratio returns and
  fixed-tail Winsorization.
- `QM5_41358` and `QM5_41360` classify two adjacent opposite-sign ratio
  returns; `QM5_41359` classifies two adjacent same-sign accelerating ratio
  returns. This card uses one weekly return per individual leg, not a
  multiweek ratio path.
- `QM5_41340_wti-xng-divtrend` trades WTI only and uses XNG as a veto.
- `QM5_12567_cum-rsi2-commodity` is a single-symbol, long-only, two-day XNG
  oscillator pullback.

The energy carrier, consecutive synchronized completed-week endpoints, strict
same-sign individual returns, symmetric relative-outperformer fade, persistent
weekly attempt, equal-notional aggregate-risk package, and next-week exit are
jointly load-bearing. Verdict:
`FUZZY_CARRIER_PORT_RESOLVED_DISTINCT_XTIXNG_SAME_DIRECTION_WEEKLY_COMMON_SHOCK_RELATIVE_OUTPERFORMER_FADE_BASKET`.

## Markets, Timeframe, And Cadence

- Host: exact `XTIUSD.DWX`; companion: exact `XNGUSD.DWX`.
- Logical basket: `QM5_41361_XTI_XNG_COMMONSHOCK_RV_D1`.
- Timeframe: exact D1; slots 0 and 1; magics `413610000` and `413610001`.
- Decision: first tradable synchronized D1 bar of a new Monday-anchored broker
  week, within 180 elapsed raw-session minutes.
- Formation: final synchronized close pair from the immediately completed week
  and from its consecutive parent week, with three to five sessions per week.
- Signal: individual weekly WTI and natural gas returns must share a strict sign;
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

g > 0 and s > 0 and g > s  => SELL XTI, BUY XNG
g > 0 and s > 0 and g < s  => BUY XTI, SELL XNG
g < 0 and s < 0 and g > s  => SELL XTI, BUY XNG
g < 0 and s < 0 and g < s  => BUY XTI, SELL XNG
otherwise                   => FLAT
```

Zero, mixed signs, equality within `1e-10`, invalid arithmetic, or missing
endpoints consume the week flat. No current decision-week price enters either
return, and return magnitude never scales risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XTIUSD.DWX` D1 bar under EA 41361 and
   magic slots zero and one.
2. Repair malformed, orphaned, same-side, duplicated, notional-invalid, later-
   week, or stale owned exposure before entry-only gates.
3. Require current XTI and XNG D1 timestamps to be identical and to represent
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
9. If `g>s`, sell XTI and buy XNG. If `g<s`, buy XTI and sell XNG. Mixed signs,
   zero, equality, or every other state stays flat.
10. Require valid executable quotes and no genuinely positive spread wider
    than 1,500 XTI points or 3,000 XNG points. Modeled zero `.DWX` spread is
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

- Exact host/companion, D1, EA 41361, slots zero/one, and registered magics.
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

- Own exactly zero or two positions: one `XTIUSD.DWX` leg under magic
  `413610000` and one `XNGUSD.DWX` leg under magic `413610001`.
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
| `strategy_xng_symbol` | `XNGUSD.DWX` | exact companion |
| `strategy_history_bars_d1` | 30 | synchronized endpoint buffer |
| `strategy_min_sessions_per_week` | 3 | completed-week lower bound |
| `strategy_max_sessions_per_week` | 5 | completed-week upper bound |
| `strategy_signal_epsilon` | `1e-10` | strict equality deadband |
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg stop distance |
| `strategy_notional_ratio` | 1.0 | target XTI/XNG absolute notional ratio |
| `strategy_max_notional_mismatch_pct` | 20.0 | package rejection cap |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_xti_max_spread_points` | 1500 | host cost guard |
| `strategy_xng_max_spread_points` | 3000 | companion cost guard |
| `strategy_deviation_points` | 20 | market-order deviation cap |
| `qm_friday_close_enabled` | false | full-week identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive value |

## Source-Defined Rules

Villar/Joutz and Ramberg/Parsons supply evidence for testing a weak,
time-varying oil/gas relationship and preserve adverse instability. They do
not supply this same-direction weekly dispersion signal.

## QM Interpretations

`AI-CODEX-XTIXNG-COMMONSHOCK-RV-20260906_S01` fixes the synchronized
week clock, consecutive parent/newest endpoints, three-to-five-session
validation, strict same-sign individual returns, equality deadband, symmetric
relative-outperformer fade, continuous-CFD mapping, durable attempt,
equal-notional aggregate fixed risk, spread caps, atomic repair, and one-week
lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stops and framework kill switch.
2. Malformed, orphaned, or unsafe package repair.
3. Later broker-week closure.
4. Ten-calendar-day stale repair.

## Runtime Data Dependencies

Exact synchronized `XTIUSD.DWX` and `XNGUSD.DWX` native D1 timestamps and
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
negative same-sign directions; symmetric WTI and natural gas leadership; mixed-
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
| v1 | 2026-09-06 | initial XTI/XNG weekly common-shock dispersion reversion card | G0 | APPROVED; build pending |
| v2 | 2026-09-06 | governed compile-PASS build and one logical fixed-risk baseline enqueue | Q01/Q02 | COMPILE_OK; ENQUEUED_PENDING |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-09-06 | APPROVED | `decisions/2026-09-06_qm5_41361_xtixng_weekly_common_shock_dispersion_reversion_g0.md` |
| Q01 Build Validation | 2026-09-06 | COMPILE_OK; BUILD_CHECK_PASS | `D:/QM/reports/work_items/c5bf5069-ecfb-40a2-a0d7-2e282d8a7df1/QM5_41361/COMPILE_EA/compile_evidence.json` |
| Q02 Baseline Screening | 2026-09-06 | ENQUEUED_PENDING | work item `ecc8e269-5a19-4cda-8c4e-0906d4f93791`; CPU admission `artifacts/qm5_41361_q02_cpu_admission_20260906.json` |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
logical-basket `RISK_FIXED` backtest setfile, and one paced target-only Q02
enqueue only below tester and whole-host CPU ceilings. It does not authorize a
manual backtest, terminal control, live/demo/shadow/stress/optimization preset,
AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio-gate change,
portfolio admission, decorrelation claim, or correlation waiver.
