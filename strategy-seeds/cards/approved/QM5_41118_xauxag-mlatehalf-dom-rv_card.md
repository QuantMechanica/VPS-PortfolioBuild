---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-MLATEHALF-DOM-RV-2026_S01
variant_id: SCHWEIKERT-CME-XAUXAG-MLATEHALF-DOM-RV-2026_S01
source_id: SCHWEIKERT-CME-XAUXAG-MLATEHALF-DOM-RV-2026
ea_id: QM5_41118
slug: xauxag-mlatehalf-dom-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41118_xauxag-mlatehalf-dom-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-22
created_by: Research+Development
last_updated: 2026-08-22
g0_status: APPROVED
g0_decision: decisions/2026-08-22_qm5_41118_xauxag_monthly_late_half_dominance_reversion_g0.md
source_approval: decisions/2026-08-22_xauxag_monthly_late_half_dominance_reversion_source_approval.md
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
    location: "governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md; bounded extraction strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MLATEHALF-DOM-RV-2026/source.md"
    quality_tier: A
    role: ratio_definition_and_intermarket_spread_carrier
strategy_mechanic: synchronized-two-consecutive-completed-calendar-months-parent-final-ratio-anchor-newest-month-floor-half-partition-two-exhaustive-cumulative-relative-return-blocks-strict-late-half-absolute-return-dominance-contrarian-late-sign-next-month-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-CME-XAUXAG-MLATEHALF-DOM-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-ratio-reversion]]"
  - "[[concepts/completed-month-late-half-dominance]]"
  - "[[concepts/market-neutral-commodity-basket]]"
indicators:
  - "[[indicators/completed-month-cumulative-half-relative-returns]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, gold-silver-ratio, relative-value-basket, completed-month-late-half-dominance, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41118_XAU_XAG_MLATEHALF_DOM_RV_D1
symbol: QM5_41118_XAU_XAG_MLATEHALF_DOM_RV_D1
host_symbol: XAUUSD.DWX
companion_symbols: [XAGUSD.DWX]
symbol_slot_map: {XAUUSD.DWX: 0, XAGUSD.DWX: 1}
magic_map: {XAUUSD.DWX: 411180000, XAGUSD.DWX: 411180001}
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-8 completed XAU/XAG basket packages per full post-warm-up year after synchronized month reconstruction and strict late-half absolute-return dominance; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 6
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_LATE_HALF_DOMINANCE_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a completed-month gold/silver late-half-dominance fade outside the certified XAU/SP500/NDX/XNG book. Verify two consecutive synchronized 17-23-session months, parent-final ratio anchor, floor-half endpoint, exhaustive non-overlapping relative-return blocks, strict late-half absolute dominance, equality and zero handling, contrarian pair sides, durable monthly attempt, aggregate fixed risk, atomic basket repair, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xau_xag_carrier, synchronized_first_tradable_month_bar, consecutive_calendar_months, bounded_month_session_counts, parent_final_ratio_anchor, floor_half_partition, exhaustive_adjacent_return_partition, strict_late_half_absolute_dominance, zero_and_equality_handling, no_current_month_leakage, contrarian_late_sign_package_direction, persistent_month_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_month_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 Tier A peer-reviewed DOI plus official CME carrier with late-half-dominance translation disclosed; R2 locks synchronized floor-half arithmetic, strict magnitude comparison, inverse late-sign sides, attempt, aggregate risk, atomicity and lifecycle; R3 native XAU/XAG D1; R4 deterministic arithmetic with no banned signal"
---

# QM5_41118 XAU/XAG Completed-Month Late-Half Dominance Reversion

## Hypothesis

Gold and silver share a long-run precious-metals factor but have different
monetary, safe-haven, and industrial sensitivities. When the newest cumulative
half of a completed month's gold/silver-ratio path moves farther than the older
half, that recency-dominant displacement may represent an intermetal overshoot.
Fading only the dominant late-half sign for the next broker month may capture
a structural, low-frequency relative-value reversion effect.

This is one opposite-leg relative-value package rather than another outright
XAU, index, or XNG direction. Equal-notional construction is a target, not
proof of profitability, neutrality, or decorrelation. Q02 owns frequency and
baseline economics; Q09 alone may establish realized portfolio correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MLATEHALF-DOM-RV-2026/source.md`,
authorized before extraction by
`decisions/2026-08-22_xauxag_monthly_late_half_dominance_reversion_source_approval.md`
at commit `3da399186`. The bounded extraction was committed at `af92247db`.
The complete parent-source hashes are
`4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`
and `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.

Schweikert documents state-dependent gold/silver cointegration evidence, the
supporting paper documents fractional-cointegration lineage, and CME defines
the gold/silver ratio and intermarket spread carrier. They do not test a
completed-month late-half-dominance rule, continuous CFDs, equal-notional
fixed-dollar risk, or the QM book. All clock, partition, magnitude comparison,
execution, and risk choices below are declared QM interpretations.

