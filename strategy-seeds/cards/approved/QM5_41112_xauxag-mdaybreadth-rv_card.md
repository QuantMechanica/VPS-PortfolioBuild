---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-MDAYBREADTH-RV-2026_S01
variant_id: SCHWEIKERT-CME-XAUXAG-MDAYBREADTH-RV-2026_S01
source_id: SCHWEIKERT-CME-XAUXAG-MDAYBREADTH-RV-2026
ea_id: QM5_41112
slug: xauxag-mdaybreadth-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41112_xauxag-mdaybreadth-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-22
created_by: Research+Development
last_updated: 2026-08-22
g0_status: APPROVED
g0_decision: decisions/2026-08-22_qm5_41112_xauxag_monthly_daily_relative_sign_breadth_reversion_g0.md
source_approval: decisions/2026-08-22_xauxag_monthly_daily_relative_sign_breadth_reversion_source_approval.md
source_author: "Karsten Schweikert; CME Group"
source_authors: "Karsten Schweikert; OlaOluwa S. Yaya; Xuan Vinh Vo; Hammed A. Olayinka; CME Group"
source_citation: "Schweikert (2018), Journal of Banking & Finance 88, 44-51, DOI 10.1016/j.jbankfin.2017.11.010; Yaya, Vo, and Olayinka (2021), Resources Policy 72, 102045, DOI 10.1016/j.resourpol.2021.102045; CME Group, Gold & Silver Ratio Spread."
source_citations:
  - type: academic_paper
    citation: "Schweikert, Karsten (2018), Are gold and silver cointegrated? New evidence from quantile cointegrating regressions, Journal of Banking & Finance 88, 44-51."
    location: "DOI 10.1016/j.jbankfin.2017.11.010; complete-read packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: state_dependent_gold_silver_long_run_relation
  - type: academic_paper
    citation: "Yaya, OlaOluwa S.; Vo, Xuan Vinh; and Olayinka, Hammed A. (2021), Gold and silver prices, their stocks and market fear gauges: Testing fractional cointegration using a robust approach, Resources Policy 72, 102045."
    location: "DOI 10.1016/j.resourpol.2021.102045; governed packet strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md"
    quality_tier: A
    role: supporting_fractional_cointegration_lineage
  - type: exchange_research
    citation: "CME Group, Gold & Silver Ratio Spread."
    location: "governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md; bounded extraction strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MDAYBREADTH-RV-2026/source.md"
    quality_tier: A
    role: ratio_definition_and_intermarket_spread_carrier
strategy_mechanic: synchronized-two-consecutive-completed-calendar-months-parent-final-ratio-anchor-every-newest-month-daily-relative-log-return-sign-strict-majority-endpoint-agreement-contrarian-next-month-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-CME-XAUXAG-MDAYBREADTH-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-ratio-reversion]]"
  - "[[concepts/completed-month-daily-relative-sign-breadth]]"
  - "[[concepts/market-neutral-commodity-basket]]"
indicators:
  - "[[indicators/completed-month-daily-relative-return-sign-count]]"
  - "[[indicators/completed-month-relative-endpoint-return]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, gold-silver-ratio, relative-value-basket, completed-month-daily-relative-sign-breadth, endpoint-return-agreement, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41112_XAU_XAG_MDAYBREADTH_RV_D1
