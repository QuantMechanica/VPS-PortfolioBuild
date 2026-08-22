---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-MTHIRDVOTE-MOM-2026_S01
variant_id: MOP-WTI-MTHIRDVOTE-MOM-2026_S01
source_id: MOP-WTI-MTHIRDVOTE-MOM-2026
ea_id: QM5_41115
slug: wti-mthirdvote-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41115_wti-mthirdvote-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-22
created_by: Research+Development
last_updated: 2026-08-22
g0_status: APPROVED
g0_decision: decisions/2026-08-22_qm5_41115_wti_monthly_three_block_vote_momentum_g0.md
source_approval: decisions/2026-08-22_wti_monthly_three_block_vote_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-WTI-MTHIRDVOTE-MOM-2026/source.md"
    quality_tier: A
    role: monthly_own_price_continuation_and_wti_carrier_lineage
strategy_mechanic: normalized-month-boundary-wti-two-consecutive-completed-month-packages-parent-final-close-anchor-newest-month-floor-third-partition-three-exhaustive-cumulative-return-blocks-strict-two-of-three-sign-vote-continuation-one-month-hold
sources:
  - "[[sources/MOP-WTI-MTHIRDVOTE-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-month-three-block-vote]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-cumulative-third-block-returns]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, completed-month-three-block-vote, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 411150000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed WTI positions per full post-warm-up year after exact monthly history and strict two-of-three cumulative-block sign voting; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_THREE_BLOCK_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a direct-WTI completed-month three-block vote sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact month boundaries, consecutive 17-23-session packages, parent-final-close anchor, floor-third partitions, exhaustive non-overlapping return blocks, strict two-of-three sign majority, zero handling, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_month_bar, consecutive_calendar_months, bounded_month_session_counts, parent_final_close_anchor, complete_newest_month_path, floor_third_partitions, exhaustive_nonoverlapping_return_blocks, strict_two_of_three_sign_vote, zero_vote_handling, no_current_month_leakage, monthly_attempt_state, risk_mode_dual, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 peer-reviewed WTI monthly continuation with disclosed three-block translation; R2 locked month/partition/vote/attempt/risk/lifecycle; R3 native XTI D1 with label/CFD risk; R4 deterministic arithmetic, no banned signal; post-allocation only self-hits"
---

# QM5_41115 WTI Completed-Month Three-Block Vote Momentum

## Hypothesis

A WTI completed-month move supported by a strict majority of three exhaustive
chronological cumulative-return blocks may represent broader temporal
continuation than a move concentrated in one portion of the month. Following
the two-of-three block-sign majority for the next broker month may capture a
structural, low-frequency crude-oil continuation effect.