No source return, density, hedge ratio, profit factor, drawdown, transaction
cost, CFD equivalence, neutrality, or correlation statistic is imported.

## Non-Duplicate Decision

The fail-closed pre-allocation checker scanned 4,615 registry identities,
1,286 repository cards, and 45 Strategy-Wiki nodes. It found no exact or
fuzzy candidate match and returned `CLEAN`. Manual semantic review fixes the
load-bearing boundaries:

- `QM5_41113_xauxag-mhalfagree-rv` requires both exhaustive ratio halves to
  share one strict sign and ignores their relative magnitudes. This card
  requires strict late-half magnitude dominance, accepts an opposed early
  half, and rejects same-sign paths whose early half is at least as large.
- `QM5_41116_xauxag-mthirdvote-rv` casts a magnitude-blind strict majority
  across three exhaustive relative-return blocks. This card uses exactly two
  halves, has no vote, and makes magnitude ordering load-bearing.
- `QM5_41112_xauxag-mdaybreadth-rv` counts every adjacent daily relative-
  return sign and requires full-month endpoint agreement. This card uses two
  cumulative blocks and imposes no endpoint-agreement filter.
- `QM5_41117_wti-mlatehalf-dom-mom` shares the abstract half-dominance shape
  but is a single-symbol direct-WTI continuation position. This card computes
  synchronized XAU-minus-XAG relative returns, reverses the late sign, and
  opens an opposite equal-notional two-leg package.
- `QM5_20260_xauxag-mom-vote` votes cross-sectional one-, three-, and
  twelve-month return ranks and follows the winner. This card partitions one
  completed month and fades a within-month relative displacement.
- `QM5_20275_gsr-runfade` classifies a fixed six-return rolling run.
- `QM5_12577`, `QM5_20157`, `QM5_20161`, `QM5_20263`, and `QM5_20268`
  estimate a center, regression, scale, score, or empirical tail; this card
  estimates none.
- certified `QM5_12567_cum-rsi2-commodity` is a single-symbol long-only XNG
  oscillator pullback, not a paired intermetal basket.

The exact paired carrier, consecutive completed calendar months,
17-to-23-session synchronization, parent-final ratio anchor, deterministic
`floor(n/2)` split, two exhaustive non-overlapping cumulative relative-return
blocks, strict late-half absolute dominance, contrarian late-sign package
side, persistent monthly attempt, equal-notional aggregate-risk package, and
next-month exit are jointly load-bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_STRICT_LATE_HALF_ABSOLUTE_DOMINANCE_REVERSION_AFTER_FAMILY_REVIEW`.

The post-allocation scan checked 4,616 registry identities, 1,286 cards, and
45 Wiki nodes. Its only exact hits are the newly reserved `QM5_41118` slug
and strategy ID; no foreign identity collision exists. Evidence:
`artifacts/qm5_41118_xauxag_mlatehalf_dom_rv_postallocation_dedup_20260822.json`.

## Markets, Timeframe, And Cadence

- Host: exact `XAUUSD.DWX`; companion: exact `XAGUSD.DWX`.
- Logical basket: `QM5_41118_XAU_XAG_MLATEHALF_DOM_RV_D1`.
- Timeframe: exact D1; slots zero and one; planned magics `411180000` and
  `411180001`.
- Decision: first tradable synchronized D1 bar of a new broker-calendar month,
  within 180 elapsed raw-session minutes.
- Formation: the two immediately preceding consecutive completed calendar
  months, each with 17 through 23 synchronized close pairs.
- Signal: the newest month's late cumulative relative-return half must have
  strictly greater absolute magnitude than its early half.
- Direction: fade the late-half relative sign with one opposite-leg package.
- Ordinary exit: first tick whose broker `yyyymm` is later than the package-
  open month.
- Expected frequency: approximately 5-8 completed packages/year; Q02 must
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
h    = floor(n / 2)

early = Q[h-1] - P
late  = Q[n-1] - Q[h-1]

abs(late) > abs(early) and late > 0
    => SELL XAUUSD.DWX, BUY XAGUSD.DWX

abs(late) > abs(early) and late < 0
    => BUY XAUUSD.DWX, SELL XAGUSD.DWX

otherwise
    => FLAT
```