symbol: QM5_41112_XAU_XAG_MDAYBREADTH_RV_D1
host_symbol: XAUUSD.DWX
companion_symbol: XAGUSD.DWX
symbol_slots: [0, 1]
magic_numbers: [411120000, 411120001]
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 7-10 completed paired packages per full post-warm-up year after exact monthly synchronization, a strict daily-relative-return-sign majority, same-sign endpoint displacement, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_MONTHLY_DAILY_BREADTH_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q00
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a completed-month gold/silver daily-relative-sign-breadth fade outside the certified XAU/SP500/NDX/XNG book. Verify two consecutive synchronized 17-23-session months, parent-final ratio anchor, every newest-month relative-return sign, flat returns retained in the denominator, strict majority, same-sign endpoint displacement, contrarian pair sides, durable monthly attempt, aggregate fixed risk, atomic basket repair, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xau_xag_carrier, synchronized_first_tradable_month_bar, consecutive_calendar_months, bounded_month_session_counts, parent_final_ratio_anchor, all_newest_month_daily_relative_returns, strict_sign_orientation, flat_returns_in_denominator, strict_daily_majority, endpoint_displacement_agreement, no_current_month_leakage, contrarian_package_direction, persistent_month_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_month_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 peer-reviewed DOI plus official CME carrier with monthly daily-breadth translation disclosed; R2 locks synchronized months, signs, majority/net, inverse side, attempt, aggregate risk, atomicity and lifecycle; R3 native XAU/XAG D1; R4 deterministic arithmetic with no banned signal; only self dedup"
---

# QM5_41112 XAU/XAG Completed-Month Daily Relative-Sign Breadth Reversion

## Hypothesis

Gold and silver share a long-run precious-metals factor but have different
monetary, safe-haven, and industrial sensitivities. When a completed monthly
gold/silver-ratio displacement is supported by a strict majority of all its
synchronized daily relative-return directions, the move may be broadly
participated rather than caused only by one endpoint jump. Fading that
relative displacement for the next broker month may capture a structural,
low-frequency intermetal reversion effect.

This is one opposite-leg relative-value package rather than another outright
XAU, index, or XNG direction. That construction does not prove profitability,
neutrality, or decorrelation. Q02 owns frequency and baseline economics; Q09
alone may establish realized portfolio correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MDAYBREADTH-RV-2026/source.md`,
authorized before extraction by
`decisions/2026-08-22_xauxag_monthly_daily_relative_sign_breadth_reversion_source_approval.md`
at commit `6b0270433`. The bounded extraction was committed at `191e20d0f`.
The complete parent-source hashes are
`4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`
and `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.

Schweikert documents state-dependent gold/silver cointegration evidence, the
supporting paper documents fractional-cointegration lineage, and CME defines
the gold/silver ratio and intermarket spread carrier. They do not test a
completed-month daily relative-sign majority, endpoint agreement, continuous
CFDs, equal-notional fixed-dollar risk, or the QM book. All clock, endpoint,
signal, execution, and risk choices below are declared QM interpretations.

No source return, density, hedge ratio, profit factor, drawdown, transaction
cost, CFD equivalence, neutrality, or correlation statistic is imported.

## Non-Duplicate Decision

The fail-closed pre-allocation checker scanned 4,608 registry identities,
1,280 repository cards, and 45 Strategy-Wiki nodes and returned `CLEAN`.
Manual semantic review fixes the load-bearing boundaries:

- `QM5_41085_xauxag-wdaybreadth-rv` requires one exact five-session week,
  four-of-five signs, and a one-week hold. This card requires two consecutive
  17-to-23-session calendar months, every newest-month relative return, strict
  majority, and a next-month hold.
- `QM5_20275_gsr-runfade` classifies a fixed six-return short rolling run, not
  every synchronized relative return in one completed calendar month.
- `QM5_12577`, `QM5_20157`, `QM5_20161`, `QM5_20263`, and `QM5_20268`
  estimate a rolling center, regression, scale, score, or empirical tail; this
  card estimates none.
- `QM5_41103`, `QM5_41104`, `QM5_41109`, and `QM5_41110` use monthly ratio
  range, location, or distribution geometry rather than daily relative-return
  signs.
- `QM5_41030`, `QM5_41040`, and `QM5_41057` classify session and overnight
  relative flows rather than synchronized close-to-close monthly paths.
- `QM5_41111_wti-mdaybreadth-mom` follows one outright WTI carrier. This card
  fades a two-metal relative move and targets equal absolute notionals.
- certified `QM5_12567_cum-rsi2-commodity` is a single-symbol long-only XNG
  oscillator pullback, not a paired intermetal basket.

