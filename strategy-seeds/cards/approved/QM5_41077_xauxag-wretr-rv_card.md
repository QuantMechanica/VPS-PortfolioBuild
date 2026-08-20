---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-WRETR-RV-2026_S01
variant_id: SCHWEIKERT-CME-XAUXAG-WRETR-RV-2026_S01
source_id: SCHWEIKERT-CME-XAUXAG-WRETR-RV-2026
ea_id: QM5_41077
slug: xauxag-wretr-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41077_xauxag-wretr-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-21
created_by: Research+Development
last_updated: 2026-08-21
g0_status: APPROVED
g0_decision: decisions/2026-08-21_qm5_41077_xauxag_weekly_partial_retracement_continuation_g0.md
source_approval: decisions/2026-08-21_xauxag_weekly_partial_retracement_continuation_source_approval.md
source_author: "Karsten Schweikert; CME Group"
source_authors: "Karsten Schweikert; CME Group"
source_citation: "Schweikert, K. (2018), Are gold and silver cointegrated? New evidence from quantile cointegrating regressions, Journal of Banking & Finance 88, 44-51; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: academic_paper
    citation: "Schweikert, Karsten (2018), Are gold and silver cointegrated? New evidence from quantile cointegrating regressions, Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_relative_value_lineage
  - type: exchange_education
    citation: "CME Group, Gold & Silver Ratio Spread."
    location: "Governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: A
    role: gold_silver_ratio_intermarket_carrier
