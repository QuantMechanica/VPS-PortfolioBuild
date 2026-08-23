---
card_schema_version: 2
type: strategy
strategy_id: MOP-MEEK-WTI-MWEEKDAY-MED-2026_S01
variant_id: MOP-MEEK-WTI-MWEEKDAY-MED-2026_S01
source_id: MOP-MEEK-WTI-MWEEKDAY-MED-2026
ea_id: QM5_41132
slug: wti-mweekday-med-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41132_wti-mweekday-med-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-23
created_by: Research+Development
last_updated: 2026-08-23
g0_status: APPROVED
g0_decision: decisions/2026-08-23_qm5_41132_wti_monthly_weekday_median_momentum_g0.md
source_approval: decisions/2026-08-23_wti_monthly_weekday_median_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Heather Meek; Susan A. Hoelscher"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Heather Meek; Susan A. Hoelscher"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003; Meek, H. and Hoelscher, S. A. (2023), Day-of-the-week effect: Petroleum and petroleum products, Cogent Economics & Finance 11(1), DOI 10.1080/23322039.2023.2213876."
source_citations:
  - type: peer_reviewed_paper_bounded_packet
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded composite strategy-seeds/sources/MOP-MEEK-WTI-MWEEKDAY-MED-2026/source.md"
    quality_tier: A
    role: wti_own_price_monthly_continuation_and_monthly_clock
  - type: peer_reviewed_open_access_paper_bounded_packet
    citation: "Meek, Heather and Hoelscher, Susan A. (2023), Day-of-the-week effect: Petroleum and petroleum products, Cogent Economics & Finance 11(1)."
    location: "DOI 10.1080/23322039.2023.2213876; complete-read packet strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md; bounded composite strategy-seeds/sources/MOP-MEEK-WTI-MWEEKDAY-MED-2026/source.md"
    quality_tier: A
    role: wti_ending_weekday_heterogeneity_and_weekday_label_lineage
strategy_mechanic: normalized-month-boundary-wti-immediately-completed-seventeen-to-twenty-three-session-daily-log-returns-partitioned-by-ending-weekday-per-bucket-arithmetic-mean-five-value-median-sign-continuation-one-month-hold
sources:
  - "[[sources/MOP-MEEK-WTI-MWEEKDAY-MED-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/weekday-balanced-return-aggregation]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-weekday-median]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, completed-month-weekday-balanced, median-direction, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 411320000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed WTI positions per full post-warm-up year after exact month, weekday-bucket, arithmetic, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKDAY_BALANCING_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a direct-WTI completed-month weekday-balanced median continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact month boundary, 17-23 returns ending in the month, older boundary inclusion, endpoint identity, ending-weekday assignment, all five bucket counts, per-bucket means, exact five-value median, direction independent of the raw endpoint, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_month_bar, immediately_completed_calendar_month, bounded_month_session_count, older_boundary_close, every_return_ending_in_month_once, chronological_log_return_orientation, endpoint_identity, normalized_ending_weekday, all_five_weekday_buckets, per_bucket_three_to_five_count, per_bucket_arithmetic_mean, ascending_five_value_sort, exact_median_index_two, raw_endpoint_not_a_gate, no_current_month_leakage, monthly_attempt_state, risk_mode_dual, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-23; R1 peer-reviewed WTI own-return and complete-read energy-weekday sources with the exact weekday-median translation disclosed; R2 exact month/return/endpoint/weekday/bucket/count/mean/sort/median/direction/attempt/risk/lifecycle; R3 native XTI D1 with label and CFD-basis risk; R4 deterministic arithmetic without a trained or banned signal; canonical pre-allocation dedup CLEAN and manual family review separates raw endpoint, daily breadth, sequential block vote, tail trim, cross-month medians, fixed weekdays, and certified XNG RSI logic."
---

# QM5_41132 WTI Completed-Month Weekday-Balanced Median Momentum

## Hypothesis