This is a direct physical-energy carrier outside the certified
XAU/SP500/NDX/XNG book. Carrier and mechanic difference do not establish
profitability or decorrelation. Q02 owns frequency and baseline economics;
unchanged Q09 alone may establish realized portfolio correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-WTI-MTHIRDVOTE-MOM-2026/source.md`, authorized
before extraction by
`decisions/2026-08-22_wti_monthly_three_block_vote_momentum_source_approval.md`
at commit `e3b7b5d15`. The bounded extraction was committed at `ff371aada`.
The complete parent-source hash is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons, explicitly test one-month formation/holding rules within pooled
commodities, and include WTI in their futures universe. They do not test a
WTI-only within-month three-block sign vote, a continuous CFD, fixed-dollar
ATR risk, or the QM book. The partition, vote, execution, and risk choices
below are declared QM interpretations.

No source return, WTI-only alpha, profit factor, drawdown, trade count,
transaction cost, CFD equivalence, neutrality, or correlation statistic is
imported.

## Non-Duplicate Decision

The canonical pre-allocation checker included author and mechanic fields plus
the explicit Company Reference Wiki root. It scanned 4,611 registry
identities, 1,283 repository cards, and 45 Strategy-Wiki nodes and found no
exact or fuzzy candidate match. Manual semantic review fixes the boundaries:

- `QM5_41114_wti-mhalfagree-mom` requires unanimity across two cumulative
  halves. This card accepts one opposing block through a strict two-of-three
  cumulative-block majority.
- `QM5_41111_wti-mdaybreadth-mom` counts every adjacent daily return sign and
  requires endpoint agreement. This card casts exactly three cumulative
  block votes and imposes no endpoint agreement.
- `QM5_20272_wti-qtrvote-tr` votes four disjoint three-month returns over a
  year. This card votes three within-month blocks and holds the next month.
- `QM5_20187_wti-tsmom1m` follows every nonzero completed-month endpoint
  return. This card can reject or oppose that endpoint direction when the
  within-month block vote differs.
- `QM5_41021_wti-mdual-mom` combines a full-month return with its nested final
  five sessions and holds five sessions. This card partitions every adjacent
  return without overlap and holds a full month.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not symmetric monthly WTI continuation.

The exact WTI carrier, consecutive completed calendar months,
17-to-23-session contract, parent-final-close anchor, deterministic
`floor(n/3)` and `floor(2n/3)` boundaries, exhaustive non-overlapping
cumulative return blocks, strict two-of-three sign vote, magnitude-blind
direction, consumed monthly attempt, fixed risk, and full-next-month hold are
jointly load-bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_THREE_EXHAUSTIVE_BLOCK_STRICT_MAJORITY_CONTINUATION_AFTER_FAMILY_REVIEW`.

The post-allocation scan checked 4,612 registry identities, 1,283 cards, and
45 Wiki nodes. Its only hits are reserved `QM5_41115` as exact slug and
strategy-ID self-hits; it found no foreign collision. Evidence:
`artifacts/qm5_41115_wti_mthirdvote_mom_postallocation_dedup_20260822.json`.

## Markets, Timeframe, And Cadence

- Target symbol and host: exact `XTIUSD.DWX`.
- Timeframe: exact D1; magic slot 0; planned magic `411150000`.
- Decision: first tradable normalized D1 bar of a new broker-calendar month,
  within 180 elapsed raw-session minutes.
- Formation: the two immediately preceding consecutive completed calendar
  months, with 17 through 23 completed sessions each.
- Normal exit: first tick whose normalized broker month is later than the
  position-open month.
- Expected frequency: approximately 10-12 completed positions/year; Q02 must
  prove at least five per full post-warm-up year or retire.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `P` be the parent month's chronological final close and let
`C[0]...C[n-1]` be every chronological close in the newest completed month:

```text
a       = floor(n / 3)
b       = floor(2 * n / 3)
block_1 = log(C[a-1] / P)
block_2 = log(C[b-1] / C[a-1])
block_3 = log(C[n-1] / C[b-1])

positive block count >= 2  => BUY
negative block count >= 2  => SELL
otherwise                  => FLAT
```

