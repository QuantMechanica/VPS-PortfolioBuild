---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-WCLOSE-EXTREME-RV-2026_S01
variant_id: SCHWEIKERT-CME-XAUXAG-WCLOSE-EXTREME-RV-2026_S01
source_id: SCHWEIKERT-CME-XAUXAG-WCLOSE-EXTREME-RV-2026
ea_id: QM5_41079
slug: xauxag-wclose-extreme-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41079_xauxag-wclose-extreme-rv_card.md
execution_contract_status: DRAFT
created: 2026-08-21
created_by: Research+Development
last_updated: 2026-08-21
g0_status: APPROVED
g0_decision: decisions/2026-08-21_qm5_41079_xauxag_weekly_closing_extreme_reversion_g0.md
source_approval: decisions/2026-08-21_xauxag_weekly_closing_extreme_reversion_source_approval.md
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; Yaya, Vo, and Olayinka (2021), Resources Policy 72, 102045, DOI 10.1016/j.resourpol.2021.102045; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete-read governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md; bounded extraction strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WCLOSE-EXTREME-RV-2026/source.md"
    quality_tier: A
    role: primary_state_dependent_long_run_relation
  - type: exchange_education
    citation: "CME Group, Gold & Silver Ratio Spread."
    location: "Governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: A
    role: gold_silver_ratio_intermarket_carrier
