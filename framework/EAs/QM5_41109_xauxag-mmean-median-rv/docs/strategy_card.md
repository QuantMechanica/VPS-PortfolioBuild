---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-MMEAN-MEDIAN-RV-2026_S01
variant_id: SCHWEIKERT-CME-XAUXAG-MMEAN-MEDIAN-RV-2026_S01
source_id: SCHWEIKERT-CME-XAUXAG-MMEAN-MEDIAN-RV-2026
ea_id: QM5_41109
slug: xauxag-mmean-median-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41109_xauxag-mmean-median-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-22
created_by: Research+Development
last_updated: 2026-08-22
g0_status: APPROVED
g0_decision: decisions/2026-08-22_qm5_41109_xauxag_monthly_mean_median_reversion_g0.md
source_approval: decisions/2026-08-22_xauxag_monthly_mean_median_reversion_source_approval.md
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; supporting carrier definition from CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: peer_reviewed_paper
    citation: "Schweikert, K. (2018). Are gold and silver cointegrated? New evidence from quantile cointegrating regressions. Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete-read governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md; bounded extraction strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MMEAN-MEDIAN-RV-2026/source.md"
    quality_tier: A
    role: primary_state_dependent_long_run_relation
  - type: exchange_education
    citation: "CME Group, Gold & Silver Ratio Spread."
    location: "Governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md"
    quality_tier: A
    role: supporting_intermarket_carrier_definition
strategy_mechanic: synchronized-immediately-completed-calendar-month-daily-close-log-ratio-arithmetic-mean-versus-ordinary-median-internal-tail-bias-fade-next-month-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-CME-XAUXAG-MMEAN-MEDIAN-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-relative-value]]"
  - "[[concepts/completed-month-ratio-mean-median-tail-bias]]"
  - "[[concepts/market-neutral-basket]]"
indicators:
  - "[[indicators/completed-month-daily-close-ratio-mean-median]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, gold-silver-ratio, relative-value-basket, completed-month-ratio-mean-median-tail-bias, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41109_XAU_XAG_MMEAN_MEDIAN_RV_D1
