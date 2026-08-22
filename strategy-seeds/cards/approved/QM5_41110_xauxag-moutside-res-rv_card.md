---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-MOUTSIDE-RES-RV-2026_S01
variant_id: SCHWEIKERT-CME-XAUXAG-MOUTSIDE-RES-RV-2026_S01
source_id: SCHWEIKERT-CME-XAUXAG-MOUTSIDE-RES-RV-2026
ea_id: QM5_41110
slug: xauxag-moutside-res-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41110_xauxag-moutside-res-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-22
created_by: Research+Development
last_updated: 2026-08-22
g0_status: APPROVED
g0_decision: decisions/2026-08-22_qm5_41110_xauxag_monthly_outside_range_residence_reversion_g0.md
source_approval: decisions/2026-08-22_xauxag_monthly_outside_range_residence_reversion_source_approval.md
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; supporting carrier definition from CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete-read governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md; bounded extraction strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MOUTSIDE-RES-RV-2026/source.md"
    quality_tier: A
    role: primary_state_dependent_long_run_relation
  - type: exchange_education
    citation: "CME Group, Gold & Silver Ratio Spread."
    location: "Governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: A
    role: supporting_intermarket_carrier_definition
strategy_mechanic: synchronized-two-consecutive-completed-calendar-month-daily-close-log-ratio-parent-range-persistent-one-sided-outside-residence-final-close-confirmation-fade-next-month-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-CME-XAUXAG-MOUTSIDE-RES-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/completed-month-outside-range-residence]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-month-parent-ratio-range]]"
  - "[[indicators/outside-boundary-session-count]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, gold-silver-ratio, relative-value-basket, completed-month-outside-range-residence, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41110_XAU_XAG_MOUTSIDE_RES_RV_D1