Every value completes before the decision month begins. The current D1 price
never enters the signal. For 17 through 23 sessions, each block contains five
through eight adjacent returns. Shared closes are anchors, not duplicated
returns. A zero block casts no vote. An invalid partition, no strict majority,
or invalid history is flat. Return magnitude never changes direction or risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XTIUSD.DWX` D1 bar under EA 41115 and
   magic slot zero.
2. Repair malformed, later-month, or stale owned exposure before entry-only
   gates.
3. Select label offset zero when the raw current D1 date equals broker date,
   or `+1` day only when it is exactly one calendar day behind. Apply the same
   convention to every historical bar and reject every other or mixed state.
4. Derive current, immediately completed, and parent `yyyymm` values from
   normalized time. Require the prior two months to be consecutive across
   year boundaries and prove that the newest completed bar is older than the
   current month.
5. Require attachment within 180 elapsed minutes of raw current D1 bar open.
   Persist the current decision `yyyymm` before history, signal, spread,
   quote, ATR, sizing, news, or order gates. Never retry that month.
6. Require no owned position and no same-magic entry deal already recorded in
   the current broker month.
7. Within a fixed 70-bar buffer, reconstruct exactly the immediately
   completed month and its parent. Require 17 to 23 unique bars per month,
   strict reverse-time order, positive finite closes, exact month membership,
   and no current-month observation.
8. Use the parent's chronological final close as `P`. Reverse the newest
   month into chronological order and include every one of its closes exactly
   once. Set `a=floor(n/3)` and `b=floor(2*n/3)` and require
   `1 <= a < b < n`.
9. Compute exactly the three formula blocks above. Buy when at least two are
   strictly positive; sell when at least two are strictly negative. A zero
   contributes no vote. No strict majority or invalid arithmetic consumes the
   month flat. Do not require the full-month endpoint sign to agree.
10. Require a valid executable quote and no genuinely positive spread wider
    than 1,500 points. Modeled zero `.DWX` spread is valid.
11. Attach one frozen hard stop at `3.5 * ATR(20,D1)` from completed data and
    size one position to `RISK_FIXED=1000`. Use no take-profit.
12. Submit one slot-zero market order once. No pending order, retry, scale-in,
    grid, martingale, pyramid, hedge, or second entry exists.

## 5. Exit Rules

1. Broker hard stop and framework kill-switch closure remain authoritative.
2. Immediately flatten duplicate, wrong-symbol, wrong-magic, missing-stop,
   invalid-volume, or invalid-open-time exposure.
3. Close on the first tick whose normalized broker `yyyymm` is later than the
   position-open `yyyymm`.
4. Close after forty elapsed calendar days as a stale safety repair.
5. No Friday close, target, signal exit, trail, break-even move, partial exit,
   discretionary close, or intentional hold beyond the next broker month.

## 6. Filters (No-Trade Module)

- Exact host, D1, EA 41115, slot zero, and registered magic.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes, legacy news mode, and Friday close are OFF; lifecycle repair
  is never delayed by an entry-only gate.
- Uniform label normalization, first-month-bar clock, 180-minute grace,
  consecutive months, session counts, parent anchor, chronological close
  ordering, floor-third partitions, exhaustive blocks, strict sign vote,
  durable attempt, spread, quote, ATR, and sizing fail closed.
- Runtime cannot read a futures chain, inventory, volume, open interest,
  event feed, external file, API, regression, trained output, prior-result
  state, or manual signal.

## 7. Trade Management Rules

- Own at most one exact `XTIUSD.DWX` slot-zero position under magic
  `411150000`.
- Persist the last attempted decision `yyyymm` across restart; clear only a
  future-dated tester residue at initialization.
- Manage malformed, later-month, stale, and kill-switch exits on every tick
  before entry evaluation.
- Freeze the original hard stop; never widen, trail, remove, or replace it.
- Do not retry, add, pyramid, grid, martingale, partially close, hedge, or
  reverse inside the month.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_bars_d1` | 70 | bounded two-month close buffer |
| `strategy_min_month_sessions` | 17 | complete-month lower bound |
| `strategy_max_month_sessions` | 23 | complete-month upper bound |
| `strategy_entry_grace_minutes` | 180 | first-month-bar window |
| `strategy_atr_period_d1` | 20 | completed-bar range estimate |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1500 | entry cost guard |
| `qm_friday_close_enabled` | false | full-month identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive value |

The block count and boundaries, sign vote, magnitude-blind direction, two-
month package count, 17-to-23-session bounds, boundary entry, one-attempt
rule, and next-month exit are not parameters.

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply monthly own-return-sign continuation and
explicit WTI carrier lineage. They do not supply the within-month partition,
three cumulative block votes, majority state, or CFD lifecycle.

## QM Interpretations