strategy_mechanic: synchronized-completed-two-adjacent-week-xau-minus-xag-relative-returns-opposite-sign-newest-strictly-smaller-follow-newest-retracement-one-week-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-CME-XAUXAG-WRETR-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/weekly-partial-retracement-continuation]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/adjacent-completed-week-relative-log-returns]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, gold-silver-ratio, market-neutral-basket, weekly-partial-retracement, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41077_XAU_XAG_WRETR_RV_D1
symbol: QM5_41077_XAU_XAG_WRETR_RV_D1
host_symbol: XAUUSD.DWX
companion_symbol: XAGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [410770000, 410770001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately eight to twenty completed paired packages per full post-warm-up year after exact synchronized weeks, strict sign opposition, strict smaller newest magnitude, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 14
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_RETRACEMENT_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING
q02_status: NOT_ENQUEUED
review_focus: "Falsify a completed-week gold/silver partial-retracement continuation outside the certified XAU/SP500/NDX/XNG book. Verify exact synchronized week ends, chronological non-overlapping returns, strict sign opposition, strict smaller newest magnitude, newest-return sides, durable weekly attempt, aggregate fixed risk, atomic basket repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xau_xag_carrier, synchronized_week_endpoints, consecutive_monday_anchors, nonoverlapping_relative_returns, strict_sign_opposition, strict_newest_absolute_smaller, follow_newest_return_basket_direction, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses one bounded child source with named peer-reviewed DOI and official exchange lineages while disclosing the weekly partial-retracement continuation as an untested QM translation; R2 locks exact synchronized weeks, chronological relative returns, strict sign opposition, strict smaller newest magnitude, newest-return side, durable attempt, aggregate fixed risk, equal notional, hard stops, spreads, and next-week lifecycle; R3 uses registered native XAU/XAG D1 histories with synchronization and CFD-basis risks explicit and requires active slots 0/1 before build; R4 is deterministic timestamp, price, logarithm, ATR, quote, position, deal, and terminal-state arithmetic without a banned signal, trained output, external feed, grid, or martingale; canonical dedup and manual family review found no exact identity."
---

# QM5_41077 XAU/XAG Completed-Week Partial-Retracement Continuation

## Hypothesis

When a completed-week gold/silver log-ratio impulse is followed by a smaller
completed-week move in the opposite direction, the second move is a bounded
partial retracement: the ratio finishes between the impulse extreme and its
pre-impulse anchor. Following that retracement for one additional broker week
may capture continued convergence without taking an outright single-metal
signal.

The candidate is one logical two-leg package intended to add a distinct
relative-value return driver outside the certified XAU/SP500/NDX/XNG book.
Equal notional is an execution target, not proof of beta neutrality. Q02 must
establish density and economics, and unchanged Q09 alone may establish
realized book correlation.

## Source Traceability And Claim Boundary

The approved source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WRETR-RV-2026/source.md`,
authorized before card extraction in
`decisions/2026-08-21_xauxag_weekly_partial_retracement_continuation_source_approval.md`
at commit `c1f1182c1`.

Schweikert supplies named peer-reviewed evidence for a potentially state-
dependent gold/silver relationship. CME defines the gold/silver ratio and
supports treating the instruments as one intermarket spread carrier. Neither
source tests adjacent opposite-sign weekly returns, strict smaller-retracement
geometry, newest-direction continuation, a continuous-CFD package, equal-
notional sizing, fixed cash risk, ATR stops, or a one-week hold.

No source return, profit factor, Sharpe ratio, drawdown, trade count,
transaction cost, hedge ratio, threshold, CFD equivalence, neutrality, or
portfolio-correlation statistic transfers. Every implementation choice below
is a pre-result QM falsification choice.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,564 registry rows and 625 root
cards and returned `CLEAN`. Manual semantic review fixes the boundaries:

- `QM5_41066_xauxag-wdecay-rv` uses two strict same-sign weekly relative
  returns with a strictly smaller newest absolute move. This card requires
  opposite signs.
- `QM5_41075_xauxag-wovershoot-rv` uses opposite signs but requires the newest
  absolute move to be strictly larger and then fades it. This card requires
  the newest move to be strictly smaller and follows it, so state and side
  both differ.
- `QM5_41076_xauxag-waccel-rv` uses two same-sign weekly relative returns with
  strict newest acceleration and fades the shared direction. This card uses a
  bounded opposite-sign retracement.
- `QM5_41069_wti-wpull-trend` is a single-leg WTI sibling that follows the
  older dominant impulse after a smaller opposite week. This card uses a
  paired two-metal carrier and follows the smaller newest counter-move toward
  the pre-impulse ratio anchor.
- `QM5_20275_gsr-runfade` uses five consecutive same-sign D1 relative returns
  plus a preceding run break and exits on a counter-return. This card uses
  exactly two non-overlapping completed broker weeks and follows the second.
- `QM5_20157`, `QM5_20161`, `QM5_20263`, `QM5_20265`, and `QM5_20268` use a
  rolling center, standard deviation, fitted residual, robust score, channel,
  or empirical tail. This card estimates none.
- `QM5_20184`, `QM5_20194`, `QM5_20202`, and `QM5_20260` use completed-month
  cross-sectional ranks, horizon conflicts, or votes. This card uses adjacent
  broker-week spread returns and no rank.
- `QM5_41030`, `QM5_41039`, `QM5_41040`, and `QM5_41057` decompose overnight
  and within-session relative flows. This card reads only completed week-end
  closes.
- `QM5_41062_xauxag-wgap-fade` uses current Monday opens versus prior Friday
  closes and requires opposite component gaps. This card excludes all current-
  week prices and uses two full historical week totals.
- `QM5_41060_xauxag-week-nr7-brk` follows a completed-close breakout after a
  strict weekly-range contraction. This card uses no high, low, range, or
  breakout.
- `QM5_12533` is only the validated logical-basket manifest/order recipe; its
  signal is an EURJPY/GBPJPY cointegration spread.
- `QM5_12567_cum-rsi2-commodity` is a single-symbol long-only two-day
  oscillator pullback and has no intermetal, weekly, or paired logic.

The exact XAU/XAG carrier, three synchronized week ends, two adjacent relative
returns, strict sign opposition, strict smaller newest magnitude, newest-
return side, weekly attempt, equal-notional aggregate-risk package, and next-
week exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_OPPOSITE_WEEK_PARTIAL_RETRACEMENT_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host: `XAUUSD.DWX`, D1, slot 0, magic `410770000`.
- Exact companion: `XAGUSD.DWX`, D1, slot 1, magic `410770001`.
- Logical symbol: `QM5_41077_XAU_XAG_WRETR_RV_D1`.
- Formation: three consecutive synchronized completed broker-week-end pairs.
- Decision: first tradable bar of a new Monday-anchored broker week, within
  180 elapsed raw-session minutes.
- Signal: two strict opposite-sign weekly relative returns with strictly
  smaller newest absolute magnitude; follow the newest direction.
- Ordinary exit: first tick whose broker Monday anchor is later than the
  package-open anchor.
- Expected cadence: eight to twenty completed packages/year; retire below
  five.
- Q02 risk: aggregate-package `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let pair 1 be the newest completed synchronized week-end closes, pair 2 the
immediately preceding week ends, and pair 3 the next older consecutive week
ends. Define:

```text
s1 = ln(XAU_1) - ln(XAG_1)
s2 = ln(XAU_2) - ln(XAG_2)
s3 = ln(XAU_3) - ln(XAG_3)

r_new = s1 - s2
r_old = s2 - s3

r_old > 0 and r_new < 0 and abs(r_new) < abs(r_old)
    => SELL XAU, BUY XAG
r_old < 0 and r_new > 0 and abs(r_new) < abs(r_old)
    => BUY XAU, SELL XAG
otherwise
    => FLAT
```

The strict smaller condition proves that `s1` lies between `s2` and `s3`.
All endpoints are completed before the decision week begins. The current D1
open, high, low, or close never enters either return. Equality is flat.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XAUUSD.DWX` D1 bar under EA 41077 and
   host magic slot zero.
2. Repair malformed, orphaned, duplicated, same-side, stopless, notional-
   invalid, later-week, or stale owned exposure before entry-only gates.
3. Require exact host D1 and companion D1 timestamps. Derive the current
   Monday anchor from broker time and prove the current bar is the first
   tradable D1 bar carrying that new anchor. Reject attachment later than 180
   elapsed minutes after the raw host bar open.
4. Persist the current Monday anchor attempt before history, signal, spread,
   quote, ATR, sizing, news, or order gates. Never retry that week.
5. Within a fixed 30-bar buffer, select only the newest synchronized positive
   finite close pair belonging to each distinct prior Monday anchor. Require
   exactly the latest three anchors to be current anchor minus 7, 14, and 21
   calendar days, in strict reverse-time order.
6. Compute `s1`, `s2`, `s3`, `r_new`, and `r_old` exactly as specified. Require
   both returns finite and non-zero, strict opposite signs, and
   `abs(r_new)<abs(r_old)`. Same signs, either zero, equality, or a larger
   newest move remains flat.
7. SELL XAU/BUY XAG only when `r_old>0`, `r_new<0`, and the newest move is
   strictly smaller. BUY XAU/SELL XAG only when `r_old<0`, `r_new>0`, and the
   newest move is strictly smaller. Signal magnitude never changes risk.
8. Require no owned exposure, no same-magic entry deal already recorded in the
   current broker week, executable side-specific quotes, and no genuinely
   positive spread wider than 1,500 XAU points or 500 XAG points. Modeled zero
   `.DWX` spread is valid.
9. Require valid completed-bar `ATR(20,D1)` for both legs and attach one frozen
   hard stop at `3.5*ATR` on each. Size the package so combined normalized stop
   risk cannot exceed the single `RISK_FIXED=1000` budget.
10. Target one-to-one absolute entry notional. Round down only and reject a
    resulting mismatch above 20 percent. Use no take-profit.
11. Submit the two market legs once. If either leg fails or the resulting
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

- Exact host, D1, EA 41077, slot zero, and both registered magics.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes, legacy news mode, and Friday close are OFF for Q02;
  lifecycle repair is never delayed by an entry-only gate.
- First-week-bar clock, synchronized timestamps, three consecutive week
  anchors, positive finite prices, strict sign opposition, strict smaller
  newest magnitude, durable attempt, side-specific trade mode, spread, quote,
  ATR, sizing, stop geometry, and notional match all fail closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, rolling center, fitted hedge ratio, or
  manual signal is read at runtime.

## 7. Trade Management Rules

- Own exactly one `XAUUSD.DWX` position under magic `410770000` and one
  opposite-side `XAGUSD.DWX` position under magic `410770001`.
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
| `strategy_history_bars_d1` | 30 | bounded week-end buffer |
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
source supplies the weekly horizon or partial-retracement continuation.

## QM Interpretations

`SCHWEIKERT-CME-XAUXAG-WRETR-RV-2026_S01` fixes the exact weekly endpoint
construction, two-return count, strict state, newest-return sides, continuous-
CFD clock, durable attempt, equal-notional aggregate risk, spread caps, stops,
and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. The companion magic is registered as a foreign owned
magic. No live execution override exists.

## Exit Precedence

1. Broker hard stops and framework kill switch.
2. Malformed or unsafe owned-package repair.
3. Later broker-week closure.
4. Ten-calendar-day stale repair.

## Runtime Data Dependencies

Exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX` native D1 timestamps and
closes, broker time, symbol metadata, quotes, completed-bar ATR, framework
position/deal state, and persistent terminal global-variable attempt state.
No finite external dataset or calendar exists.

## Risk

- Backtest only: aggregate-package `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data on each leg.
- Combined normalized stop risk may not exceed one fixed-risk budget.
- No target and no signal-strength sizing.
- Major risks are non-convergence, one-leg fills, stop-risk asymmetry, lot-step
  notional mismatch, gold/silver beta drift, week-end gaps, continuous-CFD
  basis, financing, spread, density below the floor, source translation, and
  realized overlap with the XAU book.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, wrong or
asynchronous week endpoints, nonconsecutive anchors, overlapping return
intervals, current-week leakage, same signs, zero, equality, or non-smaller
newest move at entry, wrong newest-return side, duplicate attempt, one-leg
survivor, aggregate-risk breach, notional mismatch above 20 percent, missing
hard stop, wrong next-week exit, nondeterminism, or invalid fixed-risk mode.

Changing the carrier, endpoint count, weekly horizon, sign or magnitude
condition, direction, attempt clock, risk, stop, or lifecycle requires a new
identity, binary, complete stream reconciliation, and portfolio
requalification. A failed result may not be rescued by adding a return
threshold, fitted center, beta, calendar, trend, or volatility filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, synchronized weeks, returns, state, side, attempt, spreads, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers and basket order helper |
| orphan/notional, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus package lifecycle helper |
| survivor and next-week repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, aggregate fixed-risk mode | Framework No-Trade | standard framework orchestration plus foreign-magic registration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove exact synchronized first-week-bar handling; Monday anchors
across year boundaries; three consecutive completed week ends; chronological
non-overlapping relative returns; both strict opposite-sign smaller-newest
directions; same signs, zero, equality, and larger-newest flat states; no
current-bar leakage; persistent weekly attempts; equal-notional down-rounding;
aggregate fixed-risk sizing; atomic broken-package repair; next-week and stale
exits; card lint; strict compile; setfile schema; basket manifest; resolver
identity; and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-21 | initial completed-week XAU/XAG partial-retracement continuation card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-21 | APPROVED | `decisions/2026-08-21_qm5_41077_xauxag_weekly_partial_retracement_continuation_g0.md` |
| Q01 Build Validation | 2026-08-21 | PENDING | active basket magic allocation required before build |
| Q02 Baseline Screening | 2026-08-21 | NOT_ENQUEUED | paced capacity preflight required after Q01 PASS |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one logical
D1 `RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only
below tester and CPU ceilings. It does not authorize a manual backtest,
terminal control, live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio-gate change, portfolio
admission, decorrelation claim, neutrality claim, or correlation waiver.