Each adjacent return from `P` through `Q[n-1]` belongs to exactly one block.
The shared midpoint ratio is an anchor, not a duplicated return. With 17
through 23 newest-month observations, the early block contains eight through
eleven adjacent returns and the late block contains nine through twelve.
Early-half sign and full-month endpoint agreement are deliberately ignored;
late-half magnitude dominance is mandatory.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XAUUSD.DWX` D1 bar under EA 41118 and
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
   finite closes, consecutive month labels, and no current-month observation.
8. Order the newest-month ratios chronologically. Compute the parent-final
   anchor, `h=floor(n/2)`, and the early and late cumulative blocks exactly as
   defined. Reject invalid indices, non-finite arithmetic, equality, a zero
   late block, or `abs(late) <= abs(early)`.
9. When the eligible late block is positive, request SELL XAU and BUY XAG.
   When it is negative, request BUY XAU and SELL XAG. Early-half sign and the
   full-month endpoint sign never override this map. No agreement condition,
   fitted center, alternate comparison, or alternate side is authorized.
10. Require both symbols tradable in the requested directions, positive fresh
    quotes, spreads no greater than 1,500 XAU points and 500 XAG points, and
    completed-bar `ATR(20,D1)` values.
11. Allocate one aggregate `RISK_FIXED=1000` budget across frozen
    `3.5*ATR(20,D1)` stops while targeting equal absolute USD notionals. Reject
    normalized risk above budget or notional mismatch above 20 percent.
12. Open both market legs as one logical package. If either leg fails or the
    resulting ownership is incomplete, immediately close any orphan and do
    not retry that month.

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

- Exact host/companion, D1, EA 41118, slots zero/one, and registered magics.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF; Friday close is OFF.
- Synchronized first-month-bar clock, 180-minute grace, consecutive month
  labels, bounded session counts, parent/newest endpoints, floor-half split,
  strict late-half dominance, durable attempt, spreads, quotes, ATRs, sizing, and
  stop geometry all fail closed.
- No fitted center, futures chain, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, oscillator, or manual signal is read.

## 7. Trade Management Rules

- Own exactly zero or two positions: one `XAUUSD.DWX` leg under active magic
  `411180000` and one `XAGUSD.DWX` leg under active magic `411180001`.
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

## Source-Defined Rules

Schweikert and the supporting paper supply evidence for testing a state-
dependent gold/silver relationship. CME supplies the ratio definition and
intermarket spread carrier. None supplies this monthly half-dominance fade.

## QM Interpretations

`SCHWEIKERT-CME-XAUXAG-MLATEHALF-DOM-RV-2026_S01` fixes the synchronized
calendar-month clock, parent and newest endpoints, floor-half split, two
exhaustive cumulative block definitions, equality and zero handling, strict
late-half absolute dominance, inverse late-sign side, continuous-CFD mapping, durable attempt,
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
- Major risks are ratio regime breaks, monthly aggregation or partition
  errors, leg-basis drift, unequal CFD contract behavior, holiday attrition,
  synchronization, financing, paired costs, minimum-lot mismatch, and
  realized book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | TIER_A | Named peer-reviewed DOI and official-exchange lineage; the monthly late-half dominance is disclosed as an untested QM translation. |
| R2 | PASS | Synchronized clock, month labels, endpoints, floor-half split, block orientation, strict magnitude comparison, equality/zero handling, sides, attempt, aggregate risk, atomicity, and lifecycle are deterministic. |
| R3 | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered native XAU/XAG D1 histories supply all runtime inputs; Q02 owns history, cost, density, and CFD-basis sufficiency. |
| R4 | PASS | Native deterministic arithmetic and state only; no trained signal, banned indicator, external runtime feed, grid, or martingale. |

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, wrong or
mixed month labels, invalid session count, asynchronous endpoints, current-
month leakage, wrong chronological order, wrong split index, duplicated or
omitted adjacent returns, wrong block orientation, wrong magnitude comparison,
wrong equality/zero handling or pair side, duplicate monthly attempt, incomplete aggregate-risk
sizing, orphan exposure, missing hard stop, wrong lifecycle, or
nondeterminism.

Changing carrier, endpoint count, session bounds, partition rule, block-return
orientation, dominance comparison, equality/zero handling, side, attempt clock, risk, notional target,
stops, or lifecycle requires a new identity, binary, complete stream
reconciliation, and portfolio requalification. A failed result may not be
rescued by adding a fitted center, volatility, volume, weekday, season, event,
external-data, or prior-result filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact carrier/period, synchronized month clock, endpoints, floor-half split, block returns, strict dominance, attempt, spreads, ATRs | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| equal-notional aggregate-risk two-leg open and orphan rollback | Trade Entry | basket-order helper called from `Strategy_EntrySignal` |
| malformed, later-month, and stale package repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helpers |
| next-month and forty-day closure | Trade Close | `Strategy_ExitSignal` plus paired close orchestration |
| native-price declaration; news OFF/OFF | News hook | `Strategy_NewsFilterHook` |

## Build Acceptance Contract

The build must prove exact identity, synchronized month reconstruction,
parent-anchor and newest-close ordering, all 17-to-23-session floor-half
splits, exhaustive adjacent-return coverage, late-positive/late-negative,
opposed-sign, equality, zero, and non-dominance cases, both package directions, malformed and nonconsecutive history
rejection, no current-month price leakage, durable attempt timing, aggregate
fixed-risk equal-notional sizing, atomic rollback, next-month/stale exits,
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
| Q00 Research Intake | 2026-08-22 | APPROVED | `decisions/2026-08-22_qm5_41118_xauxag_monthly_late_half_dominance_reversion_g0.md` |
| Q01 Build and Spec | - | PENDING | - |
| Q02 Baseline | - | NOT_QUEUED | - |

No Q11 portfolio or live decision is made by this card.