WTI adjusts to production, inventory, transport, refining, hedging, and demand
shocks through persistent physical-energy regimes. A raw completed-month
endpoint can nevertheless be dominated by one weekday or by an unequal number
of weekday observations. Giving Monday through Friday equal final weight and
following the median weekday's average daily return tests whether directional
pressure is broad across the weekly trading cycle rather than concentrated in
one calendar segment.

This is direct crude-oil exposure outside the certified XAU, SP500, NDX, and
XNG carriers. Different instrument and logic do not prove profitability or
decorrelation. Q02 owns density and baseline economics; unchanged Q09 alone
owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-MEEK-WTI-MWEEKDAY-MED-2026/source.md`, SHA-256
`B893049C0BA566F78412AE76DB1EE9E5E730119C3FBC53053DF705B7C0EDA57A`,
authorized before extraction by
`decisions/2026-08-23_wti_monthly_weekday_median_momentum_source_approval.md`
at commit `1e3af965c` and extracted at commit `4f670d5c0`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons, a monthly formation/renewal family, a pooled commodity `k=1,h=1`
implementation, and explicit WTI membership. Meek and Hoelscher document
heterogeneous ending-weekday WTI returns. Neither source tests a WTI-only
within-month median of weekday means, a continuous CFD, fixed-dollar ATR risk,
or the QM book. Weekday balancing, the exact aggregation, execution, and risk
rules below are declared QM interpretations.

No source alpha, return, probability, density, profit factor, drawdown, trade
count, cost, WTI-only efficacy, CFD equivalence, or portfolio-correlation
statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,631 registry
identities, 1,299 cards, and 45 Strategy Wiki nodes using the actual Company
Reference root and returned `CLEAN`. Evidence is
`artifacts/qm5_wti_mweekday_med_mom_preallocation_dedup_20260823.json`.

Manual family review fixes the mechanic boundaries:

- `QM5_20187_wti-tsmom1m` follows the unpartitioned completed-month endpoint.
- `QM5_41111_wti-mdaybreadth-mom` counts positive and negative individual
  daily returns and requires sign-majority agreement with the raw endpoint.
  This card uses magnitudes, averages by weekday, and does not gate on the raw
  endpoint.
- `QM5_41115_wti-mthirdvote-mom` partitions a month into three consecutive
  time blocks. This card groups five noncontiguous ending weekdays.
- `QM5_41131_wti-mdaily-tailtrim-mom` sorts individual daily returns and
  deletes one observation per tail. This card first averages within weekday
  and takes the median of exactly five bucket means.
- `QM5_20269_wti-medret-mom` takes a median across twelve completed monthly
  returns, not across weekday means inside one completed month.
- `QM5_41055_wti-medcal` takes a historical median of the same calendar month
  across ten years.
- fixed weekday WTI cards own one declared weekday session. This card enters
  only at month boundary and uses every prior-month weekday symmetrically.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only, short-horizon XNG
  oscillator pullback rather than symmetric monthly WTI trend.

The exact WTI carrier, immediately completed month, older boundary, every
daily return ending in the month, ending-weekday partition, per-bucket mean,
five-value median, symmetric direction, consumed attempt, fixed risk, and
next-month lifecycle are jointly load bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_WEEKDAY_BALANCED_MEDIAN_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0, magic `411320000`.
- Decision: first executable tick of a new normalized broker-calendar month,
  within 180 elapsed minutes of the raw current host D1 bar open.
- Signal data: one older boundary close plus every D1 close and ending-weekday
  label in the immediately completed normalized calendar month; current-month
  prices are excluded.
- Position count: zero or one owned WTI position and at most one consumed
  attempt per normalized broker `yyyymm`.
- Expected frequency: approximately 10-12 positions/year; Q02 retires below
  five in any full post-warm-up scored year.

## Energy-Label Normalization

Choose one label offset for the entire decision and history package. Use zero
when the raw current D1 label equals broker date. Permit `+1` calendar day only
when the raw D1 label is exactly one calendar day behind broker date. Apply
the selected offset to current and historical bars uniformly. Reject every
other offset, mixed convention, normalized collision, weekend ending label,
or non-increasing timestamp state. Raw bar-open time, not normalized label
time, owns the 180-minute entry grace.

## Completed-Month And Weekday-Median Contract

Within a fixed 45-bar buffer, the newest completed normalized D1 bar must
belong to the immediately preceding calendar month. Collect every unique bar
in that month and require 17 through 23 sessions plus one adjacent older bar
from the preceding month proving the left boundary. Reverse selected closes
and ending labels into chronological order beginning with the older boundary.

For chronological closes `C[-1], C[0]..C[n-1]` and normalized ending weekdays
`D[0]..D[n-1]`, define:

```text
r[j] = ln(C[j] / C[j-1]), j=0..n-1

