---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-MDAILY-TAILTRIM-MOM-2026_S01
variant_id: MOP-WTI-MDAILY-TAILTRIM-MOM-2026_S01
source_id: MOP-WTI-MDAILY-TAILTRIM-MOM-2026
ea_id: QM5_41131
slug: wti-mdaily-tailtrim-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41131_wti-mdaily-tailtrim-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-23
created_by: Research+Development
last_updated: 2026-08-23
g0_status: APPROVED
g0_decision: decisions/2026-08-23_qm5_41131_wti_monthly_daily_tail_trim_momentum_g0.md
source_approval: decisions/2026-08-23_wti_monthly_daily_tail_trim_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250, DOI 10.1016/j.jfineco.2011.11.003."
source_citations:
  - type: peer_reviewed_paper_bounded_packet
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded child strategy-seeds/sources/MOP-WTI-MDAILY-TAILTRIM-MOM-2026/source.md"
    quality_tier: A
    role: wti_own_price_one_month_continuation_and_monthly_clock
strategy_mechanic: normalized-month-boundary-wti-immediately-completed-seventeen-to-twenty-three-session-daily-log-returns-ascending-sort-delete-single-minimum-and-maximum-inner-sum-sign-continuation-one-month-hold
sources:
  - "[[sources/MOP-WTI-MDAILY-TAILTRIM-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-month-daily-robust-direction]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-daily-tail-trim]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, completed-month-daily-order-statistic, robust-direction, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 411310000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-12 completed WTI positions per full post-warm-up year after exact month, arithmetic, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 11
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WITHIN_MONTH_ROBUST_AGGREGATION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PENDING_BUILD
q02_status: NOT_ENQUEUED_Q01_PENDING
review_focus: "Falsify a direct-WTI completed-month daily tail-trim continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact month boundary, 17-23 returns ending in the month, older boundary inclusion, endpoint identity, ascending sort, deletion of exactly one minimum and maximum, inner-sum direction independent of the raw endpoint, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_month_bar, immediately_completed_calendar_month, bounded_month_session_count, older_boundary_close, every_return_ending_in_month_once, chronological_log_return_orientation, endpoint_identity, ascending_return_sort, single_minimum_deletion, single_maximum_deletion, exact_inner_sum, raw_endpoint_not_a_gate, no_current_month_leakage, monthly_attempt_state, risk_mode_dual, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER mission 2026-08-23; R1 peer-reviewed WTI own-return source with daily-horizon robust-aggregation translation disclosed; R2 exact month/return/endpoint/sort/deletion/inner-sum/direction/attempt/risk/lifecycle; R3 native XTI D1 with label and CFD-basis risk; R4 deterministic arithmetic without banned signal; pre-allocation dedup CLEAN and post-allocation only expected self-hits."
---

# QM5_41131 WTI Completed-Month Daily Tail-Trim Momentum

## Hypothesis

WTI adjusts to production, inventory, transport, refining, hedging, and demand
shocks through persistent physical-energy regimes. A completed month's raw
endpoint can nevertheless be dominated by one exceptional gain or loss.
Deleting exactly the single best and single worst daily return and following
the sign of all remaining daily returns tests whether the central monthly path
contains more durable directional information for the next broker month.

This is direct crude-oil exposure outside the certified XAU, SP500, NDX, and
XNG carriers. Different instrument and logic do not prove profitability or
decorrelation. Q02 owns density and baseline economics; unchanged Q09 alone
owns realized portfolio overlap.

## Source Traceability And Claim Boundary

The sole source of record is
`strategy-seeds/sources/MOP-WTI-MDAILY-TAILTRIM-MOM-2026/source.md`, SHA-256
`B157B166929E07B818E7C31816AC00B97EEF495E180C7E55F03E268A86C0A559`,
authorized before extraction by
`decisions/2026-08-23_wti_monthly_daily_tail_trim_momentum_source_approval.md`
at commit `77dca19cb` and extracted at commit `6e8df9e35`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons, a monthly formation/renewal family, a pooled commodity `k=1`, `h=1`
implementation, and explicit WTI membership. They do not test a WTI-only
within-month daily-return tail trim, a continuous CFD, fixed-dollar ATR risk,
or the QM book. The daily horizon, exact single observation deleted from each
tail, execution, and risk rules below are declared QM interpretations.