symbol: QM5_41110_XAU_XAG_MOUTSIDE_RES_RV_D1
host_symbol: XAUUSD.DWX
companion_symbol: XAGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [411100000, 411100001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately five to nine completed paired packages per full post-warm-up year after two exact synchronized completed-month packages, five one-sided outside closes, no opposite breach, and final-close persistence; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_MONTHLY_OUTSIDE_RANGE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a completed-month gold/silver ratio persistent outside-parent-range fade outside the certified XAU/SP500/NDX/XNG book. Verify exact adjacent-month membership, 17-23 synchronized sessions per month, fixed unit log ratio, parent range, five one-sided outside closes, zero opposite breach, final close still outside, contrarian paired sides, durable monthly attempt, aggregate fixed risk, atomic basket repair, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xau_xag_carrier, first_tradable_month_bar, consecutive_calendar_months, synchronized_completed_d1_closes, bounded_month_session_counts, fixed_unit_log_ratio, parent_ratio_range, five_outside_sessions, zero_opposite_breach, final_close_still_outside, equality_inside, contrarian_ratio_direction, persistent_month_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_month_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 PASS_WITH_TRANSLATION_RISK peer-reviewed DOI plus official CME carrier; R2 PASS locked synchronized months, parent range, outside residence, attempt, risk and lifecycle; R3 PASS native XAU/XAG D1 with Q02 basis risk; R4 PASS deterministic native arithmetic, no banned or external runtime signal."
---

# QM5_41110 XAU/XAG Completed-Month Outside-Range Residence Reversion

## Hypothesis

When the gold/silver daily-close ratio spends at least five sessions beyond
one side of the immediately preceding month's complete observed ratio range,
never breaches the opposite side, and ends the month still outside, the state
is a persistent relative-value displacement rather than one isolated print.
Fading an upper displacement by selling gold and buying silver, or fading a
lower displacement with the opposite package, for the next broker month may
capture re-convergence in the metals' state-dependent long-run relationship
without taking one outright directional signal.

The candidate is one logical two-leg relative-value package intended to add a
different return driver outside the certified XAU/SP500/NDX/XNG book. Equal
notional and opposite legs are execution targets, not proof of beta, factor,
market, volatility, or portfolio neutrality. Q02 owns density and economics;
unchanged Q09 alone may establish realized book correlation.

## Source Traceability And Claim Boundary

The approved source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MOUTSIDE-RES-RV-2026/source.md`,
authorized before extraction in
`decisions/2026-08-22_xauxag_monthly_outside_range_residence_reversion_source_approval.md`
at commit `58523766b`. The bounded extraction was committed at `7df05e3f7`.

Schweikert supplies named peer-reviewed evidence for a potentially state-
dependent gold/silver relation. CME defines the gold/silver ratio and supports
treating the instruments as one intermarket spread carrier. Neither source
tests completed-month parent ranges, outside-range residence, a five-session
floor, the no-opposite-breach or final-close conditions, the contrarian side,
a continuous-CFD package, equal-notional sizing, fixed cash risk, ATR stops,
or a one-month hold.

No source return, profit factor, risk-adjusted return, drawdown, trade count,
transaction cost, hedge ratio, residence rule, CFD equivalence, neutrality,
or portfolio-correlation statistic transfers. Every implementation choice
below is a pre-result QM falsification choice.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,599 registry rows and 1,278
repository cards and found no exact or fuzzy match. Its default optional Wiki
path was unavailable and the receipt therefore failed closed. After allocation,
the checker used the governed Company Reference Wiki path, scanned 4,600
registry rows, 1,278 cards, and 45 Wiki nodes, and returned only the expected
slug and strategy-ID self-hits for `QM5_41110`. Receipts:

- `artifacts/qm5_xauxag_moutside_res_rv_preallocation_dedup_20260822.json`;
- `artifacts/qm5_41110_xauxag_moutside_res_rv_postallocation_dedup_20260822.json`.

Manual semantic review fixes the boundaries:

- `QM5_20157_xau-xag-ratio` fades a rolling 60-day ratio z-score and exits at
  a rolling center. This card estimates neither center nor scale.
- `QM5_20161_xauxag-ols-rv` fits a rolling OLS residual and hedge coefficient.
  This card fits no parameter and uses one fixed unit log ratio.
- `QM5_20254_xauxag-vr-fade` gates a daily ratio z-score with a robust monthly
  variance-ratio statistic. This card uses neither statistic.
- `QM5_41079_xauxag-wclose-extreme-rv` ranks one final weekly ratio close
  inside the same week's range. This card counts many closes beyond a separate
  parent calendar-month range.
- `QM5_41085_xauxag-wdaybreadth-rv` counts adjacent daily relative-return
  signs in one week. This card counts ratio levels beyond fixed boundaries.
- `QM5_41103_xauxag-mrange-migrate-rv` compares both newest range endpoints
  with both parent endpoints. This card does not require endpoint migration;
  it requires at least five actual outside observations, no opposite breach,
  and a still-outside final close.
- `QM5_41104_xauxag-mmedian-shift-rv` compares two monthly medians. This card
  computes no median and uses fixed parent-range boundaries.
- `QM5_41109_xauxag-mmean-median-rv` compares mean with median inside one
  month. This card uses two months and computes neither statistic.
- `QM5_41093_wti-wclose-breakout-mom` follows one final direct-WTI weekly
  close outside a parent range. This card fades persistent monthly residence
  of a two-leg metals ratio.
- `QM5_12533` supplies the validated logical-basket manifest/order recipe but
  its signal is an EURJPY/GBPJPY rolling cointegration spread.
- certified `QM5_12567_cum-rsi2-commodity` is a single-symbol long-only
  two-day XNG oscillator pullback and has no intermetal, monthly, or paired
  logic.

The exact XAU/XAG carrier, two synchronized completed calendar months, fixed
unit daily-close log ratio, parent observed range, at least five newest-month
closes beyond exactly one boundary, no opposite boundary breach, final close
still outside, contrarian package, durable monthly attempt, equal-notional
aggregate-risk sizing, and next-month exit are jointly load-bearing. Verdict:
`NO_EXACT_XAUXAG_MONTHLY_OUTSIDE_RANGE_RESIDENCE_REVERSION_DUPLICATE_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Exact host: `XAUUSD.DWX`, D1, slot 0, planned magic `411100000`.
- Exact companion: `XAGUSD.DWX`, D1, slot 1, planned magic `411100001`.
- Logical symbol: `QM5_41110_XAU_XAG_MOUTSIDE_RES_RV_D1`.
- Formation: synchronized daily-close log ratios in each of the immediately
  preceding two complete broker-calendar months.
- Decision: first tradable D1 bar of a new broker-calendar month, within 180
  elapsed raw-session minutes.
- Signal: five or more newest-month closes beyond exactly one parent range
  boundary, zero opposite breach, and a final close still outside; fade it.
- Ordinary exit: first tick whose broker `yyyymm` is later than the package-
  open month.
- Expected cadence: five to nine completed packages/year; retire below five.
- Q02 risk: aggregate-package `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

For every synchronized completed D1 session `d`:

```text
r[d] = log(XAU_close[d]) - log(XAG_close[d])

P_hi = max(r[d]) in the parent completed calendar month
P_lo = min(r[d]) in the parent completed calendar month

A = count(r[d] > P_hi) in the newest completed calendar month
B = count(r[d] < P_lo) in the newest completed calendar month
F = r[d] on the chronologically final newest-month session

A >= 5 and B == 0 and F > P_hi
    => SELL XAU, BUY XAG

B >= 5 and A == 0 and F < P_lo
    => BUY XAU, SELL XAG

otherwise
    => FLAT
```

All signal inputs complete before the decision month begins. Equality with a
parent boundary is inside for count purposes and cannot satisfy final-close
persistence. Outside distance and count above five never change eligibility,
direction, or risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XAUUSD.DWX` D1 bar under EA 41110 and
   host magic slot zero.
2. Repair malformed, orphaned, duplicated, same-side, stopless, notional-
   invalid, later-month, or stale owned exposure before entry-only gates.
3. Require exact host and companion D1 timestamps. Derive current, immediately
   completed, and parent `yyyymm` values from broker time and prove the prior
   two are consecutive across year boundaries. Reject attachment later than
   180 elapsed minutes after the raw host-bar open.
4. Persist the current decision `yyyymm` attempt before history, signal,
   spread, quote, ATR, sizing, news, or order gates. Never retry that month.
5. Within a fixed 70-bar buffer, collect every positive finite synchronized
   close pair belonging to the immediately completed month and its parent.
   Require 17 through 23 unique, strictly ordered timestamp-identical sessions
   in each package and no current-month observation.
6. Compute `log(XAU close)-log(XAG close)` for each pair. Aggregate the parent
   month's strict minimum and maximum and require a finite positive range.
7. Count newest-month ratios strictly above the parent maximum and strictly
   below the parent minimum. Preserve the chronologically final newest-month
   ratio independently of array storage direction.
8. SELL XAU and BUY XAG only when the upper count is at least five, the lower
   count is zero, and the final ratio is strictly above the parent maximum.
   BUY XAU and SELL XAG only for the exact lower-side mirror. Equality, an
   opposite breach, fewer than five outside closes, or an inside final close
   remains flat.
9. Require no owned exposure, no same-magic entry deal already recorded in the
   current broker month, executable side-specific quotes, and no genuinely
   positive spread wider than 1,500 XAU points or 500 XAG points. Modeled zero
   `.DWX` spread is valid.
10. Require valid completed-bar `ATR(20,D1)` for both legs and attach one
    frozen hard stop at `3.5*ATR` on each. Size the package so combined
    normalized stop risk cannot exceed the single `RISK_FIXED=1000` budget.
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
3. Close both legs on the first tick whose broker `yyyymm` is later than the
   package-open `yyyymm`.
4. Close after forty elapsed calendar days as a final stale guard.
5. No Friday close, target, fitted-mean exit, signal reversal, trailing stop,
   break-even move, partial exit, discretionary close, or intentional hold
   beyond the next broker month is authorized.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41110, slot zero, and both governed magics.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes, legacy news mode, and Friday close are OFF for Q02;
  lifecycle repair is never delayed by an entry-only gate.
- First-month-bar clock, exact adjacent prior months, synchronized timestamps,
  17-to-23 session count per month, positive finite closes, positive parent
  ratio range, five one-sided outside observations, zero opposite breach,
  final close still outside, durable attempt, side-specific trade mode,
  spread, quote, ATR, sizing, stop geometry, and notional match all fail closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, rolling center, fitted hedge ratio, or
  manual signal is read at runtime.

## 7. Trade Management Rules

- Own exactly one `XAUUSD.DWX` position under active magic `411100000` and one
  opposite-side `XAGUSD.DWX` position under active magic `411100001`.
- Persist the last attempted decision `yyyymm` and package-open `yyyymm`
  across restart.
- Manage malformed, later-month, stale, and kill-switch exits on every tick
  before entry evaluation.
- Freeze both original hard stops; never widen, trail, or remove them.
- Do not retry, add, pyramid, grid, martingale, partially close, add a third
  hedge, or reverse inside the month.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_history_bars_d1` | 70 | bounded two-month buffer |
| `strategy_min_month_sessions` | 17 | complete-month lower bound |
| `strategy_max_month_sessions` | 23 | complete-month upper bound |
| `strategy_min_outside_sessions` | 5 | one-sided residence floor |
| `strategy_entry_grace_minutes` | 180 | first-month-bar window |
| `strategy_atr_period_d1` | 20 | completed-bar per-leg range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal absolute notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | lot-step mismatch ceiling |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_xau_max_spread_points` | 1500 | XAU cost guard |
| `strategy_xag_max_spread_points` | 500 | XAG cost guard |
| `strategy_deviation_points` | 20 | bounded market-order deviation |
| `qm_friday_close_enabled` | false | full-month identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive value |

## Source-Defined Rules

Schweikert supplies state-dependent gold/silver relationship lineage. CME
supplies the gold/silver ratio definition and relative-value carrier. Neither
source supplies completed-month parent ranges, outside-observation counts,
one-sidedness, final-close persistence, or a next-month fade.

## QM Interpretations

`SCHWEIKERT-CME-XAUXAG-MOUTSIDE-RES-RV-2026_S01` fixes the exact prior two
calendar months, synchronized daily-close log-ratio construction, parent
range, five-session outside residence floor, zero opposite breach, final-
close persistence, contrarian sides, continuous-CFD clock, durable attempt,
equal-notional aggregate risk, spread caps, stops, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. The companion magic must be registered as a foreign
owned magic before build. No live execution override exists.

## Exit Precedence

1. Broker hard stops and framework kill switch.
2. Malformed or unsafe owned-package repair.
3. Later broker-month closure.
4. Forty-calendar-day stale repair.

## Runtime Data Dependencies

Exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX` native D1 timestamps and
closes, broker time, symbol metadata, quotes, completed-bar ATR, framework
position/deal state, and persistent terminal global-variable attempt/package
state. No finite external dataset or calendar exists.

## Risk

- Backtest only: aggregate-package `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data on each leg.
- Combined normalized stop risk may not exceed one fixed-risk budget.
- No target and no signal-strength sizing.
- Major risks are non-convergence, persistent macro divergence, one-leg fills,
  stop-risk asymmetry, lot-step notional mismatch, gold/silver beta drift,
  month-end gaps, continuous-CFD basis, financing, spread, density below the
  floor, source translation, and realized overlap with the XAU book.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, wrong or
asynchronous prior-month timestamps, invalid session count, current-month
leakage, wrong parent range, accepting equality as outside, fewer than five
one-sided observations, an opposite breach, an inside final close, wrong
contrarian side, duplicate monthly attempt, unbounded combined risk, missing
stops, broken atomicity, or nondeterminism.

Requalification requires a new OWNER-approved card version before lowering
the residence floor, accepting an opposite breach or inside final close,
changing direction or hold, changing history/session bounds, fitting a center
or hedge ratio, or adding a return, volatility, volume, season, external-data,
or prior-result gate. No post-result parameter salvage is authorized.

## Framework Alignment

| Card rule | V5 owner | Implementation target |
|---|---|---|
| exact carrier, timeframe, input, and month lock | No-Trade | `Strategy_NoTradeFilter` and `OnInit` |
| synchronized months, ratio, parent range, counts, final close, sides, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus package helper |
| next-month and survivor repair | Trade Close | `Strategy_ExitSignal` plus package helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard V5 orchestration plus foreign-magic registration |

## R1-R4 Gate Record

- R1: `PASS_WITH_MONTHLY_OUTSIDE_RANGE_TRANSLATION_RISK`. Named peer-reviewed
  DOI and official exchange lineages support the carrier, while every residence
  rule is disclosed as untested.
- R2: `PASS`. Membership, synchronization, range, counts, strict conditions,
  side, attempt, risk, stops, spreads, and lifecycle are fully mechanical.
- R3: `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`. Registered native D1
  histories provide all runtime data; Q02 owns actual sufficiency and costs.
- R4: `PASS`. Native arithmetic and framework state only; no banned signal,
  external runtime feed, adaptive fit, grid, martingale, or pyramiding.

## Validation Plan

1. `skill_card_schema_lint.py` and `skill_g0_card_lint.py` must pass.
2. Deterministic registry and magic allocation must bind slots zero and one to
   exact XAU/XAG symbols before Development starts.
3. Strict compile/build validation must produce one fresh `.ex5` and verify
   card identity, inputs, magics, setfile schema, source hash, and resolver.
4. The logical basket manifest must route one Q02 work item through the XAU D1
   host and declare both custom-history symbols.
5. Q02 alone may execute the backtest baseline. No manual tester dispatch is
   authorized.

## Approval Checklist

- [x] Reputable source lineage and claim boundary recorded.
- [x] Structural, low-frequency, oscillator-free signal.
- [x] Exact non-duplicate family boundary recorded.
- [x] Two-leg atomicity, equal-notional target, and aggregate risk locked.
- [x] Backtest uses `RISK_FIXED=1000` and zero percentage risk.
- [x] No live, portfolio-gate, or correlation-waiver authority.
- [x] Deterministic G0 approval receipt attached.
- [ ] Magic rows allocated and strict build passed.
- [ ] One paced logical-basket Q02 row enqueued.

## Change Log

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-22 | initial completed-month outside-range residence reversion basket | G0 | APPROVED |