for d in Monday..Friday:
    bucket_sum[d]   = sum(r[j] where D[j] == d)
    bucket_count[d] = count(r[j] where D[j] == d)
    bucket_mean[d]  = bucket_sum[d] / bucket_count[d]

weekday_median = ascending(bucket_mean[Monday..Friday])[2]

weekday_median > 0 => BUY XTIUSD.DWX
weekday_median < 0 => SELL XTIUSD.DWX
otherwise          => FLAT
```

Require positive finite closes, finite returns, all five weekday buckets, and
three through five observations in every bucket. Verify that `sum(r)` equals
`ln(C[n-1]/C[-1])` within `1e-10`. Sort exactly five finite means without
rounding and select index two. A zero median, endpoint mismatch, invalid
weekday, invalid count, malformed history, or invalid arithmetic stays flat.
The raw endpoint may agree or disagree and is diagnostic only. Neither signal
magnitude nor endpoint magnitude changes risk.

## Rules

The entry, exit, filter, management, and risk rules below are the complete
authorized baseline. There is no optimization surface, alternate bucket
weighting, or fallback signal.

## 4. Entry Rules

1. Repair malformed or stale owned exposure before entry-only filters.
2. Require exact `XTIUSD.DWX`, D1, EA `41132`, slot zero, registered magic,
   locked fixed-risk inputs, and one uniform energy-label convention.
3. Detect only the first executable D1 bar of a new normalized broker month
   and require no more than 180 elapsed minutes since its raw bar open.
4. Persist the normalized current `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, margin, or order gates. Never retry that month.
5. Require no owned position and no same-magic entry deal already recorded in
   the current normalized broker month.
6. Reconstruct the exact immediately completed normalized month plus one
   older boundary close. Require 17-23 unique month sessions, positive finite
   closes, strict chronology, and no current-month observation.
7. Form one chronological log return ending on every completed-month session
   and verify endpoint identity.
8. Assign every return by normalized ending weekday. Require Monday through
   Friday buckets with counts of three through five. Compute all five means,
   sort ascending, and select exact index two.
9. Buy for a strict positive median and sell for a strict negative median.
   Equality, invalid arithmetic, or malformed history consumes the month flat.
10. Require a valid executable quote and no genuinely positive spread wider
    than 1,500 points. Modeled zero `.DWX` spread is valid.
11. Require completed-bar `ATR(20,D1)`, valid point/digit/volume metadata, and
    valid `RISK_FIXED` sizing.
12. Open at most one market position with a frozen `3.5*ATR(20,D1)` broker
    hard stop and no take-profit.

### Attempt And Restart Contract

The attempt key is terminal-global and scoped by EA and symbol. It stores the
normalized decision `yyyymm` before every fallible gate. Initialization clears
only a future-dated tester residue. Late attachment consumes the missed month
without a trade. Owned deal history and open-position checks are additional
fail-closed guards. A flat signal, invalid history, news/spread/quote/ATR
block, order rejection, stop-out, or restart cannot create a same-month retry.