No source alpha, return, probability, density, profit factor, drawdown, trade
count, cost, WTI-only efficacy, CFD equivalence, or portfolio-correlation
statistic is imported.

## Non-Duplicate Decision

Before allocation, the fail-closed canonical checker scanned 4,630 registry
identities, 1,298 cards, and 45 Strategy Wiki nodes using the actual Company
Reference root and returned `CLEAN`. After atomic reservation it found only
the exact slug and strategy-ID self-hits for `QM5_41131`. Evidence is in the
pre- and post-allocation receipts under `artifacts/`.

Manual family review fixes the mechanic boundaries:

- `QM5_20187_wti-tsmom1m` follows the full completed-month endpoint. One
  extreme session can determine its direction; this card removes exactly the
  best and worst sessions before selecting direction.
- `QM5_20270_wti-trimmean-mom` sorts twelve disjoint completed monthly returns
  spanning a year and deletes two observations per tail. This card sorts one
  completed month's 17-23 daily returns and deletes one observation per tail.
- `QM5_41111_wti-mdaybreadth-mom` counts daily signs and requires raw endpoint
  agreement. This card retains magnitudes, counts no signs, and deliberately
  does not use raw endpoint direction as a gate.
- `QM5_41124_wti-mrms-coherence-mom` divides the untrimmed monthly mean by
  daily RMS; `QM5_41126_wti-mpath-eff-mom` divides the raw endpoint by the L1
  path. Neither sorts or deletes observations.
- `QM5_41127_wti-mdaily-persist-mom` centers daily returns and multiplies
  adjacent observations before following the raw endpoint. This card uses no
  autocorrelation, centered variance, chronology after return construction,
  or endpoint-direction gate.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only, short-horizon XNG
  oscillator pullback rather than symmetric monthly WTI robust momentum.

The exact WTI carrier, immediately completed month, older boundary, every
daily return ending in the month, ascending sort, deletion of exactly one
array endpoint per tail, inner-return sum, symmetric direction, consumed
attempt, fixed risk, and next-month lifecycle are jointly load bearing.
Verdict:
`CLEAN_WTI_COMPLETED_MONTH_DAILY_SINGLE_TAIL_TRIM_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Market, Clock, And State

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0, magic `411310000`.
- Decision: first executable tick of a new normalized broker-calendar month,
  within 180 elapsed minutes of the raw current host D1 bar open.
- Signal data: one older boundary close plus every D1 close in the immediately
  completed normalized calendar month; current-month prices are excluded.
- Position count: zero or one owned WTI position and at most one consumed
  attempt per normalized broker `yyyymm`.
- Expected frequency: approximately 10-12 positions/year; Q02 retires below
  five in any full post-warm-up scored year.

## Energy-Label Normalization

Choose one label offset for the entire decision and history package. Use zero
when the raw current D1 label equals broker date. Permit `+1` calendar day only
when the raw D1 label is exactly one calendar day behind broker date. Apply
the selected offset to current and historical bars uniformly. Reject every
other offset, mixed convention, normalized collision, or non-increasing
timestamp state. Raw bar-open time, not normalized label time, owns the
180-minute entry grace.

## Completed-Month And Statistical Contract

Within a fixed 45-bar buffer, the newest completed normalized D1 bar must
belong to the immediately preceding calendar month. Collect every unique bar
in that month and require 17 through 23 sessions plus one adjacent older bar
from the preceding month proving the left boundary. Reverse the selected
closes into chronological order beginning with the older boundary.

For chronological closes `C[-1], C[0]..C[n-1]`, define:

```text
r[j]      = ln(C[j] / C[j-1]), j=0..n-1
raw_sum   = sum(r[j]), j=0..n-1
sorted    = ascending copy of r[0..n-1]
inner_sum = sum(sorted[j]), j=1..n-2