The exact paired carrier, consecutive completed calendar months,
17-to-23-session synchronization, parent-final ratio anchor, every newest-
month relative-return sign, equality-inclusive denominator, strict majority,
same-sign endpoint displacement, contrarian package side, persistent monthly
attempt, equal-notional aggregate-risk package, and next-month exit are jointly
load-bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_DAILY_RELATIVE_SIGN_MAJORITY_NET_AGREEMENT_REVERSION_AFTER_FAMILY_REVIEW`.

Post-allocation evidence is
`artifacts/qm5_41112_xauxag_mdaybreadth_rv_postallocation_dedup_20260822.json`.
Its only exact hits must be the newly reserved `QM5_41112` slug and strategy
ID; any foreign collision rejects G0.

## Markets, Timeframe, And Cadence

- Host: exact `XAUUSD.DWX`; companion: exact `XAGUSD.DWX`.
- Logical basket: `QM5_41112_XAU_XAG_MDAYBREADTH_RV_D1`.
- Timeframe: exact D1; slots zero and one; planned magics `411120000` and
  `411120001`.
- Decision: first tradable synchronized D1 bar of a new broker-calendar month,
  within 180 elapsed raw-session minutes.
- Formation: the two immediately preceding consecutive completed calendar
  months, each with 17 through 23 synchronized close pairs.
- Signal: a strict majority of all newest-month daily relative-return signs
  must agree with the parent-final-to-newest-final ratio displacement.
- Direction: fade the agreeing relative sign with one opposite-leg package.
- Normal exit: first tick whose broker `yyyymm` is later than the package-entry
  month.
- Expected frequency: approximately 7-10 completed packages/year; Q02 must
  prove at least five per full post-warm-up year or retire.
- Backtest risk: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `P` be the parent month's chronological final synchronized log ratio and
let `Q[0]...Q[n-1]` be every chronological synchronized log ratio in the
immediately completed month:

```text
P    = ln(XAU_parent_final) - ln(XAG_parent_final)
Q[i] = ln(XAU_i) - ln(XAG_i)

d[0] = Q[0] - P
d[i] = Q[i] - Q[i-1], i=1...n-1
net  = Q[n-1] - P

2 * count(d[i] > 0) > n and net > 0
    => SELL XAUUSD.DWX, BUY XAGUSD.DWX

2 * count(d[i] < 0) > n and net < 0
    => BUY XAUUSD.DWX, SELL XAGUSD.DWX

otherwise
    => FLAT
```

Every endpoint completes before the decision month begins. A zero relative
return remains in `n` and contributes to neither direction. A tie,
non-majority, net equality, sign disagreement, or invalid history is flat.
Breadth margin and net magnitude never change risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XAUUSD.DWX` D1 bar under EA 41112 and
   magic slots zero and one.
2. Repair malformed, orphaned, same-side, duplicated, notional-invalid, later-
   month, or stale owned exposure before entry-only gates.
3. Require current host and companion D1 timestamps to be identical. Derive
   the current broker `yyyymm`, immediately completed month, and consecutive
   parent month from synchronized raw bar time, including year boundaries.
4. Require the immediately preceding synchronized completed bar to belong to
   the prior month, proving this is the first tradable bar of the new month.
5. Require attachment within 180 elapsed minutes of the raw current host D1
   bar open. Persist the current decision `yyyymm` before history, signal,
   spread, quote, ATR, sizing, news, or order gates. Never retry that month.
6. Require no owned position and no same-magic entry deal already recorded in
   the current broker month.
7. Within a fixed 70-bar buffer, reconstruct exactly the immediately completed
   month and its parent from synchronized host/companion timestamps. Require
   17 to 23 unique pairs per month, strict reverse-time chronology, positive
   finite closes, exact month membership, and no current-month observation.
8. Use the parent month's chronological final ratio as `P`. Reverse the newest
   month into chronological order and include every one of its close pairs
   exactly once. Form the first relative return from `P` to the first newest-
   month ratio and each later return between adjacent ratios.
