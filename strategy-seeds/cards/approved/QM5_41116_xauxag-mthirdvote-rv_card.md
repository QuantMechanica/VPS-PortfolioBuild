---
card_schema_version: 2
type: strategy
strategy_id: SCHWEIKERT-CME-XAUXAG-MTHIRDVOTE-RV-2026_S01
variant_id: SCHWEIKERT-CME-XAUXAG-MTHIRDVOTE-RV-2026_S01
source_id: SCHWEIKERT-CME-XAUXAG-MTHIRDVOTE-RV-2026
ea_id: QM5_41116
slug: xauxag-mthirdvote-rv
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41116_xauxag-mthirdvote-rv_card.md
execution_contract_status: APPROVED
created: 2026-08-22
created_by: Research+Development
last_updated: 2026-08-22
g0_status: APPROVED
g0_decision: decisions/2026-08-22_qm5_41116_xauxag_monthly_three_block_vote_reversion_g0.md
source_approval: decisions/2026-08-22_xauxag_monthly_three_block_vote_reversion_source_approval.md
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
    location: "governed packet strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md; bounded extraction strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MTHIRDVOTE-RV-2026/source.md"
    quality_tier: A
    role: ratio_definition_and_intermarket_spread_carrier
strategy_mechanic: synchronized-two-consecutive-completed-calendar-months-parent-final-ratio-anchor-newest-month-floor-third-partition-three-exhaustive-cumulative-relative-return-blocks-strict-two-of-three-sign-vote-contrarian-next-month-equal-notional-basket
sources:
  - "[[sources/SCHWEIKERT-CME-XAUXAG-MTHIRDVOTE-RV-2026]]"
concepts:
  - "[[concepts/gold-silver-ratio-reversion]]"
  - "[[concepts/completed-month-three-block-vote]]"
  - "[[concepts/market-neutral-commodity-basket]]"
indicators:
  - "[[indicators/completed-month-cumulative-third-block-relative-returns]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, precious-metals, gold-silver-ratio, relative-value-basket, completed-month-three-block-vote, mean-reversion, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_41116_XAU_XAG_MTHIRDVOTE_RV_D1
symbol: QM5_41116_XAU_XAG_MTHIRDVOTE_RV_D1
host_symbol: XAUUSD.DWX
companion_symbols: [XAGUSD.DWX]
symbol_slot_map: {XAUUSD.DWX: 0, XAGUSD.DWX: 1}
magic_map: {XAUUSD.DWX: 411160000, XAGUSD.DWX: 411160001}
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed XAU/XAG basket packages per full post-warm-up year after synchronized month reconstruction and strict two-of-three cumulative-block voting; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 35.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_MONTHLY_THREE_BLOCK_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a completed-month gold/silver three-block majority fade outside the certified XAU/SP500/NDX/XNG book. Verify two consecutive synchronized 17-23-session months, parent-final ratio anchor, floor-third endpoints, exhaustive non-overlapping relative-return blocks, strict two-of-three sign vote, zero handling, contrarian pair sides, durable monthly attempt, aggregate fixed risk, atomic basket repair, and next-month lifecycle. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_xau_xag_carrier, synchronized_first_tradable_month_bar, consecutive_calendar_months, bounded_month_session_counts, parent_final_ratio_anchor, floor_third_partitions, exhaustive_adjacent_return_partition, strict_two_of_three_sign_vote, zero_vote_handling, no_current_month_leakage, contrarian_package_direction, persistent_month_attempt, equal_notional_basket, aggregate_fixed_risk, hard_stops_present, atomic_package_repair, next_month_exit, risk_mode_dual, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 Tier A peer-reviewed DOI plus official CME carrier with three-block translation disclosed; R2 locks synchronized floor-third vote, inverse sides, attempt, aggregate risk, atomicity and lifecycle; R3 native XAU/XAG D1; R4 deterministic arithmetic with no banned signal"
---

# QM5_41116 XAU/XAG Completed-Month Three-Block Vote Reversion

## Hypothesis

Gold and silver share a long-run precious-metals factor but have different
monetary, safe-haven, and industrial sensitivities. When a strict majority of
three exhaustive chronological blocks inside a completed month moves the
gold/silver ratio in one direction, the relative displacement spans more than
one part of the path. Fading that magnitude-blind majority for the next broker
month may capture a structural, low-frequency intermetal reversion effect.

This is one opposite-leg relative-value package rather than another outright
XAU, index, or XNG direction. Equal-notional construction is a target, not
proof of profitability, neutrality, or decorrelation. Q02 owns frequency and
baseline economics; Q09 alone may establish realized portfolio correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MTHIRDVOTE-RV-2026/source.md`,
authorized before extraction by
`decisions/2026-08-22_xauxag_monthly_three_block_vote_reversion_source_approval.md`
at commit `d853ac635`. The bounded extraction was committed at `8da1fe0e4`.
The complete parent-source hashes are
`4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`
and `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.