`MOP-WTI-MTHIRDVOTE-MOM-2026_S01` fixes the exact prior two calendar months,
parent-final-close anchor, all newest-month closes, deterministic floor-third
partitions, three exhaustive cumulative return blocks, strict two-of-three
sign majority, continuous-CFD clock, durable attempt, fixed risk, spread cap,
stop, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later broker-month closure.
4. Forty-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 timestamps and closes, broker time, symbol
metadata, quotes, completed-bar ATR, framework position/deal state, and
persistent terminal global-variable attempt state. No external runtime
dataset exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are false continuation, partition/indexing errors, month-end
  gaps, continuous-CFD basis, financing, energy-label drift, session
  sparsity, spread, source translation, and realized overlap with other
  momentum sleeves.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_THREE_BLOCK_TRANSLATION_RISK | Named peer-reviewed DOI, complete-read evidence, durable hash, and explicit WTI membership; the three-block vote is disclosed as an untested QM translation. |
| R2 | PASS | Clock, label, consecutive months, endpoints, floor-third partitions, cumulative-return orientation, zero handling, strict vote, attempt, risk, and lifecycle are deterministic. |
| R3 | PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK | Registered native WTI D1 supplies all runtime inputs; Q02 owns label, density, cost, and CFD-basis sufficiency. |
| R4 | PASS | Native deterministic arithmetic and state only; no trained signal, banned indicator, external runtime feed, grid, or martingale. |

## Falsification And Requalification

Q02 retires rather than tunes on zero positions, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, wrong
label or month membership, invalid session count, current-month leakage,
missing or duplicated closes, wrong partitions, overlapping or omitted
returns, wrong zero handling, wrong block vote, duplicate monthly attempt,
invalid risk mode, missing stop, wrong lifecycle, or nondeterminism.

Requalification requires a new OWNER-approved card version before changing
the block count or boundaries, vote rule, endpoint-agreement behavior,
direction or hold, history/session bounds, or adding volatility, volume,
season, weekday, moving-average, breakout, event, inventory, external-data,
or prior-result gates. No post-result parameter salvage is authorized.

## Framework Alignment

| Card rule | V5 owner | Implementation target |
|---|---|---|
| Exact host, period, risk, news, Friday, frozen inputs | No-Trade | `Strategy_NoTradeFilter` plus framework initialization |
| Month label, adjacency, close packages, floor-third partitions, block vote, attempt, ATR sizing | Trade Entry | `Strategy_EntrySignal` |
| Frozen stop and malformed-position repair | Trade Management | `Strategy_ManageOpenPosition` plus pre-entry lifecycle repair |
| Next-month and forty-day stale exits | Trade Close | `Strategy_ExitSignal` |
| Native-price declaration; news OFF/OFF | News hook | `Strategy_NewsFilterHook` |

## Build Acceptance Contract

The build must prove exact identity, deterministic month reconstruction,
parent anchor and newest close ordering, all 17-to-23-session floor-third
partitions, exhaustive non-overlapping return blocks, zero handling, strict
two-of-three vote, both entry directions, an endpoint-opposed majority,
malformed and nonconsecutive history rejection, no current-month price
leakage, durable attempt timing, fixed-risk stop sizing, next-month/stale
exits, card lint, strict compile/build checks, setfile schema, resolver
identity, and a deterministic reference suite before Q02 handoff.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1-card | 2026-08-22 | new OWNER-authorized WTI structural sleeve | Q00 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| Q00 Research Intake | 2026-08-22 | APPROVED | `decisions/2026-08-22_qm5_41115_wti_monthly_three_block_vote_momentum_g0.md` |
| Q01 Build and Spec | - | PENDING | - |
| Q02 Baseline | - | NOT_QUEUED | - |

## Safety Boundary

Research/backtest only. This card authorizes one branch-only non-live build,
strict Q01, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue only
after all gates pass. It authorizes no manual tester; live/demo/shadow/stress/
optimization setfile; AutoTrading; `T_Live`; deploy or T_Live manifest;
portfolio admission; portfolio-gate change; correlation waiver; or live use.