inner_sum > 0 => BUY XTIUSD.DWX
inner_sum < 0 => SELL XTIUSD.DWX
otherwise     => FLAT
```

Require positive finite closes and finite returns/sums. Verify `raw_sum`
equals `ln(C[n-1]/C[-1])` within `1e-10`. Delete exactly sorted index zero and
sorted index `n-1`, retaining 15 through 21 observations. Tied extremes and
zero constituent returns are valid. A zero inner sum, endpoint mismatch,
invalid numerical state, wrong month, wrong count, or missing boundary stays
flat. Raw endpoint sign may agree or disagree with the signal and is
diagnostic only. Neither signal magnitude nor endpoint magnitude changes
risk.

## Rules

The entry, exit, filter, management, and risk rules below are the complete
authorized baseline. There is no optimization surface, alternate tail count,
or fallback signal.

## 4. Entry Rules

1. Repair malformed or stale owned exposure before entry-only filters.
2. Require exact `XTIUSD.DWX`, D1, EA `41131`, slot zero, registered magic,
   locked fixed-risk inputs, and one uniform energy-label convention.
3. Detect only the first executable D1 bar of a new normalized broker month
   and require no more than 180 elapsed minutes since its raw bar open.
4. Persist the normalized current `yyyymm` before history, signal, news,
   spread, quote, ATR, sizing, or order gates. Never retry that month.
5. Require no owned position and no same-magic entry deal already recorded in
   the current normalized broker month.
6. Reconstruct the exact immediately completed normalized month plus one
   older boundary close. Require 17-23 unique month sessions, positive finite
   closes, strict chronological order, and no current-month observation.
7. Form one chronological log return ending on every completed-month session,
   verify endpoint identity, sort a copy ascending, exclude exactly indexes
   zero and `n-1`, and sum exactly indexes `1..n-2`.
8. Buy for strict positive inner sum and sell for strict negative inner sum.
   Equality, invalid arithmetic, or malformed history consumes the month flat.
9. Require a valid executable quote and no genuinely positive spread wider
   than 1,500 points. Modeled zero `.DWX` spread is valid.
10. Require completed-bar `ATR(20,D1)`, valid point/digit/volume metadata, and
    valid `RISK_FIXED` sizing.
11. Open at most one market position with a frozen `3.5*ATR(20,D1)` broker
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
  return validity, endpoint identity, sort, exact deletion endpoints, inner
  sum, spread, quote, ATR, sizing, and stop checks fail closed.
- Runtime cannot read current-month signal prices, futures curves, inventory,
  volume, open interest, events, external files/APIs, trained output, prior
  pipeline results, or manual signals.

## 7. Trade Management Rules

- Own at most one exact `XTIUSD.DWX` slot-zero position under magic
  `411310000`.
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
| `strategy_trim_each_tail` | 1 | exact deleted array elements per tail |
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_numerical_tolerance` | 1e-10 | endpoint-identity tolerance |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry-cost guard |
| `qm_friday_close_enabled` | false | preserve full-month lifecycle |
| `qm_friday_close_hour_broker` | 21 | locked inactive value |

Every value is locked in the one baseline setfile. Changing the observation
grain, month, trim count, retained indexes, direction, risk, or lifecycle
requires a new identity and complete G0/Q01 cycle.

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-return direction, monthly formation and
renewal, pooled commodity one-month lineage, and explicit WTI membership. They
do not supply the within-month daily-return horizon or trimmed statistic.

## QM Interpretations