Schweikert documents state-dependent gold/silver cointegration evidence, the
supporting paper documents fractional-cointegration lineage, and CME defines
the gold/silver ratio and intermarket spread carrier. They do not test a
completed-month three-block vote, continuous CFDs, equal-notional fixed-dollar
risk, or the QM book. All clock, partition, vote, execution, and risk choices
below are declared QM interpretations.

No source return, density, hedge ratio, profit factor, drawdown, transaction
cost, CFD equivalence, neutrality, or correlation statistic is imported.

## Non-Duplicate Decision

The fail-closed pre-allocation checker scanned 4,612 registry identities,
1,284 repository cards, and 45 Strategy-Wiki nodes. It found no exact
collision and one fuzzy family neighbor,
`QM5_41112_xauxag-mdaybreadth-rv`. Manual semantic review fixes the
load-bearing boundaries:

- `QM5_41112` counts every adjacent daily relative-return sign and requires a
  strict sign majority plus endpoint agreement. This card casts only three
  cumulative block votes and has no endpoint-agreement filter.
- `QM5_41113_xauxag-mhalfagree-rv` requires unanimity across two cumulative
  halves. This card accepts one opposing block through a strict two-of-three
  majority and uses different partition endpoints.
- `QM5_41115_wti-mthirdvote-mom` is single-symbol direct-WTI continuation.
  This card computes synchronized XAU-minus-XAG relative returns, takes the
  inverse side, and owns two equal-notional legs.
- `QM5_20260_xauxag-mom-vote` votes cross-sectional one-, three-, and
  twelve-month return ranks and follows the winner. This card votes three
  non-overlapping blocks inside one month and fades the majority.
- `QM5_20275_gsr-runfade` classifies a fixed six-return rolling run.
- `QM5_12577`, `QM5_20157`, `QM5_20161`, `QM5_20263`, and `QM5_20268`
  estimate a center, regression, scale, score, or empirical tail; this card
  estimates none.
- certified `QM5_12567_cum-rsi2-commodity` is a single-symbol long-only XNG
  oscillator pullback, not a paired intermetal basket.

The exact paired carrier, consecutive completed calendar months,
17-to-23-session synchronization, parent-final ratio anchor, deterministic
`floor(n/3)` and `floor(2*n/3)` endpoints, exhaustive non-overlapping
cumulative relative-return blocks, strict two-of-three sign vote,
magnitude-blind contrarian package side, persistent monthly attempt,
equal-notional aggregate-risk package, and next-month exit are jointly
load-bearing. Verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_THREE_EXHAUSTIVE_BLOCK_STRICT_MAJORITY_REVERSION_AFTER_FAMILY_REVIEW`.

The post-allocation scan checked 4,613 registry identities, 1,285 cards, and
45 Wiki nodes. Its only exact hits are the newly reserved `QM5_41116` slug
and strategy ID; no foreign identity collision exists. Evidence:
`artifacts/qm5_41116_xauxag_mthirdvote_rv_postallocation_dedup_20260822.json`.

## Markets, Timeframe, And Cadence

- Host: exact `XAUUSD.DWX`; companion: exact `XAGUSD.DWX`.
- Logical basket: `QM5_41116_XAU_XAG_MTHIRDVOTE_RV_D1`.
- Timeframe: exact D1; slots zero and one; planned magics `411160000` and
  `411160001`.
- Decision: first tradable synchronized D1 bar of a new broker-calendar month,
  within 180 elapsed raw-session minutes.
- Formation: the two immediately preceding consecutive completed calendar
  months, each with 17 through 23 synchronized close pairs.
- Signal: at least two of the newest month's three cumulative relative-return
  blocks must have the same strict sign; zero casts no vote.
- Direction: fade the majority relative sign with one opposite-leg package.
- Ordinary exit: first tick whose broker `yyyymm` is later than the package-
  open month.
- Expected frequency: approximately 10-12 completed packages/year; Q02 must
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
a    = floor(n / 3)
b    = floor(2 * n / 3)

block_1 = Q[a-1] - P
block_2 = Q[b-1] - Q[a-1]
block_3 = Q[n-1] - Q[b-1]

at least two blocks > 0
    => SELL XAUUSD.DWX, BUY XAGUSD.DWX

at least two blocks < 0
    => BUY XAUUSD.DWX, SELL XAGUSD.DWX

otherwise
    => FLAT
```

