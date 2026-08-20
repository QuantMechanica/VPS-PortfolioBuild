---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-WSTREAK3-RV-2026_S01
variant_id: SCHWEIKERT-CME-XAUXAG-WSTREAK3-RV-2026_S01
source_id: SCHWEIKERT-CME-XAUXAG-WSTREAK3-RV-2026
ea_id: QM5_41078
slug: xauxag-wstreak3-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41078_xauxag-wstreak3-rv_card.md
execution_contract_status: DRAFT
created: 2026-08-21
created_by: Research+Development
last_updated: 2026-08-21
g0_status: APPROVED
g0_decision: decisions/2026-08-21_qm5_41078_xauxag_weekly_sign_streak_reversion_g0.md
source_approval: decisions/2026-08-21_xauxag_weekly_sign_streak_reversion_source_approval.md
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; Yaya, Vo, and Olayinka (2021), Resources Policy 72, 102045, DOI 10.1016/j.resourpol.2021.102045; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete-read governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md; bounded extraction strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WSTREAK3-RV-2026/source.md"
    quality_tier: A
    role: primary_state_dependent_long_run_relation
  - type: exchange_education
    citation: "CME Group, Gold & Silver Ratio Spread."
    location: "Governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: A
    role: gold_silver_ratio_intermarket_carrier