9. Count strict positive and negative relative returns. Equality remains in
   the session denominator and counts neither way. Sell XAU/buy XAG only when
   `2*positive>n` and the newest final ratio is strictly above `P`. Buy
   XAU/sell XAG only when `2*negative>n` and the newest final ratio is strictly
   below `P`. Every other state consumes the month flat.
10. Require valid executable quotes and no genuinely positive spread wider
    than 1,500 XAU points or 500 XAG points. Modeled zero `.DWX` spread is
    valid.
11. Attach one frozen hard stop at `3.5 * ATR(20,D1)` to each leg. Choose lots
    so aggregate normalized stop risk is at most one `RISK_FIXED=1000` budget
    and absolute USD notionals target 1:1 within 20 percent. Use no target.
12. Submit the two market legs once. If the second leg or final package
    validation fails, flatten any opened leg immediately. No pending order,
    retry, scale-in, grid, martingale, pyramid, overlay hedge, or second entry
    exists.

## 5. Exit Rules

1. Broker hard stops and framework kill-switch closure remain authoritative.
2. Immediately flatten an orphaned, duplicated, same-side, wrong-symbol,
   wrong-magic, missing-stop, invalid-volume, or notional-invalid package.
3. Close both legs on the first tick whose broker `yyyymm` is later than the
   package-entry `yyyymm`.
4. Close both legs after forty elapsed calendar days as a stale safety repair.
5. No Friday close, target, signal exit, trail, break-even move, partial exit,
   discretionary close, or intentional hold beyond the next broker month.

## 6. Filters (No-Trade Module)

- Exact host/companion, D1, EA 41112, slots zero/one, and registered magics.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF; Friday close is OFF.
- Synchronized first-month-bar clock, 180-minute grace, consecutive month
  labels, bounded session counts, parent/newest endpoints, relative-return
  chronology, equality-inclusive denominator, majority/net state, durable
  attempt, spreads, quotes, ATRs, sizing, and stop geometry all fail closed.
- No fitted center, futures chain, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, oscillator, or manual signal is read.

## 7. Trade Management Rules

- Own exactly zero or two positions: one `XAUUSD.DWX` leg under magic
  `411120000` and one `XAGUSD.DWX` leg under magic `411120001`.
- The legs must be opposite side, have positive stops, and remain within the
  20-percent absolute-notional mismatch cap.
- Persist the last attempted decision `yyyymm` across restart; clear only a
  future-dated tester residue during initialization.
- Manage malformed, later-month, stale, and kill-switch exits before entry.
- Freeze original hard stops; never widen, trail, or remove them.
- Do not retry, add, pyramid, grid, martingale, partially close, overlay hedge,
  or reverse inside the month.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_history_bars_d1` | 70 | bounded two-month synchronized buffer |
| `strategy_min_month_sessions` | 17 | complete-month lower bound |
| `strategy_max_month_sessions` | 23 | complete-month upper bound |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen per-leg stop distance |
| `strategy_notional_ratio` | 1.0 | target XAU/XAG absolute notional ratio |
| `strategy_max_notional_mismatch_pct` | 20.0 | package rejection cap |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_xau_max_spread_points` | 1500 | host cost guard |
| `strategy_xag_max_spread_points` | 500 | companion cost guard |
| `strategy_deviation_points` | 20 | market-order deviation cap |
| `qm_friday_close_enabled` | false | full-month identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive value |

Strict majority, endpoint agreement, equality handling, relative-return
orientation, two-month package count, 17-to-23-session bounds, boundary entry,
one-attempt rule, contrarian direction, and next-month exit are not parameters.

## Source-Defined Rules

Schweikert and the supporting paper supply evidence for testing a
state-dependent gold/silver relationship. CME supplies the ratio definition
and intermarket spread carrier. None supplies this monthly daily-breadth fade.

## QM Interpretations