Each adjacent return from `P` through `Q[n-1]` belongs to exactly one block.
Shared ratios are anchors, not duplicated returns. With 17 through 23 newest-
month observations, each block contains five through eight adjacent returns.
Block magnitude and full-month endpoint agreement are deliberately ignored.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XAUUSD.DWX` D1 bar under EA 41116 and
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
   anchor, `a=floor(n/3)`, `b=floor(2*n/3)`, and all three cumulative blocks
   exactly as defined. Reject invalid indices or non-finite arithmetic.
9. If at least two blocks are positive, request SELL XAU and BUY XAG. If at
   least two blocks are negative, request BUY XAU and SELL XAG. Zero abstains;
   no strict majority is flat. No magnitude threshold, endpoint filter,
   alternate vote, fitted center, or alternate side is authorized.
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

- Exact host/companion, D1, EA 41116, slots zero/one, and registered magics.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes and legacy mode are OFF; Friday close is OFF.
- Synchronized first-month-bar clock, 180-minute grace, consecutive month
  labels, bounded session counts, parent/newest endpoints, floor-third
  partitions, strict vote, durable attempt, spreads, quotes, ATRs, sizing, and
  stop geometry all fail closed.
- No fitted center, futures chain, volume, open interest, event feed, API, CSV,
  optimizer artifact, trained output, oscillator, or manual signal is read.

## 7. Trade Management Rules

- Own exactly zero or two positions: one `XAUUSD.DWX` leg under active magic
  `411160000` and one `XAGUSD.DWX` leg under active magic `411160001`.
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
intermarket spread carrier. None supplies this monthly three-block fade.

## QM Interpretations

`SCHWEIKERT-CME-XAUXAG-MTHIRDVOTE-RV-2026_S01` fixes the synchronized
calendar-month clock, parent and newest endpoints, floor-third partitions,
three cumulative block definitions, zero-abstention handling, strict
two-of-three vote, inverse side, continuous-CFD mapping, durable attempt,
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
| R1 | TIER_A | Named peer-reviewed DOI and official-exchange lineage; the monthly three-block vote is disclosed as an untested QM translation. |
| R2 | PASS | Synchronized clock, month labels, endpoints, partitions, block orientation, zero handling, strict vote, sides, attempt, aggregate risk, atomicity, and lifecycle are deterministic. |
| R3 | PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK | Registered native XAU/XAG D1 histories supply all runtime inputs; Q02 owns history, cost, density, and CFD-basis sufficiency. |
| R4 | PASS | Native deterministic arithmetic and state only; no trained signal, banned indicator, external runtime feed, grid, or martingale. |

## Falsification And Requalification

Q02 retires rather than tunes on zero packages, fewer than five completed
packages per full post-warm-up year, nonpositive governed economics, wrong or
mixed month labels, invalid session count, asynchronous endpoints, current-
month leakage, wrong chronological order, wrong partition indices, duplicated
or omitted adjacent returns, wrong block orientation, wrong zero handling,
wrong vote or pair side, duplicate monthly attempt, incomplete aggregate-risk
sizing, orphan exposure, missing hard stop, wrong lifecycle, or
nondeterminism.

Changing carrier, endpoint count, session bounds, partition rule, block-return
orientation, zero handling, vote, side, attempt clock, risk, notional target,
stops, or lifecycle requires a new identity, binary, complete stream
reconciliation, and portfolio requalification. A failed result may not be
rescued by adding a fitted center, volatility, volume, weekday, season, event,
external-data, or prior-result filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact carrier/period, synchronized month clock, endpoints, partitions, block returns, strict vote, attempt, spreads, ATRs | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| equal-notional aggregate-risk two-leg open and orphan rollback | Trade Entry | basket-order helper called from `Strategy_EntrySignal` |
| malformed, later-month, and stale package repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helpers |
| next-month and forty-day closure | Trade Close | `Strategy_ExitSignal` plus paired close orchestration |
| native-price declaration; news OFF/OFF | News hook | `Strategy_NewsFilterHook` |

## Build Acceptance Contract

The build must prove exact identity, synchronized month reconstruction,
parent-anchor and newest-close ordering, all 17-to-23-session floor-third
partitions, exhaustive adjacent-return coverage, positive/negative/zero/no-
majority cases, both package directions, malformed and nonconsecutive history
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
| Q00 Research Intake | 2026-08-22 | APPROVED | `decisions/2026-08-22_qm5_41116_xauxag_monthly_three_block_vote_reversion_g0.md` |
| Q01 Build and Spec | - | PENDING | - |
| Q02 Baseline | - | NOT_QUEUED | - |

No Q11 portfolio or live decision is made by this card.