## 5. Exit Rules

1. Broker hard stop and framework kill-switch closure remain authoritative.
2. Immediately flatten duplicate, wrong-symbol, wrong-magic, wrong-type,
   invalid-volume, invalid-open-time, or stopless owned exposure.
3. Close on the first tick whose normalized broker `yyyymm` is later than the
   month containing the position's normalized entry time.
4. Forty elapsed calendar days is a stale repair only.

There is no target, opposite-signal exit, trail, break-even move, partial
close, Friday flatten, scale-in, pyramid, grid, martingale, hedge, or
discretionary close.

## 6. Filters (No-Trade Module)

- Exact symbol, period, EA ID, slot, magic, risk, news, Friday, and frozen
  strategy inputs.
- Framework kill switch and ownership controls remain authoritative.
- Apply uniform label normalization, entry grace, durable attempt, exact
  month membership, session bounds, boundary proof, chronology, close and
  return validity, endpoint identity, ending weekdays, bucket membership and
  counts, five means, exact median, spread, quote, ATR, sizing, and stop checks
  fail closed.
- Runtime cannot read current-month signal prices, futures curves, inventory,
  volume, open interest, fitted conditional-variance output, external
  files/APIs, trained output, prior pipeline results, or manual signals.

## 7. Trade Management Rules

- Own at most one exact `XTIUSD.DWX` slot-zero position under magic
  `411320000`.
- Manage malformed, later-month, stale, and kill-switch exits every tick
  before entry evaluation.
- Freeze the original hard stop; never widen, trail, remove, or replace it.
- Persist the monthly attempt across restart and supplement it with owned
  position/deal-history checks.
- Never retry, add, pyramid, grid, martingale, partially close, hedge, or
  reverse inside the month.

## Parameters To Test

Q02 has one locked baseline and no optimization surface:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_history_bars_d1` | 45 | bounded month plus boundary buffer |
| `strategy_min_month_sessions` | 17 | completed-month lower bound |
| `strategy_max_month_sessions` | 23 | completed-month upper bound |
| `strategy_weekday_buckets` | 5 | exact Monday-through-Friday partition |
| `strategy_min_bucket_observations` | 3 | per-weekday lower bound |
| `strategy_max_bucket_observations` | 5 | per-weekday upper bound |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_numerical_tolerance` | 1e-10 | endpoint-identity tolerance |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `qm_friday_close_enabled` | false | preserve full-month lifecycle |
| `qm_friday_close_hour_broker` | 21 | locked inactive value |

Every value is locked in the one baseline setfile. Changing the observation
grain, bucket membership or weighting, month, median direction, risk, or
lifecycle requires a new identity and complete G0/Q01 cycle.

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-return direction, monthly formation
and renewal, pooled commodity one-month lineage, and explicit WTI membership.
Meek and Hoelscher supply ending-weekday WTI return heterogeneity and weekday
label lineage. Neither supplies the within-month five-bucket median statistic.

## QM Interpretations

`MOP-MEEK-WTI-MWEEKDAY-MED-2026_S01` fixes the normalized broker month,
17-23 sessions, older boundary, every daily log return ending in the month,
endpoint identity, ending-weekday partition, counts, arithmetic means, exact
five-value median, direction without endpoint agreement, continuous-CFD
mapping, attempt ledger, fixed risk, stop, spread cap, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
repair precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later normalized broker-month closure.
4. Forty-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 timestamps and closes, normalized ending weekday,
broker time, symbol metadata, quotes, completed-bar ATR, framework position/
deal state, and persistent terminal-global attempt state. No external runtime
dataset or calendar exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are false continuation, weekday effects changing sign,
  structural oil-regime breaks, one bucket masking a shock, month-end gaps,
  continuous-CFD roll/basis, financing, energy-label drift, holiday-driven
  bucket imbalance, spread, density below the floor, and realized overlap with
  other trend sleeves.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Kill Criteria