`SCHWEIKERT-CME-XAUXAG-MDAYBREADTH-RV-2026_S01` fixes the synchronized
calendar-month clock, parent plus newest-month endpoints, every daily relative-
return sign, strict majority with equal observations retained, endpoint
agreement, inverse side, continuous-CFD mapping, durable attempt,
equal-notional aggregate fixed risk, spread caps, atomic repair, and one-month
lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stops and framework kill switch.
2. Malformed, orphaned, or unsafe package repair.
3. Later broker-month closure.
4. Forty-calendar-day stale repair.

## Runtime Data Dependencies

Exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX` native D1 timestamps and
closes, broker time, symbol metadata, quotes, completed-bar ATRs, framework
position/deal state, and persistent terminal global-variable attempt state.
No finite external runtime dataset exists.

## Risk

- Backtest only: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stops: `3.5 * ATR(20,D1)` independently on both legs.
- Lots target equal absolute USD notionals while aggregate normalized stop
  risk remains at or below the single fixed-dollar budget.
- No target and no signal-strength sizing.
- Major risks are ratio regime breaks, monthly aggregation errors, leg-basis
  drift, unequal CFD contract behavior, holiday attrition, synchronization,
  financing, paired costs, minimum-lot mismatch, density below the floor, and
  realized book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_MONTHLY_DAILY_BREADTH_TRANSLATION_RISK | Named peer-reviewed DOI and official-exchange lineage; daily relative-sign breadth is disclosed as an untested QM translation. |
| R2 | PASS | Synchronized clock, month labels, endpoints, strict signs, equality handling, strict majority, endpoint agreement, sides, attempt, aggregate risk, atomicity, and lifecycle are deterministic. |
| R3 | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered native XAU/XAG D1 histories supply all runtime inputs; Q02 owns history, cost, density, and CFD-basis sufficiency. |
| R4 | PASS | Native deterministic arithmetic and state only; no trained signal, banned indicator, external runtime feed, grid, or martingale. |

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, wrong or
mixed month labels, invalid session count, asynchronous endpoints, current-
month leakage, missing or duplicated relative returns, wrong orientation,
removing equality from `n`, accepting a tie, majority/net disagreement, wrong
pair side, duplicate monthly attempt, incomplete aggregate-risk sizing,
orphan exposure, missing hard stop, wrong lifecycle, or nondeterminism.

Changing carrier, endpoint count, session bounds, relative-return orientation,
majority equality, equality treatment, endpoint conjunction, side, attempt
clock, risk, notional target, stops, or lifecycle requires a new identity,
binary, complete stream reconciliation, and portfolio requalification. A
failed result may not be rescued by adding a fitted center, volatility,
volume, calendar, event, external-data, or prior-result filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact carrier/period, synchronized month clock, endpoints, relative returns, strict majority/net state, attempt, spreads, ATRs | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| equal-notional aggregate-risk two-leg open and orphan rollback | Trade Entry | basket-order helper called from `Strategy_EntrySignal` |
| malformed, later-month, and stale package repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helpers |
| next-month and forty-day closure | Trade Close | `Strategy_ExitSignal` plus paired close orchestration |
| native-price declaration; news OFF/OFF | News hook | `Strategy_NewsFilterHook` |

## Build Acceptance Contract

The build must prove exact identity, synchronized month reconstruction,
parent-anchor and newest-close ordering, positive/negative/equality count
cases, strict-majority equality flat, majority/net disagreement flat, both
package directions, malformed and nonconsecutive history rejection, no
current-month price leakage, durable attempt timing, aggregate fixed-risk
equal-notional sizing, atomic rollback, next-month/stale exits,
`basket_manifest.json`, card lint, strict compile/build checks, setfile schema,
resolver identity, and a deterministic reference test suite before Q02
handoff.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1-card | 2026-08-22 | new OWNER-authorized intermetal structural sleeve | Q00 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| Q00 Research Intake | 2026-08-22 | APPROVED | `decisions/2026-08-22_qm5_41112_xauxag_monthly_daily_relative_sign_breadth_reversion_g0.md` |
| Q01 Build and Spec | - | PENDING | - |
| Q02 Baseline | - | NOT_QUEUED | - |

No Q11 portfolio or live decision is made by this card.