strategy_mechanic: synchronized-five-completed-week-xau-minus-xag-endpoints-fresh-three-same-sign-relative-return-streak-after-opposite-predecessor-fade-one-week-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-CME-XAUXAG-WSTREAK3-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/fresh-weekly-sign-streak-reversion]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-week-relative-log-return-sign]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, gold-silver-ratio, relative-value-basket, fresh-weekly-sign-streak, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41078_XAU_XAG_WSTREAK3_RV_D1
symbol: QM5_41078_XAU_XAG_WSTREAK3_RV_D1
host_symbol: XAUUSD.DWX
companion_symbol: XAGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [410780000, 410780001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately five to nine completed paired packages per full post-warm-up year after exact synchronized weeks, strict fresh-streak state, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_STREAK_REVERSION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: G0_APPROVED_BUILD_PENDING
q01_status: NOT_BUILT
q02_status: NOT_ENQUEUED
review_focus: "Falsify a fresh three-completed-week gold/silver relative-return streak fade outside the certified XAU/SP500/NDX/XNG book. Verify synchronized completed week ends, chronological relative returns, strict -+++ or +--- state, contrarian sides, durable weekly attempt, aggregate fixed risk, atomic basket repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xau_xag_carrier, synchronized_week_endpoints, consecutive_monday_anchors, bounded_week_session_counts, chronological_relative_returns, strict_fresh_three_week_sign_streak, contrarian_package_direction, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses one bounded child source with named peer-reviewed DOI and official exchange lineages while disclosing the fresh weekly sign-streak fade as an untested QM translation; R2 locks exact synchronized weeks, chronological relative returns, strict fresh -+++ or +--- state, contrarian side, durable attempt, aggregate fixed risk, equal notional, hard stops, spreads, and next-week lifecycle; R3 uses registered native XAU/XAG D1 histories with synchronization and CFD-basis risks explicit and requires active slots 0/1 before build; R4 is deterministic timestamp, price, logarithm, ATR, quote, position, deal, and terminal-state arithmetic without a banned signal, trained output, external feed, grid, or martingale; canonical dedup and manual family review found no exact identity."
---

# QM5_41078 XAU/XAG Fresh Three-Week Sign-Streak Reversion

## Hypothesis

The first completion of three consecutive same-direction broker-week moves in
the gold/silver log ratio after an opposite week may mark a short-lived
relative displacement. Fading that fresh streak for one broker week may
capture reversion in the intermetal relation without taking an outright
single-metal signal.

The candidate is one logical two-leg relative-value package intended to add a
different return driver outside the certified XAU/SP500/NDX/XNG book. Equal
notional and opposite legs are execution targets, not proof of beta, factor,
market, volatility, or portfolio neutrality. Q02 owns density and economics;
unchanged Q09 alone may establish realized book correlation.

## Source Traceability And Claim Boundary

The approved source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WSTREAK3-RV-2026/source.md`,
authorized before card extraction in
`decisions/2026-08-21_xauxag_weekly_sign_streak_reversion_source_approval.md`
at commit `83ec155ac`.

Schweikert supplies named peer-reviewed evidence for a potentially state-
dependent gold/silver relationship. CME defines the gold/silver ratio and
supports treating the instruments as one intermarket spread carrier. Neither
source tests a fresh three-week sign streak, its contrarian direction, a
continuous-CFD package, equal-notional sizing, fixed cash risk, ATR stops, or
a one-week hold.

No source return, profit factor, risk-adjusted return, drawdown, trade count,
transaction cost, hedge ratio, threshold, CFD equivalence, neutrality, or
portfolio-correlation statistic transfers. Every implementation choice below
is a pre-result QM falsification choice.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,565 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual semantic
review fixes the boundaries:

- `QM5_20275_gsr-runfade` requires five newest same-sign D1 relative returns,
  a sixth-return break, and a first-counter-return exit. This card aggregates
  exactly three completed broker weeks after an opposite predecessor and uses
  a fixed one-week hold.
- `QM5_41066_xauxag-wdecay-rv`, `QM5_41075_xauxag-wovershoot-rv`,
  `QM5_41076_xauxag-waccel-rv`, and `QM5_41077_xauxag-wretr-rv` classify only
  two adjacent completed-week relative returns by sign and magnitude. This
  card requires four returns and ignores every magnitude.
- `QM5_41060_xauxag-week-nr7-brk` follows a weekly-range breakout, while
  `QM5_41062_xauxag-wgap-fade` uses current Monday opens versus prior Friday
  closes. This card reads only five completed week-end close pairs.
- `QM5_41074_wti-wstreak3-mom` uses the same fresh weekly sign-path topology
  on one outright WTI leg but follows the streak. This card fades the streak
  through an opposite-leg XAU/XAG package, so carrier, direction, ownership,
  aggregate risk, and lifecycle repair differ.
- `QM5_20157`, `QM5_20161`, `QM5_20263`, `QM5_20265`, and `QM5_20268` use a
  rolling center, fitted residual, robust score, channel, or empirical tail.
  This card estimates none.
- Monthly cross-sectional ranks, calendar systems, flow decompositions, and
  variance-ratio systems do not use the exact fresh completed-week sign path.
- `QM5_12533` supplies the validated logical-basket manifest/order recipe but
  its signal is an EURJPY/GBPJPY cointegration spread.
- `QM5_12567_cum-rsi2-commodity` is a single-symbol long-only two-day
  oscillator pullback and has no intermetal, weekly, or paired logic.

The exact XAU/XAG carrier, five synchronized week ends, four chronological
relative returns, strict `-+++` or `+---` state, contrarian package, durable
weekly attempt, equal-notional aggregate-risk package, and next-week exit are
jointly load-bearing. Verdict:
`CLEAN_XAUXAG_FRESH_THREE_WEEK_SIGN_STREAK_REVERSION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host: `XAUUSD.DWX`, D1, slot 0, intended magic `410780000`.
- Exact companion: `XAGUSD.DWX`, D1, slot 1, intended magic `410780001`.
- Logical symbol: `QM5_41078_XAU_XAG_WSTREAK3_RV_D1`.
- Formation: five consecutive synchronized completed broker-week-end pairs.
- Decision: first tradable bar of a new Monday-anchored broker week, within
  180 elapsed raw-session minutes.
- Signal: strict fresh three-week same-sign relative-return streak after a
  strict opposite predecessor; fade the newest streak direction.
- Ordinary exit: first tick whose broker Monday anchor is later than the
  package-open anchor.
- Expected cadence: five to nine completed packages/year; retire below five.
- Q02 risk: aggregate-package `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let pair 0 be the newest completed synchronized week-end closes and pair 4 the
oldest. Define:

```text
s0 = ln(XAU_0) - ln(XAG_0)
s1 = ln(XAU_1) - ln(XAG_1)
s2 = ln(XAU_2) - ln(XAG_2)
s3 = ln(XAU_3) - ln(XAG_3)
s4 = ln(XAU_4) - ln(XAG_4)

r0 = s0 - s1
r1 = s1 - s2
r2 = s2 - s3
r3 = s3 - s4

r0 > 0 and r1 > 0 and r2 > 0 and r3 < 0
    => SELL XAU, BUY XAG
r0 < 0 and r1 < 0 and r2 < 0 and r3 > 0
    => BUY XAU, SELL XAG
otherwise
    => FLAT
```

All endpoints complete before the decision week begins. The current D1 open,
high, low, or close never enters a return. Strict zero breaks the streak and
remains flat. Return magnitude never changes signal or risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XAUUSD.DWX` D1 bar under EA 41078 and
   host magic slot zero.
2. Repair malformed, orphaned, duplicated, same-side, stopless, notional-
   invalid, later-week, or stale owned exposure before entry-only gates.
3. Require exact host D1 and companion D1 timestamps. Derive the current
   Monday anchor from broker time and prove the current bar is the first
   tradable D1 bar carrying that new anchor. Reject attachment later than 180
   elapsed minutes after the raw host bar open.
4. Persist the current Monday anchor attempt before history, signal, spread,
   quote, ATR, sizing, news, or order gates. Never retry that week.
5. Within a fixed 50-bar buffer, select the newest synchronized positive
   finite close pair belonging to each distinct prior Monday anchor. Require
   exactly the latest five anchors to be current anchor minus 7, 14, 21, 28,
   and 35 calendar days in strict reverse-time order. Require three to five
   synchronized completed D1 sessions in every contributing week.
6. Compute `s0..s4` and `r0..r3` exactly as specified. Require every return to
   be finite and non-zero. Qualify only strict `r0,r1,r2>0` with `r3<0`, or
   strict `r0,r1,r2<0` with `r3>0`. Every other state remains flat.
7. SELL XAU/BUY XAG for a fresh positive streak. BUY XAU/SELL XAG for a fresh
   negative streak. Signal magnitude never changes risk.
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

- Exact host, D1, EA 41078, slot zero, and both registered magics.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes, legacy news mode, and Friday close are OFF for Q02;
  lifecycle repair is never delayed by an entry-only gate.
- First-week-bar clock, synchronized timestamps, five consecutive week
  anchors, bounded weekly session counts, positive finite prices, strict
  fresh-streak signs, durable attempt, side-specific trade mode, spread,
  quote, ATR, sizing, stop geometry, and notional match all fail closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, rolling center, fitted hedge ratio, or
  manual signal is read at runtime.

## 7. Trade Management Rules

- Own exactly one `XAUUSD.DWX` position under intended magic `410780000` and
  one opposite-side `XAGUSD.DWX` position under intended magic `410780001`.
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
| `strategy_history_bars_d1` | 50 | bounded week-end buffer |
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
source supplies the weekly horizon or fresh sign-streak fade.

## QM Interpretations

`SCHWEIKERT-CME-XAUXAG-WSTREAK3-RV-2026_S01` fixes the exact weekly endpoint
construction, strict fresh sign path, contrarian sides, continuous-CFD clock,
durable attempt, equal-notional aggregate risk, spread caps, stops, and
lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. The companion magic is registered as a foreign owned
magic after governed allocation. No live execution override exists.

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
- Major risks are non-convergence, relative streak persistence, one-leg fills,
  stop-risk asymmetry, lot-step notional mismatch, gold/silver beta drift,
  week-end gaps, continuous-CFD basis, financing, spread, density below the
  floor, source translation, and realized overlap with the XAU book.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, wrong or
asynchronous week endpoints, nonconsecutive anchors, invalid weekly session
counts, current-week leakage, any zero or wrong sign in the strict fresh
streak, wrong contrarian side, duplicate attempt, one-leg survivor, aggregate-
risk breach, notional mismatch above 20 percent, missing hard stop, wrong
next-week exit, nondeterminism, or invalid fixed-risk mode.

Changing the carrier, endpoint count, streak length, predecessor rule,
direction, attempt clock, risk, stop, or lifecycle requires a new identity,
binary, complete stream reconciliation, and portfolio requalification. A
failed result may not be rescued by adding a return threshold, fitted center,
beta, calendar, trend, magnitude, or volatility filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, synchronized weeks, returns, strict path, side, attempt, spreads, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers and basket order helper |
| orphan/notional, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus package lifecycle helper |
| survivor and next-week repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, aggregate fixed-risk mode | Framework No-Trade | standard framework orchestration plus foreign-magic registration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove exact synchronized first-week-bar handling; Monday anchors
across year boundaries; five consecutive completed week ends; three-to-five
session bounds; chronological non-overlapping relative returns; both strict
fresh-streak directions; zero, continuing streak, early break, and mixed-sign
flat states; no current-bar leakage; persistent weekly attempts; equal-
notional down-rounding; aggregate fixed-risk sizing; atomic broken-package
repair; next-week and stale exits; card lint; strict compile; setfile schema;
basket manifest; resolver identity; and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-21 | initial XAU/XAG fresh three-week sign-streak reversion card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-21 | APPROVED | `decisions/2026-08-21_qm5_41078_xauxag_weekly_sign_streak_reversion_g0.md` |
| Q01 Build Validation | 2026-08-21 | NOT_BUILT | active magics and implementation required |
| Q02 Baseline Screening | 2026-08-21 | NOT_ENQUEUED | Q01 PASS and paced capacity preflight required |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one logical
D1 `RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only
below tester and CPU ceilings. It does not authorize a manual backtest,
terminal control, live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio-gate change, portfolio
admission, decorrelation claim, neutrality claim, or correlation waiver.
