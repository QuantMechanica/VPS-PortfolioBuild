---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-WDAYBREADTH4-RV-2026_S01
variant_id: SCHWEIKERT-CME-XAUXAG-WDAYBREADTH4-RV-2026_S01
source_id: SCHWEIKERT-CME-XAUXAG-WDAYBREADTH4-RV-2026
ea_id: QM5_41085
slug: xauxag-wdaybreadth-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41085_xauxag-wdaybreadth-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-21
created_by: Research+Development
last_updated: 2026-08-21
g0_status: APPROVED
g0_decision: decisions/2026-08-21_qm5_41085_xauxag_weekly_daily_relative_sign_breadth_reversion_g0.md
source_approval: decisions/2026-08-21_xauxag_weekly_daily_relative_sign_breadth_reversion_source_approval.md
source_author: "Karsten Schweikert; CME Group"
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; Yaya, Vo, and Olayinka (2021), Resources Policy 72, 102045, DOI 10.1016/j.resourpol.2021.102045; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: academic_paper
    citation: "Schweikert, Karsten (2018), Are gold and silver cointegrated? New evidence from quantile cointegrating regressions, Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_long_run_relation
  - type: exchange_research
    citation: "CME Group, Gold & Silver Ratio Spread."
    location: "governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md; bounded extraction strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WDAYBREADTH4-RV-2026/source.md"
    quality_tier: A
    role: ratio_definition_and_intermarket_spread_carrier
strategy_mechanic: synchronized-parent-week-final-plus-exact-five-session-completed-week-xau-minus-xag-daily-relative-log-return-signs-four-of-five-breadth-and-weekly-net-agreement-contrarian-one-week-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-CME-XAUXAG-WDAYBREADTH4-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-ratio-reversion]]"
  - "[[concepts/within-week-relative-directional-breadth]]"
  - "[[concepts/market-neutral-commodity-basket]]"
indicators:
  - "[[indicators/adjacent-daily-relative-return-sign-count]]"
  - "[[indicators/completed-week-relative-net-return]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, gold-silver-ratio, relative-value-basket, daily-relative-sign-breadth, weekly-net-confirmation, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41085_XAU_XAG_WDAYBREADTH_RV_D1