- Retire at zero positions or below five completed positions in any full
  post-warm-up scored year.
- Fail on wrong label/month membership, missing boundary, wrong session count,
  current-month leakage, reversed/omitted/duplicated return, endpoint mismatch,
  weekend label, missing weekday, invalid bucket count, wrong mean or sort,
  wrong median index, accepting exact-zero median, endpoint agreement used as
  a gate, wrong side, repeated attempt, missing stop, invalid fixed-risk mode,
  wrong lifecycle, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing bucket membership, weighting, aggregation,
  direction, carrier, hold, risk, stop, or by adding a fitted scale, endpoint
  agreement, seasonality, event, volatility, external, or prior-result state.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS_WITH_WEEKDAY_BALANCING_TRANSLATION_RISK | Peer-reviewed JFE momentum paper and peer-reviewed open-access energy weekday paper, DOIs, complete-read evidence, durable hashes, explicit WTI membership, and governed child packet; the exact weekday median is disclosed as untested. |
| R2 | PASS | Exact label, month, boundary, sessions, returns, identity, weekdays, counts, means, sort, median, side, attempt, fixed risk, stop, spread, and lifecycle. |
| R3 | PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK | Registered native `XTIUSD.DWX` D1 history and MT5 state supply every runtime field. |
| R4 | PASS | Deterministic timestamp, logarithm, arithmetic, sorting, comparison, ATR, and execution state only; no trained, conditional-variance, or banned runtime signal. |

## Falsification And Requalification

Q02 retires rather than tunes on zero positions, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics, or
any label, month, session, boundary, return, endpoint, weekday, bucket, mean,
median, side, attempt, risk, stop, lifecycle, or determinism defect.

Changing the bucket membership or weighting, aggregation, direction,
observation inclusion, carrier, risk, stop, hold, retry policy, or adding
endpoint agreement, seasonality, event, volatility, external, or prior-result
state requires a new card and full pipeline cycle.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period/ID/slot, month clock, label, history, returns, weekday buckets, means, median, attempt, spread, ATR, sizing | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed/later-month/stale lifecycle repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| later-month and stale exit | Trade Close | `Strategy_ExitSignal` plus lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove raw and `+1` label equivalence; mixed-label rejection; first
month bar and 180-minute timing; year boundaries; 17/20/23-session acceptance
and 16/24 rejection; older boundary proof; every return ending in the month
once; endpoint identity; Monday-through-Friday assignment; weekend rejection;
3/4/5 per-bucket acceptance and missing/2/6 rejection; positive, negative,
and zero bucket values; per-bucket means; exact five-value median; raw endpoint
agreement and disagreement both accepted; no current-month leakage; durable
attempt timing; fixed-risk stop sizing; malformed/later-month/stale repair;
card lint; strict compile/build checks; setfile schema; resolver identity; and
deterministic reference tests before Q02 handoff.

Q02 alone measures density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-23 | initial WTI completed-month weekday-balanced median momentum card | G0 | APPROVED |
| v2 | 2026-08-23 | EA source, reference tests, SPEC, and fixed-risk preset complete; governed compile held at fleet CPU ceiling | Q01 | SOURCE_READY_COMPILE_HELD |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-23 | APPROVED | `decisions/2026-08-23_qm5_41132_wti_monthly_weekday_median_momentum_g0.md` |
| Q01 Build Validation | 2026-08-23 | SOURCE_READY_COMPILE_HELD | `docs/ops/evidence/2026-08-23_qm5_41132_wti_weekday_median_build_cpu_ceiling.md`; compile work item `690cf433-d157-49d0-aaa8-57b58431a845` pending |
| Q02 Baseline Screening | 2026-08-23 | NOT_ENQUEUED_CPU_CEILING | no EX5; measured CPU 98.1% above the 97% claim ceiling, so the OWNER stop condition binds |

## Safety Boundary

This card requests a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation claim, correlation waiver, or live use.