strategy_mechanic: synchronized-immediately-completed-broker-week-three-to-five-d1-gold-minus-silver-log-ratio-closes-strict-newest-within-week-extreme-fade-one-week-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-CME-XAUXAG-WCLOSE-EXTREME-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/completed-week-closing-extreme-reversion]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/within-week-relative-close-rank]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, gold-silver-ratio, relative-value-basket, completed-week-closing-extreme, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41079_XAU_XAG_WCLOSE_EXTREME_RV_D1
symbol: QM5_41079_XAU_XAG_WCLOSE_EXTREME_RV_D1
host_symbol: XAUUSD.DWX
companion_symbol: XAGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [410790000, 410790001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately fifteen to twenty-five completed paired packages per full post-warm-up year after exact synchronized weeks, strict newest closing-rank, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 18
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_CLOSING_EXTREME_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01_PASS
q01_status: PASS
q02_status: NOT_ENQUEUED
review_focus: "Falsify a completed-week gold/silver within-week closing-extreme fade outside the certified XAU/SP500/NDX/XNG book. Verify exact prior-week membership, synchronized three-to-five-session close pairs, oldest-to-newest ordering, strict newest upper/lower rank, contrarian sides, durable weekly attempt, aggregate fixed risk, atomic basket repair, and next-week lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xau_xag_carrier, immediately_preceding_monday_anchor, synchronized_completed_d1_closes, three_to_five_week_sessions, chronological_close_order, strict_newest_within_week_ratio_extreme, contrarian_package_direction, persistent_week_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_week_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 uses one bounded child source with named peer-reviewed DOI and official exchange lineages while disclosing the completed-week closing-extreme fade as an untested QM translation; R2 locks exact synchronized prior-week sessions, chronological log ratios, strict newest rank, contrarian side, durable attempt, aggregate fixed risk, equal notional, hard stops, spreads, and next-week lifecycle; R3 uses registered native XAU/XAG D1 histories with synchronization and CFD-basis risks explicit and requires active slots 0/1 before build; R4 is deterministic timestamp, price, logarithm, comparison, ATR, quote, position, deal, and terminal-state arithmetic without a banned signal, trained output, external feed, grid, or martingale; canonical dedup and manual family review found no exact identity."
---

# QM5_41079 XAU/XAG Completed-Week Closing-Extreme Reversion

## Hypothesis

When the final synchronized gold/silver log-ratio close of a completed broker
week is strictly above or below every earlier synchronized ratio close in that
same week, the relative move may be temporarily extended. Fading that closing
extreme for one broker week may capture reversion in the intermetal relation
without taking an outright single-metal signal.

The candidate is one logical two-leg relative-value package intended to add a
different return driver outside the certified XAU/SP500/NDX/XNG book. Equal
notional and opposite legs are execution targets, not proof of beta, factor,
market, volatility, or portfolio neutrality. Q02 owns density and economics;
unchanged Q09 alone may establish realized book correlation.

## Source Traceability And Claim Boundary

The approved source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WCLOSE-EXTREME-RV-2026/source.md`,
authorized before card extraction in
`decisions/2026-08-21_xauxag_weekly_closing_extreme_reversion_source_approval.md`
at commit `37d65f4e0`.

Schweikert supplies named peer-reviewed evidence for a potentially state-
dependent gold/silver relationship. CME defines the gold/silver ratio and
supports treating the instruments as one intermarket spread carrier. Neither
source tests a within-week closing rank, its contrarian direction, a
continuous-CFD package, equal-notional sizing, fixed cash risk, ATR stops, or
a one-week hold.

No source return, profit factor, risk-adjusted return, drawdown, trade count,
transaction cost, hedge ratio, threshold, CFD equivalence, neutrality, or
portfolio-correlation statistic transfers. Every implementation choice below
is a pre-result QM falsification choice.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,566 registry rows and 625 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual semantic
review fixes the boundaries:

- `QM5_12577`, `QM5_20157`, `QM5_20161`, `QM5_20263`, and `QM5_20268` use a
  rolling center, fitted residual, robust score, or empirical tail. This card
  estimates none and ranks only the synchronized closes inside one completed
  broker week.
- `QM5_20265_gsr-fail-rv` requires an outside-to-inside daily channel failure;
  this card requires no channel crossing or return-inside event.
- `QM5_20275_gsr-runfade` requires five same-sign D1 relative returns after a
  break and exits on a counter-return. This card ignores the intervening
  return-sign path and holds for one fixed broker week.
- `QM5_41060_xauxag-week-nr7-brk` compares seven completed weekly ranges and
  follows a fresh next-week breakout. This card compares only daily close
  levels inside the immediately completed week and fades its final rank.
- `QM5_41066_xauxag-wdecay-rv`, `QM5_41075_xauxag-wovershoot-rv`,
  `QM5_41076_xauxag-waccel-rv`, `QM5_41077_xauxag-wretr-rv`, and
  `QM5_41078_xauxag-wstreak3-rv` classify completed-week returns by sign,
  magnitude, or streak topology. This card requires no prior-week endpoint.
- Weekly/monthly flow decompositions, weekend gaps, calendar systems,
  cross-sectional ranks, moment ranks, and variance-ratio systems do not use
  this exact within-week closing-rank state.
- `QM5_12533` supplies the validated logical-basket manifest/order recipe but
  its signal is an EURJPY/GBPJPY cointegration spread.
- `QM5_12567_cum-rsi2-commodity` is a single-symbol long-only two-day
  oscillator pullback and has no intermetal, weekly, or paired logic.

The exact XAU/XAG carrier, immediately preceding broker week, complete
synchronized three-to-five-session close set, strict newest upper/lower ratio
rank, contrarian package, durable weekly attempt, equal-notional aggregate-
risk package, and next-week exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_WEEK_CLOSING_EXTREME_REVERSION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host: `XAUUSD.DWX`, D1, slot 0, active magic `410790000`.
- Exact companion: `XAGUSD.DWX`, D1, slot 1, active magic `410790001`.
- Logical symbol: `QM5_41079_XAU_XAG_WCLOSE_EXTREME_RV_D1`.
- Formation: every synchronized completed D1 close pair belonging to the
  immediately preceding Monday-anchored broker week.
- Decision: first tradable bar of a new Monday-anchored broker week, within
  180 elapsed raw-session minutes.
- Signal: newest completed-week ratio close is strictly above or strictly
  below every earlier synchronized ratio close in that week; fade the extreme.
- Ordinary exit: first tick whose broker Monday anchor is later than the
  package-open anchor.
- Expected cadence: fifteen to twenty-five completed packages/year; retire
  below five.
- Q02 risk: aggregate-package `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let the immediately completed broker week contain `n` synchronized positive
finite D1 close pairs ordered oldest to newest, with `3 <= n <= 5`. Define:

```text
s[i] = ln(XAU_close[i]) - ln(XAG_close[i]), i=0..n-1

s[n-1] > s[i] for every i=0..n-2
    => SELL XAU, BUY XAG
s[n-1] < s[i] for every i=0..n-2
    => BUY XAU, SELL XAG
otherwise
    => FLAT
```

All endpoints complete before the decision week begins. The current D1 open,
high, low, or close never enters the rank. Only close ratios are compared;
intraday highs and lows are excluded. Equality is flat. Distance from the
earlier closes never changes signal or risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XAUUSD.DWX` D1 bar under EA 41079 and
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
   close pair whose Monday anchor equals current anchor minus seven calendar
   days. Require exactly three to five pairs, identical timestamps across
   legs, unique strictly increasing timestamps, and no pair from another
   anchor.
6. Order the ratios oldest to newest and require the newest ratio to be
   strictly greater than every earlier ratio or strictly less than every one.
   Any equality, interior close, invalid arithmetic, missing session, or more
   than five sessions remains flat.
7. SELL XAU/BUY XAG for a strict upper closing extreme. BUY XAU/SELL XAG for
   a strict lower closing extreme. Rank distance never changes risk.
8. Require no owned exposure, no same-magic entry deal already recorded in the
   current broker week, executable side-specific quotes, and no genuinely
   positive spread wider than 1,500 XAU points or 500 XAG points. Modeled
   zero `.DWX` spread is valid.
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

- Exact host, D1, EA 41079, slot zero, and both governed magics.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes, legacy news mode, and Friday close are OFF for Q02;
  lifecycle repair is never delayed by an entry-only gate.
- First-week-bar clock, exact prior anchor, synchronized timestamps, three-to-
  five session count, unique chronological endpoints, positive finite prices,
  strict newest rank, durable attempt, side-specific trade mode, spread,
  quote, ATR, sizing, stop geometry, and notional match all fail closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, rolling center, fitted hedge ratio, or
  manual signal is read at runtime.

## 7. Trade Management Rules

- Own exactly one `XAUUSD.DWX` position under active magic `410790000` and
  one opposite-side `XAGUSD.DWX` position under active magic `410790001`.
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
source supplies the within-week closing-rank state or one-week fade.

## QM Interpretations

`SCHWEIKERT-CME-XAUXAG-WCLOSE-EXTREME-RV-2026_S01` fixes the exact prior-week
session set, strict newest rank, contrarian sides, continuous-CFD clock,
durable attempt, equal-notional aggregate risk, spread caps, stops, and
lifecycle.

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
- Major risks are non-convergence, repeated weekly extremes during a relative
  trend, one-leg fills, stop-risk asymmetry, lot-step notional mismatch,
  gold/silver beta drift, week-end gaps, continuous-CFD basis, financing,
  spread, density below the floor, source translation, and realized overlap
  with the XAU book.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, wrong or
asynchronous prior-week timestamps, invalid session count, current-week
leakage, accepting an equality or interior newest ratio, wrong contrarian
side, duplicate attempt, one-leg survivor, aggregate-risk breach, notional
mismatch above 20 percent, missing hard stop, wrong next-week exit,
nondeterminism, or invalid fixed-risk mode.

Changing the carrier, week definition, session bounds, rank rule, direction,
attempt clock, risk, stop, or lifecycle requires a new identity, binary,
complete stream reconciliation, and portfolio requalification. A failed
result may not be rescued by adding a distance threshold, fitted center, beta,
calendar, trend, magnitude, or volatility filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, prior-week sessions, ratios, strict rank, side, attempt, spreads, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers and basket order helper |
| orphan/notional, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus package lifecycle helper |
| survivor and next-week repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, aggregate fixed-risk mode | Framework No-Trade | standard framework orchestration plus foreign-magic registration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove exact synchronized first-week-bar handling; Monday anchors
across year boundaries; immediately prior anchor selection; three-, four-, and
five-session holiday/ordinary weeks; chronological daily ratio ordering;
strict upper and lower newest ranks; equality, interior close, invalid price,
duplicate timestamp, and asynchronous flat states; no current-bar leakage;
persistent weekly attempts; equal-notional down-rounding; aggregate fixed-risk
sizing; atomic broken-package repair; next-week and stale exits; card lint;
strict compile; setfile schema; basket manifest; resolver identity; and static
artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-21 | initial XAU/XAG completed-week closing-extreme reversion card | G0 | APPROVED |
| v1-build | 2026-08-21 | paired V5 implementation, 10-test reference suite, strict compile/build checks, and static artifact validation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-21 | APPROVED | `decisions/2026-08-21_qm5_41079_xauxag_weekly_closing_extreme_reversion_g0.md` |
| Q01 Build Validation | 2026-08-21 | PASS | `D:/QM/reports/framework/21/build_check_20260821_003146.json`; `D:/QM/reports/pipeline/QM5_41079/P1/P1_QM5_41079_result.json` |
| Q02 Baseline Screening | TBD | NOT_ENQUEUED | Q01 PASS and paced capacity preflight required |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one logical
D1 `RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only
below tester and CPU ceilings. It does not authorize a manual backtest,
terminal control, live/demo/shadow/stress/optimization preset, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio-gate change, portfolio
admission, decorrelation claim, neutrality claim, or correlation waiver.