symbol: QM5_41085_XAU_XAG_WDAYBREADTH_RV_D1
host_symbol: XAUUSD.DWX
companion_symbol: XAGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [410850000, 410850001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-20 completed paired packages per full post-warm-up year after exact five-session synchronization, four-of-five daily relative-sign breadth, weekly-net agreement, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 14
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_DAILY_BREADTH_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_EXACT_FIVE_SESSION_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
review_focus: "Falsify a completed-week gold/silver daily relative-sign breadth fade outside the certified XAU/SP500/NDX/XNG book. Verify synchronized parent and exact five-session endpoints, chronological relative-return orientation, strict four-of-five breadth, same-sign weekly net, contrarian pair sides, durable weekly attempt, aggregate fixed risk, atomic basket repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xau_xag_carrier, synchronized_first_tradable_week_bar, parent_week_final_close, exact_five_session_completed_week, five_adjacent_relative_log_returns, strict_four_of_five_sign_breadth, same_sign_weekly_relative_net, contrarian_package_direction, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses one bounded child source with named peer-reviewed DOI and official exchange lineage while disclosing the weekly daily-breadth fade as an untested QM translation; R2 locks exact synchronized parent/newest-week endpoints, chronological relative returns, zero handling, strict breadth/net agreement, contrarian side, durable attempt, aggregate fixed risk, equal notionals, hard stops, spreads, and next-week lifecycle; R3 uses registered native XAU/XAG D1 histories with exact-five-session synchronization and CFD-basis risks explicit and requires active slots 0/1 before build; R4 is deterministic timestamp, price, logarithm, counting, comparison, ATR, quote, position, deal, and terminal-state arithmetic without a banned signal, trained output, external feed, grid, or martingale; canonical dedup and manual family review found no exact identity."
---

# QM5_41085 XAU/XAG Completed-Week Daily Relative-Sign Breadth Reversion

## Hypothesis

Gold and silver share a long-run precious-metals factor but respond differently
to monetary, safe-haven, and industrial forces. When the gold/silver ratio
moves in one direction on at least four of five synchronized daily intervals
and the completed-week net move agrees, the displacement is broadly
participated rather than caused solely by one endpoint jump. On the next
broker week, fade that relative displacement with opposite equal-notional legs.

The source supports testing a potentially state-dependent gold/silver
relationship and the ratio as an intermarket spread. It does not establish
this exact five-session breadth rule, weekly fade, standalone CFD result, or
portfolio relationship. The rule is falsifiable and carries no ex-ante
profitability, neutrality, or decorrelation claim.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WDAYBREADTH4-RV-2026/source.md`,
approved before card extraction in
`decisions/2026-08-21_xauxag_weekly_daily_relative_sign_breadth_reversion_source_approval.md`
at commit `25a9c6356`.

Schweikert documents state-dependent gold/silver cointegration evidence, and
CME defines the gold/silver ratio and intermarket spread carrier. Neither
source tests adjacent synchronized daily relative returns, an exact five-
session week, a four-of-five threshold, weekly-net confirmation, continuous-
CFD labels, equal-notional fixed-dollar risk, or a one-week hold. All such
clock, endpoint, signal, execution, and risk choices below are declared QM
interpretations. No source return, density, hedge ratio, cost, or correlation
result transfers.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,572 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review fixes
the load-bearing boundaries:

- `QM5_12577`, `QM5_20157`, `QM5_20161`, `QM5_20263`, and `QM5_20268`
  estimate a rolling center, regression, scale, robust score, or empirical
  tail; this card estimates none.
- `QM5_41079_xauxag-wclose-extreme-rv` ranks the final ratio close inside a
  three-to-five-session week. It uses no parent endpoint, exact-five-session
  requirement, adjacent relative returns, or sign-breadth count.
- `QM5_41083_xauxag-wlegdiv-rv` compares the individual metals' full-week
  return signs and has no within-week daily path state.
- `QM5_41030`, `QM5_41040`, and `QM5_41057` decompose session and overnight
  relative flows rather than adjacent close-to-close relative returns.
- `QM5_41066` and `QM5_41075` through `QM5_41078` classify relative returns
  across multiple completed weeks rather than daily breadth inside one week.
- `QM5_41084_wti-wdaybreadth-mom` trades one directional WTI carrier and
  follows its move; this card fades a two-metal relative move and equalizes
  absolute package notionals.
- `QM5_12567_cum-rsi2-commodity` is a single-symbol long-only two-day
  oscillator pullback, not a synchronized intermetal basket.

The exact paired carrier, parent-week endpoint, exact five-session synchronized
week, five relative-return signs, strict four-of-five breadth, same-sign weekly
net, contrarian package side, persistent weekly attempt, equal-notional
aggregate-risk package, and next-week exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_EXACT_FIVE_SESSION_DAILY_RELATIVE_SIGN_BREADTH_REVERSION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Host: exact `XAUUSD.DWX`; companion: exact `XAGUSD.DWX`.
- Logical basket: `QM5_41085_XAU_XAG_WDAYBREADTH_RV_D1`.
- Timeframe: exact D1; slots 0 and 1; magics `410850000` and `410850001`.
- Decision: first tradable synchronized D1 bar of a new Monday-anchored broker
  week, within 180 elapsed raw-session minutes.
- Formation: the parent week's final synchronized ratio close plus exactly
  five synchronized closes in the immediately completed week.
- Signal: at least four of five adjacent relative returns share one strict sign
  and the full-week relative return has that same strict sign.
- Direction: fade the agreeing relative sign with one opposite-leg package.
- Normal exit: first tick whose broker Monday anchor is later than the package
  entry anchor.
- Expected cadence: approximately 10-20 completed packages/year.
- Q02 risk: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `q0` be the synchronized parent-week final log ratio and `q1..q5` the five
chronological synchronized log-ratio closes of the immediately completed week:

```text
q_i = ln(XAU_i) - ln(XAG_i)
d_i = q_i - q_(i-1), i = 1..5
weekly_net = q5 - q0

positive_count >= 4 and weekly_net > 0
    => SELL XAUUSD.DWX, BUY XAGUSD.DWX

negative_count >= 4 and weekly_net < 0
    => BUY XAUUSD.DWX, SELL XAGUSD.DWX

otherwise
    => FLAT
```

All endpoints are complete before the decision week begins. Zero component
returns count toward neither side. The current decision-week open, high, low,
or close never enters the signal. Relative-return magnitude never scales risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XAUUSD.DWX` D1 bar under EA 41085 and
   magic slots zero and one.
2. Repair malformed, orphaned, same-side, duplicated, notional-invalid, later-
   week, or stale owned exposure before entry-only gates.
3. Require the current XAU and XAG D1 bar timestamps to be identical and to
   represent the current broker date and Monday-anchored week.
4. Require the immediately prior synchronized completed bar to have an older
   week anchor, proving this is the first tradable bar of the new week.
5. Require attachment within 180 elapsed minutes of the raw host D1 bar open.
   Persist the current Monday anchor attempt before endpoint validation,
   signal, spread, quote, ATR, sizing, news, or order gates. Never retry that
   week.
6. Require no owned position and no same-magic entry deal already recorded in
   the current broker week.
7. Within the fixed 30-bar buffer, require exact host/companion timestamp
   synchronization and strict reverse-time chronology. Select exactly five
   closes from the immediately completed week and the newest final close from
   its consecutive parent week. Any sixth newest-week session, missing parent
   boundary, asynchronous pair, invalid label, or nonconsecutive week fails.
8. Reverse endpoints to chronological order. Compute the six log ratios, five
   adjacent relative log returns, and parent-final-to-newest-final weekly net.
   Count strict signs; zero counts toward neither side.
9. Require at least four positive components and a positive weekly net to sell
   XAU/buy XAG, or at least four negative components and a negative weekly net
   to buy XAU/sell XAG. Equality, disagreement, or any other state stays flat.
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

- Exact host/companion, D1, EA 41085, slots zero/one, and registered magics.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF; Friday close is OFF.
- Synchronized first-week-bar clock, 180-minute grace, exact parent/five-
  session endpoints, relative-return chronology, breadth/net state, durable
  attempt, spreads, quotes, ATRs, sizing, and stop geometry all fail closed.
- No fitted center, futures chain, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, oscillator, or manual signal is read.

## 7. Trade Management Rules

- Own exactly zero or two positions: one `XAUUSD.DWX` leg under magic
  `410850000` and one `XAGUSD.DWX` leg under magic `410850001`.
- The legs must be opposite side, have positive stops, and remain within the
  20-percent absolute-notional mismatch cap.
- Persist the last attempted Monday anchor across restart.
- Manage malformed, later-week, stale, and kill-switch exits before entry.
- Freeze original hard stops; never widen, trail, or remove them.
- Do not retry, add, pyramid, grid, martingale, partially close, overlay hedge,
  or reverse inside the week.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_history_bars_d1` | 30 | synchronized endpoint buffer |
| `strategy_required_sessions` | 5 | exact completed-week session count |
| `strategy_min_same_sign` | 4 | strict daily relative-sign breadth |
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
carrier. Neither supplies this weekly daily-breadth signal.

## QM Interpretations

`SCHWEIKERT-CME-XAUXAG-WDAYBREADTH4-RV-2026_S01` fixes the synchronized
week clock, parent plus five endpoints, strict daily relative-return signs,
four-of-five breadth, weekly-net agreement, inverse side, continuous-CFD
mapping, durable attempt, equal-notional aggregate fixed risk, spread caps,
atomic repair, and one-week lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stops and framework kill switch.
2. Malformed, orphaned, or unsafe package repair.
3. Later broker-week closure.
4. Ten-calendar-day stale repair.

## Runtime Data Dependencies

Exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX` native D1 closes, broker time,
symbol metadata, quotes, completed-bar ATRs, framework position/deal state,
and persistent terminal global-variable attempt state. No finite external
dataset or calendar exists.

## Risk

- Backtest only: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stops: `3.5 * ATR(20,D1)` independently on both legs.
- Lots target equal absolute USD notionals while aggregate normalized stop
  risk remains at or below the single fixed-dollar budget.
- No target and no signal-strength sizing.
- Major risks are ratio regime breaks, leg-basis drift, unequal CFD contract
  behavior, holiday-week attrition, synchronization, financing, paired costs,
  minimum-lot mismatch, density below the floor, and realized book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, wrong or
mixed labels, asynchronous endpoints, a non-five-session week, missing or
wrong parent endpoint, overlapping/misoriented relative returns, incorrect
zero handling, absent four-of-five breadth/net agreement, wrong package side,
late or repeated attempt, incomplete aggregate-risk sizing, orphan exposure,
missing hard stop, wrong next-week close, or nondeterminism.

Changing the carrier, endpoint count, session-count rule, relative-return
orientation, breadth threshold, weekly-net conjunction, side, attempt clock,
risk, notional target, stops, or lifecycle requires a new identity, binary,
complete stream reconciliation, and portfolio requalification. A failed
result may not be rescued by accepting four sessions, lowering breadth,
removing net confirmation, following rather than fading, changing the hold, or
adding a fitted center, volatility, volume, calendar, or external-data filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact carrier/period, synchronized week clock, endpoints, relative returns, strict breadth/net state, attempt, spreads, ATRs | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| equal-notional aggregate-risk two-leg open and orphan rollback | Trade Entry | basket-order helper called from `Strategy_EntrySignal` |
| malformed, later-week, and stale package repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helpers |
| no discretionary signal exit | Trade Close | `Strategy_ExitSignal` returns false |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove synchronized first-week-bar and 180-minute clock; exact five-
session prior week plus one parent final endpoint; chronological six-ratio and
five-return orientation; both breadth/net directions; three-of-five, zero,
net-disagreement, four-session, equality, async, missing-parent, and sixth-
session flat states; contrarian pair sides; persistent weekly attempts;
aggregate fixed-risk and equal-notional sizing; second-leg rollback; malformed
package repair; next-week and stale exits; card lint; strict compile; setfile
schema; resolver identity; basket manifest; and static artifact validation.

Q02 alone may measure frequency and baseline combined economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-21 | initial XAU/XAG completed-week daily relative-sign breadth reversion card | Q00 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| Q00 Research Intake | 2026-08-21 | APPROVED | `decisions/2026-08-21_qm5_41085_xauxag_weekly_daily_relative_sign_breadth_reversion_g0.md` |
| Q01 Build Validation | - | NOT_RUN | governed build pending |
| Q02 Baseline Screening | - | NOT_ENQUEUED | paced enqueue only after Q01 PASS and capacity checks |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
logical-basket `RISK_FIXED` backtest setfile, and one paced target-only Q02
enqueue only below tester and CPU ceilings. It does not authorize a manual
backtest, terminal control, live/demo/shadow/stress/optimization preset,
AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio-gate change,
portfolio admission, decorrelation claim, or correlation waiver.