symbol: QM5_41109_XAU_XAG_MMEAN_MEDIAN_RV_D1
host_symbol: XAUUSD.DWX
companion_symbol: XAGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [411090000, 411090001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately ten to twelve completed paired packages per full post-warm-up year after one exact synchronized completed-month sample, a strict arithmetic-mean-versus-ordinary-median displacement, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_MEAN_MEDIAN_TAIL_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a completed-month gold/silver daily-close log-ratio internal tail-bias fade outside the certified XAU/SP500/NDX/XNG book. Verify exact prior-month membership, 17-23 synchronized sessions, arithmetic mean, ordinary odd/even median, strict comparison, contrarian paired sides, durable monthly attempt, aggregate fixed risk, atomic basket repair, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xau_xag_carrier, first_tradable_month_bar, immediately_completed_calendar_month, synchronized_completed_d1_closes, bounded_month_session_count, arithmetic_mean, ordinary_sample_median, strict_mean_median_displacement, equality_flat, contrarian_ratio_direction, persistent_month_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_month_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 peer-reviewed DOI plus official CME carrier with internal mean-median tail bias disclosed as QM translation; R2 locks synchronized month, mean, odd/even median, strict side, attempt, aggregate risk, atomicity and lifecycle; R3 registered native XAU/XAG D1; R4 deterministic native arithmetic, no M"
---

# QM5_41109 XAU/XAG Completed-Month Ratio Mean-Median Reversion

## Hypothesis

The arithmetic mean of synchronized daily gold/silver log ratios moves more
than the ordinary median when observations on one side exert greater leverage
inside a completed calendar-month sample. Fading a strict positive internal
mean-median displacement by selling gold and buying silver, or fading a
strict negative displacement with the opposite package, for the next broker
month may capture re-convergence after a bounded tail-biased ratio state
without taking one outright directional signal.

This rule calls the signed mean-minus-median difference an internal tail-bias
state. It is not a standardized skewness estimator and makes no population-
moment claim. The sign alone selects direction; magnitude is ignored.

The candidate is one logical two-leg relative-value package intended to add a
different return driver outside the certified XAU/SP500/NDX/XNG book. Equal
notional and opposite legs are execution targets, not proof of beta, factor,
market, volatility, or portfolio neutrality. Q02 owns density and economics;
unchanged Q09 alone may establish realized book correlation.

## Source Traceability And Claim Boundary

The approved source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MMEAN-MEDIAN-RV-2026/source.md`,
authorized before extraction in
`decisions/2026-08-22_xauxag_monthly_mean_median_reversion_source_approval.md`
at commit `4a1957e0c`. The bounded extraction was committed at `088014c50`.

Schweikert supplies named peer-reviewed evidence for a potentially state-
dependent gold/silver relation. CME defines the gold/silver ratio and supports
treating the instruments as one intermarket spread carrier. Neither source
tests a completed-month ratio-level sample's arithmetic mean against its
ordinary median, the internal-tail interpretation, the contrarian side, a
continuous-CFD package, equal-notional sizing, fixed cash risk, ATR stops, or
a one-month hold.

No source return, profit factor, risk-adjusted return, drawdown, trade count,
transaction cost, hedge ratio, mean-median rule, CFD equivalence, neutrality,
or portfolio-correlation statistic transfers. Every implementation choice
below is a pre-result QM falsification choice.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,598 registry rows, 1,277
repository cards, and 45 Strategy-Wiki nodes. It found no exact or fuzzy
identity. Manual semantic review fixes the boundaries:

- `QM5_41104_xauxag-mmedian-shift-rv` compares the ordinary medians of two
  non-overlapping completed months. This card uses one completed month and
  compares its arithmetic mean with its own ordinary median. It can signal
  without any between-month location shift, and it never compares two
  medians.
- `QM5_41103_xauxag-mrange-migrate-rv` requires both minimum and maximum ratio
  endpoints to migrate between two months. This card computes no range
  endpoint and requires only one completed month.
- `QM5_20263_xauxag-mad-rv` uses a rolling 63-D1 median and MAD score, a fresh
  standardized-threshold crossing, and a rolling-center exit. This card
  estimates no scale, threshold, or crossing and compares two location
  functionals inside one bounded calendar sample once per month.
- `QM5_20268_xauxag-qtail-rv` uses frozen empirical deciles over 126
  observations and exits at a central band. This card uses every observation
  in one exact month, no quantile threshold, and a calendar-month exit.
- `QM5_20233_xauxag-skew-rank` estimates each metal's standardized third
  moment over twelve completed months and buys the lower-skew metal. This card
  neither estimates individual return skewness nor ranks the legs; it compares
  mean and median of the single log-ratio level sample.
- `QM5_20057_xauxag-xmom1` follows the relative winner from two month-end
  closes. This card uses all synchronized daily ratio closes inside one month
  and fades an internal location-functional displacement.
- `QM5_20157_xau-xag-ratio` fades a rolling 60-day mean/standard-deviation
  ratio score and exits at a rolling center. This card uses neither rolling
  window, scale, z-score, threshold, nor intramonth center exit.
- `QM5_20161_xauxag-ols-rv` fits a rolling residual and hedge coefficient.
  This card fits no parameter and uses a fixed unit log ratio.
- `QM5_41039_xauxag-mflow-div` compares overnight and intraday return
  components inside one month rather than ratio-level mean and median.
- `QM5_12533` supplies the validated logical-basket manifest/order recipe but
  its signal is an EURJPY/GBPJPY rolling cointegration spread.
- certified `QM5_12567_cum-rsi2-commodity` is a single-symbol long-only two-
  day XNG oscillator pullback and has no intermetal, monthly, or paired logic.

The exact XAU/XAG carrier, one synchronized immediately completed calendar
month, arithmetic mean, ordinary odd/even median, strict internal comparison,
contrarian package, durable monthly attempt, equal-notional aggregate-risk
sizing, and next-month exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_INTERNAL_MEAN_MEDIAN_TAIL_BIAS_REVERSION`.

## Markets, Timeframe, And Cadence

- Exact host: `XAUUSD.DWX`, D1, slot 0, planned magic `411090000`.
- Exact companion: `XAGUSD.DWX`, D1, slot 1, planned magic `411090001`.
- Logical symbol: `QM5_41109_XAU_XAG_MMEAN_MEDIAN_RV_D1`.
- Formation: synchronized daily-close log ratios in the immediately preceding
  complete broker-calendar month.
- Decision: first tradable D1 bar of a new broker-calendar month, within 180
  elapsed raw-session minutes.
- Signal: strict displacement of the completed-month arithmetic ratio mean
  from its ordinary ratio median; fade that internal direction.
- Ordinary exit: first tick whose broker `yyyymm` is later than the package-
  open month.
- Expected cadence: 10 trades/year per symbol as paired packages; retire below
  five completed packages per full post-warm-up year.
- Q02 risk: aggregate-package `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

For every synchronized completed D1 session `d`:

```text
r[d] = log(XAU_close[d]) - log(XAG_close[d])

mean = sum(r[d]) / n

sort a copy of r inside the completed calendar month

median(odd n)  = r_sorted[n / 2]
median(even n) = (r_sorted[n / 2 - 1] + r_sorted[n / 2]) / 2

mean > median => SELL XAU, BUY XAG
mean < median => BUY XAU, SELL XAG
mean = median => FLAT
```

All signal inputs complete before the decision month begins. The current D1
open, high, low, or close never enters the calculation. Equality, invalid
arithmetic, a non-predecessor month, or unsynchronized history is flat. The
mean-median displacement magnitude never changes eligibility or risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XAUUSD.DWX` D1 bar under EA 41109 and
   host magic slot zero.
2. Repair malformed, orphaned, duplicated, same-side, stopless, notional-
   invalid, later-month, or stale owned exposure before entry-only gates.
3. Require exact host and companion D1 timestamps. Derive the current and
   immediately completed `yyyymm` values from broker time and prove the sample
   month is the calendar predecessor across year boundaries. Reject attachment
   later than 180 elapsed minutes after the raw host bar open.
4. Persist the current decision `yyyymm` attempt before history, signal,
   spread, quote, ATR, sizing, news, or order gates. Never retry that month.
5. Within a fixed 40-bar buffer, collect every positive finite synchronized
   close pair belonging to the immediately completed month. Require 17 through
   23 unique, strictly increasing timestamp-identical sessions and no current-
   month observation.
6. Compute `log(XAU close)-log(XAG close)` for each pair. Compute the
   arithmetic mean from all values. Sort a copy only. Use the center value for
   odd counts and the arithmetic mean of the two center values for even counts
   as the ordinary median. Require both functionals to be finite.
7. Require the arithmetic mean to be strictly above or below the ordinary
   median. Equality, invalid arithmetic, missing synchronization, a non-
   predecessor month, or more than 23 sessions remains flat.
8. On `mean>median`, SELL XAU and BUY XAG. On `mean<median`, BUY XAU and SELL
   XAG. Difference magnitude never changes eligibility, direction, or risk.
9. Require no owned exposure, no same-magic entry deal already recorded in the
   current broker month, executable side-specific quotes, and no genuinely
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
3. Close both legs on the first tick whose broker `yyyymm` is later than the
   package-open `yyyymm`.
4. Close after forty elapsed calendar days as a final stale guard.
5. No Friday close, target, fitted-center exit, signal reversal, trailing stop,
   break-even move, partial exit, discretionary close, or intentional hold
   beyond the next broker month is authorized.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41109, slot zero, and both governed magics.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes, legacy news mode, and Friday close are OFF for Q02;
  lifecycle repair is never delayed by an entry-only gate.
- First-month-bar clock, exact predecessor month, synchronized timestamps,
  17-to-23 session count, positive finite closes, finite arithmetic mean and
  ordinary median, strict displacement, durable attempt, side-specific trade
  mode, spread, quote, ATR, sizing, stop geometry, and notional match all fail
  closed.
- No futures chain, inventory, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, rolling center, fitted hedge ratio, or
  manual signal is read at runtime.

## 7. Trade Management Rules

- Own exactly one `XAUUSD.DWX` position under active magic `411090000` and one
  opposite-side `XAGUSD.DWX` position under active magic `411090001`.
- Persist the last attempted decision `yyyymm` and package-open `yyyymm` across
  restart.
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
| `strategy_history_bars_d1` | 40 | bounded completed-month buffer |
| `strategy_min_month_sessions` | 17 | complete-month lower bound |
| `strategy_max_month_sessions` | 23 | complete-month upper bound |
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
source supplies a completed-month arithmetic-mean-versus-median rule, the
internal-tail interpretation, a strict side map, or a next-month fade.

## QM Interpretations

`SCHWEIKERT-CME-XAUXAG-MMEAN-MEDIAN-RV-2026_S01` fixes the exact immediately
completed calendar month, synchronized daily-close log-ratio sample,
arithmetic mean, ordinary odd/even median, strict internal comparison,
contrarian sides, continuous-CFD clock, durable attempt, equal-notional
aggregate risk, spread caps, stops, and lifecycle.

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

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_MEAN_MEDIAN_TAIL_TRANSLATION_RISK | Named peer-reviewed DOI plus official CME carrier lineage; the internal mean-median tail-bias fade is disclosed as an untested QM translation. |
| R2 | PASS | Clock, synchronized completed month, arithmetic mean, odd/even median, strict side, attempt, risk, and lifecycle are deterministic. |
| R3 | PASS | Registered native XAU/XAG D1 histories supply all runtime inputs; Q02 owns synchronization, residual beta, and CFD-basis sufficiency. |
| R4 | PASS | Native deterministic arithmetic and state only; no trained signal, banned indicator, external runtime feed, grid, or martingale. |

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, wrong or
asynchronous prior-month timestamps, invalid session count, current-month
leakage, incorrect arithmetic mean or odd/even median, accepting equality,
wrong contrarian side, duplicate monthly attempt, unbounded combined risk,
missing stops, broken atomicity, or nondeterminism.

Requalification requires a new OWNER-approved card version before accepting
equality, changing direction or hold, changing history/session bounds, fitting
a center or hedge ratio, adding a displacement threshold or standardized
moment, or adding a range, return, volatility, volume, season, external-data,
or prior-result gate. No post-result parameter salvage is authorized.

## Framework Alignment

| Card rule | V5 owner | Implementation target |
|---|---|---|
| exact carrier, timeframe, input, and month lock | No-Trade | `Strategy_NoTradeFilter` and `OnInit` |
| synchronized completed-month closes, arithmetic mean, ordinary median, strict comparison, sides, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus package helper |
| next-month and survivor repair | Trade Close | `Strategy_ExitSignal` plus package helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove month arithmetic across year boundaries; first-month-bar and
180-minute clock; exact immediately completed month with 17-to-23 synchronized
sessions; correct arithmetic mean and odd/even log-ratio median; both valid
internal-displacement directions; equality, invalid arithmetic, asynchrony,
incomplete-month, and non-predecessor flat states; no current-bar leakage;
persistent monthly attempts; fixed-risk frozen-stop sizing; atomic repair;
next-month and stale exits; card lint; strict compile; setfile schema; resolver
identity; basket manifest; and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-22 | initial XAU/XAG completed-month ratio mean-median reversion card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-22 | APPROVED | `decisions/2026-08-22_qm5_41109_xauxag_monthly_mean_median_reversion_g0.md` |
| Q01 Build Validation | - | PENDING_BUILD | - |
| Q02 Baseline Screening | - | NOT_QUEUED | - |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` logical-basket backtest setfile, and one paced logical-basket Q02
enqueue only below tester and CPU ceilings. It does not authorize a manual
backtest, terminal control, live/demo/shadow/stress/optimization preset,
AutoTrading, `T_Live`, deploy or T_Live manifest, portfolio-gate change,
portfolio admission, decorrelation claim, or correlation waiver.