`MOP-WTI-MDAILY-TAILTRIM-MOM-2026_S01` fixes the normalized broker month,
17-23 sessions, older boundary, every daily log return ending in the month,
endpoint identity, ascending sort, exactly one omitted observation per tail,
inner-sum direction without endpoint agreement, continuous-CFD mapping,
attempt ledger, fixed risk, stop, spread cap, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
repair precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later normalized broker-month closure.
4. Forty-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 timestamps and closes, broker time, symbol
metadata, quotes, completed-bar ATR, framework position/deal state, and
persistent terminal-global attempt state. No finite external runtime dataset
or calendar exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are false continuation, a structural oil-regime break, tail
  deletion hiding useful shock information, month-end gaps, continuous-CFD
  roll/basis, financing, energy-label drift, session sparsity, spread,
  density below the floor, and realized overlap with other trend sleeves.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Kill Criteria

- Retire at zero positions or below five completed positions in any full
  post-warm-up scored year.
- Fail on wrong label/month membership, missing boundary, wrong session count,
  current-month leakage, reversed/omitted/duplicated return, endpoint mismatch,
  wrong sort, deleting other than one array endpoint per tail, wrong retained
  indexes, accepting exact-zero inner sum, endpoint agreement used as a gate,
  wrong side, repeated attempt, missing stop, invalid fixed-risk mode, wrong
  lifecycle, or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing the trim count, return inclusion,
  direction, carrier, hold, risk, stop, or by adding a fitted center, scale,
  sign count, persistence, volatility, seasonality, event, external, or
  prior-result state.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS_WITH_WITHIN_MONTH_ROBUST_AGGREGATION_TRANSLATION_RISK | Peer-reviewed JFE paper, DOI, complete-read evidence, durable hashes, explicit WTI membership, and governed child packet; daily tail trimming is disclosed as an untested translation. |
| R2 | PASS | Exact label, month, boundary, sessions, returns, identity, sort, deletion, retained sum, side, attempt, fixed risk, stop, spread, and lifecycle. |
| R3 | PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_BASIS_RISK | Registered native `XTIUSD.DWX` D1 history and MT5 state supply every runtime field. |
| R4 | PASS | Deterministic timestamp, logarithm, sorting, arithmetic, comparison, ATR, and execution state only; no trained or banned signal. |

## Falsification And Requalification

Q02 retires rather than tunes on zero positions, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics, or
any label, month, session, boundary, return, endpoint, sort, deletion, side,
attempt, risk, stop, lifecycle, or determinism defect.

Changing the trim count, retained indexes, direction, observation inclusion,
carrier, risk, stop, hold, retry policy, or adding endpoint agreement, sign
breadth, persistence, volatility, calendar, event, external, or prior-result
state requires a new card and full pipeline cycle.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period/ID/slot, month clock, label, history, returns, sort, tail deletion, inner sum, attempt, spread, ATR, sizing | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed/later-month/stale lifecycle repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| later-month and stale exit | Trade Close | `Strategy_ExitSignal` plus lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove raw and `+1` label equivalence; mixed-label rejection; first
month bar and 180-minute timing; year boundaries; 17/20/23-session acceptance
and 16/24 rejection; older boundary proof; every return ending in the month
once; positive, negative, and zero constituent returns; endpoint identity;
ascending sort; distinct and tied extremes; deletion of exactly one minimum
and maximum; positive, negative, and exact-zero inner sums; raw endpoint
agreement and disagreement both accepted; no current-month leakage; durable
attempt timing; fixed-risk stop sizing; malformed/later-month/stale repair;
card lint; strict compile/build checks; setfile schema; resolver identity; and
deterministic reference tests before Q02 handoff.

Q02 alone measures density and baseline economics. Q09 alone may establish
realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-23 | initial WTI completed-month daily single-tail-trim momentum card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-23 | APPROVED | `decisions/2026-08-23_qm5_41131_wti_monthly_daily_tail_trim_momentum_g0.md` |
| Q01 Build Validation | 2026-08-23 | PENDING_BUILD | source implementation and strict compile required |
| Q02 Baseline Screening | 2026-08-23 | NOT_ENQUEUED_Q01_PENDING | strict compile, EX5, final set binding, and Q01 PASS required |

## Safety Boundary

This card requests a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation claim, correlation waiver, or live use.
