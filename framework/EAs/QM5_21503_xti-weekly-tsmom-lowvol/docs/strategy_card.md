---
card_schema_version: 2
type: strategy
strategy_id: ZHAO-ST-MOMREV-2026_XTI_S02
variant_id: ZHAO-ST-MOMREV-2026_XTI_S02
source_id: 28681f5d-aa78-584e-9698-750d1402e485
ea_id: QM5_21503
slug: xti-weekly-tsmom-lowvol
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_21503_xti-weekly-tsmom-lowvol_card.md
execution_contract_status: APPROVED
created: 2026-08-17
created_by: Research+Development
last_updated: 2026-08-17
g0_status: APPROVED
g0_decision: decisions/2026-08-17_wti_exact_week_lowvol_momentum_g0.md
source_approval: decisions/2026-08-17_wti_exact_week_lowvol_momentum_source_approval.md
source_author: "Shen Zhao; Yiyi Ding; Jianfeng Yu; Wenjin Kang"
source_authors: "Shen Zhao; Yiyi Ding; Jianfeng Yu; Wenjin Kang"
source_citation: "Zhao, Ding, Yu, and Kang (2026), Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets, SSRN 6425598, DOI 10.2139/ssrn.6425598."
source_citations:
  - type: academic_working_paper_bounded_abstract_packet
    citation: "Zhao, S., Ding, Y., Yu, J., and Kang, W. (2026). Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets."
    location: "SSRN 6425598; DOI 10.2139/ssrn.6425598; bounded accessible-material record in strategy-seeds/sources/28681f5d-aa78-584e-9698-750d1402e485/source.md"
    quality_tier: B_WITH_ACCESS_LIMIT
    role: weekly_commodity_continuation_and_low_volatility_conditioning_context
strategy_mechanic: exact-prior-monday-friday-wti-close-return-sign-continuation-only-when-five-return-realized-volatility-ranks-in-lower-tercile-of-forty-older-nonoverlapping-blocks
sources:
  - "[[sources/28681f5d-aa78-584e-9698-750d1402e485]]"
concepts:
  - "[[concepts/short-term-time-series-momentum]]"
  - "[[concepts/low-volatility-continuation]]"
  - "[[concepts/non-overlapping-volatility-rank]]"
indicators:
  - "[[indicators/completed-log-return]]"
  - "[[indicators/realized-volatility]]"
  - "[[indicators/broker-calendar]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, crude-oil, time-series-momentum, low-volatility-regime, exact-week, weekly-entry, friday-close, atr-hard-stop, low-frequency, symmetric-long-short]
markets: [commodities, energy, crude_oil]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
symbol_slot: 0
magic: 215030000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-18 completed WTI positions per full post-warm-up year after the fixed lower-tercile volatility gate and exact-week holiday exclusions; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 14
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_ACCESS_AND_PROXY_RISK
r2_mechanical: PASS
r3_data_available: PASS_FOR_DISCLOSED_PROXY
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: PENDING
review_focus: "Falsify an exact-calendar direct-WTI weekly continuation sleeve outside the certified XAU/SP500/NDX/XNG book. Verify the completed Monday-Friday endpoints, non-overlapping five-return RV blocks, inclusive lower-tercile rank, no late/repeated Monday entry, and Friday flattening; Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_weekday_sequence, completed_price_endpoints, no_current_bar_leakage, nonoverlapping_volatility_blocks, inclusive_low_tercile_rank, monday_decision_clock, weekly_attempt_state, risk_mode_dual, friday_close_enabled, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "R1 one named DOI-bearing source with complete bounded accessible-material evidence and explicit access/proxy limits; R2 exact weekday sequence, return and RV formulas, disjoint baseline, fixed rank, timing, retry, risk, stop, spread and lifecycle; R3 native XTI D1 proxy only; R4 deterministic arithmetic without trained or banned signal logic; exact identity is a dormant reservation and manual review separates rolling low-volatility, split-week, volume-switch, and incumbent oscillator families."
---

# QM5_21503 XTI Exact-Week Low-Volatility Momentum

## Hypothesis

A fully completed Monday-through-Friday WTI move may continue through the
next broker week when the signal week's daily path was unusually quiet
relative to older, non-overlapping five-return blocks. The candidate follows
the completed weekly return sign only when its realized volatility ranks in a
fixed lower tercile, enters on the next genuine Monday, and closes by Friday.

This is a falsifiable price-only proxy. The source does not test this exact
calendar, estimator, WTI CFD carrier, fixed Monday/Friday clock, or the QM
portfolio. Direct crude exposure is economically different from the current
XAU/SP500/NDX/XNG book, but Q09 alone may establish realized correlation.

## Source Traceability And Claim Boundary

The sole source of record is the governed packet
`strategy-seeds/sources/28681f5d-aa78-584e-9698-750d1402e485/source.md`, approved
for this extraction in
`decisions/2026-08-17_wti_exact_week_lowvol_momentum_source_approval.md` at
commit `398b88395`.

Zhao, Ding, Yu, and Kang supply bounded accessible context that a residual
component of weekly commodity returns predicts the following week positively
and that short-term momentum strengthens when volatility or uncertainty is
low. Their full paper was inaccessible, and their actual decomposition uses
investor-position information unavailable to this EA.

The exact completed-week sequence, native-price proxy, five-return realized
volatility, forty-block non-overlapping rank, lower-tercile boundary, broker-
calendar normalization, Monday opening grace, continuous-CFD carrier, Friday
close, hard stop, fixed-dollar risk, spread cap, and attempt ledger are
disclosed QM choices. No source return, alpha, coefficient, significance,
trade density, drawdown, cost, WTI-only result, CFD equivalence,
decorrelation, or portfolio result transfers.

## Non-Duplicate Decision

The pre-card inventory contained 4,526 EA-registry rows, 622 root-card files,
575 approved-card files, and 3,630 EA directories. Exact review found only the
dormant 2026-08-13 reservation for `QM5_21503`; it had no card, directory,
magic, setfile, binary, or pipeline work item. Manual review fixes the
load-bearing boundaries:

- `QM5_13049_xti-1w-mom-vol` uses any-new-day rolling five-D1 returns, a 1.25%
  magnitude threshold, overlapping 20-D1 volatility observations, a 55th-
  percentile cap, and reversal/time exits. This card uses an exact completed
  Monday-Friday week, no magnitude threshold, five-return RV, forty older
  non-overlapping blocks, a fixed lower-tercile rank, and Friday flattening.
- `QM5_13101_xng-1w-mom-vol` is the same rolling/magnitude family on natural
  gas, not this WTI exact-calendar carrier.
- `QM5_41020_wti-wclose-mom` reads only a Tuesday-Friday segment and exits on
  Wednesday; `QM5_41022_wti-wdual-mom` requires two within-week segment signs
  to agree. Neither computes or ranks realized volatility.
- `QM5_21521_wti-flow-switch` ranks tick-volume blocks and may reverse the
  completed return. This card reads no volume and always follows the admitted
  weekly sign.
- WTI event, calendar, inventory, roll, carry, range-breakout, longer-horizon
  trend, reversal, and relative-value families use different state objects,
  clocks, directions, or topology.
- `QM5_12567_cum-rsi2-commodity` is a long-only XNG oscillator pullback. This
  card is symmetric direct-WTI weekly continuation without an oscillator.

Verdict: `CLEAN_RESERVED_UNBUILT_WTI_EXACT_WEEK_LOW_TERCILE_MOMENTUM`.

## Markets, Timeframe, And Cadence

- Exact host and target: `XTIUSD.DWX`.
- Timeframe: D1; EA `QM5_21503`; magic slot 0; magic `215030000`.
- Decision: first executable tick of a genuine broker Monday, within 180
  minutes of the executable D1 opening boundary.
- Formation: one exact completed Monday-Friday week and forty immediately
  older, non-overlapping five-return realized-volatility blocks.
- Signal: follow the exact week's close-return sign only when inclusive RV
  rank count is at most 13 of 40.
- Ordinary exit: framework Friday close at broker hour 21.
- Expected cadence: approximately 10-18 completed positions per full
  post-warm-up year; retire below five/year.

## Formula

At the current Monday, completed D1 closes are indexed newest-first. Shifts
`1..6` must be prior Friday through the preceding Friday anchor. Define the
five chronological signal-week returns:

```text
r[k] = log(Close[5-k] / Close[6-k]), k = 0..4
weekly_return = sum(r[k])
current_rv = sqrt(sum(r[k]^2))

require abs(weekly_return - log(Close[1] / Close[6])) <= 1e-10
```

For baseline block `b=0..39`, use five older return intervals:

```text
base_r[b,k] = log(Close[6 + 5*b + k] / Close[7 + 5*b + k]), k = 0..4
base_rv[b] = sqrt(sum(base_r[b,k]^2))
rank_count = count(base_rv[b] <= current_rv), b = 0..39

eligible only when rank_count <= 13
weekly_return > 0 => BUY
weekly_return < 0 => SELL
otherwise         => flat
```

Signal and baseline blocks may share boundary closes but never share a return
interval. All 206 required closes are completed before the current Monday.
No annualization, demeaning, fitted threshold, magnitude scaling, or current-
bar value enters the signal.

## Rules

The rules below are the complete authorized baseline. There is no optimizer
surface and no fallback to a return threshold, moving line, oscillator,
volume, event, curve, inventory, carry, or external-data signal.

### 4. Entry Rules

1. Require exact EA ID `21503`, exact chart symbol `XTIUSD.DWX`, D1, and magic
   slot 0. Evaluate entry only on a new D1 bar.
2. Require the broker clock to be Monday. Accept only a native same-day D1
   label or the governed uniform `+1` calendar-day energy normalization when
   the raw label is 24-48 hours behind broker time. Apply one offset to all
   signal-week labels and never shift an individual bar.
3. Require the six immediately preceding completed normalized labels, newest
   first, to be prior Friday, Thursday, Wednesday, Tuesday, Monday, and the
   preceding Friday at exact calendar offsets 3, 4, 5, 6, 7, and 10 days.
   Holidays, missing bars, duplicates, or any other sequence consume the week
   flat.
4. Derive the attempt key from the exact broker Monday `yyyymmdd`. Persist it
   before history, signal, news, spread, quote, ATR, sizing, or order gates.
   Never retry the Monday after any flat, blocked, failed, or stopped outcome.
5. Compute elapsed time from broker time and raw D1 label modulo one day.
   Require 0 through 180 minutes. Late attachment consumes the week without a
   backfill.
6. Load exactly 206 completed closes, require strictly descending timestamps,
   unique normalized dates, and positive finite values, and compute the signal
   and forty baseline RVs exactly as declared.
7. Require finite arithmetic, positive `current_rv`, nonnegative finite
   baseline RVs, and return reconciliation within `1e-10`.
8. Count baseline RVs less than or equal to current RV. Admit only counts 0
   through 13. Inclusive ties above the boundary remain flat.
9. BUY only for a strictly positive admitted weekly return and SELL only for a
   strictly negative one. Exact zero remains flat. Return and RV magnitudes
   never alter risk.
10. Require completed-bar `ATR(20,D1)` and place one frozen hard stop at
    `3.0 * ATR`. Use no take-profit.
11. Require no owned position, a valid positive quote, and no genuinely
    positive spread wider than 1,500 points. A modeled zero `.DWX` spread is
    valid.
12. Open at most one market position. No pending order, retry, second entry,
    scale-in, grid, martingale, hedge, or pyramid exists.

### 5. Exit Rules

1. Framework Friday close is enabled and closes owned exposure at broker hour
   21. It is the ordinary lifecycle exit.
2. Close exposure surviving into a later broker week at the first observable
   D1 boundary. This is stale repair, not a new signal.
3. Close after eight elapsed calendar days as a final stale guard.
4. Close owned exposure with invalid open time, volume, price, symbol, magic,
   direction, or missing hard stop.
5. The framework kill switch and frozen broker hard stop remain authoritative.
6. No target, opposite-signal exit, trail, break-even move, partial close,
   discretionary exit, or Friday-close override is authorized.

### 6. Filters (No-Trade Module)

- Exact `XTIUSD.DWX`, D1, EA ID 21503, slot 0, and locked strategy inputs.
- Backtest risk exclusively `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Both news axes and the legacy news mode are OFF because the signal uses only
  completed native prices and its weekly lifecycle is fixed.
- Friday close is ON at broker hour 21 and is load-bearing.
- Week identity, label normalization, opening grace, attempt, history order,
  prices, return reconciliation, RV arithmetic, non-overlap, inclusive rank,
  direction, ATR, quote, spread, sizing, and ownership all fail closed.
- Management and close paths remain reachable before every entry-only gate.

### 7. Trade Management Rules

- Own at most one `XTIUSD.DWX` position under magic `215030000`.
- Preserve the original hard stop; never widen, trail, or remove it.
- Run malformed and stale ownership repair on every tick before entry logic.
- Persist the last attempted broker-Monday key in terminal global state so a
  restart cannot create a second weekly attempt.
- Recover lifecycle timing from the owned position or deal record; never infer
  a replacement entry after attachment.
- Do not add, hedge, reverse, partially close, grid, or pyramid.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- One fixed-dollar budget applies to the single WTI position and is sized from
  the frozen stop distance through the V5 risk helper.
- Baseline hard stop: `3.0 * ATR(20,D1)` from completed data; no target.
- Invalid tick size, tick value, stop distance, volume step, minimum volume,
  quote, or computed lot size consumes the week without an order.
- WTI gaps, continuous-CFD basis and financing, energy-label mapping, source
  access limits, the investor-position-to-price proxy, and lower-tercile
  sampling are first-order risks.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Parameters To Test

Q02 has one locked baseline and no parameter sweep:

| Input | Locked value | Role |
|---|---:|---|
| `strategy_baseline_blocks` | 40 | older non-overlapping RV blocks |
| `strategy_rank_max_count` | 13 | inclusive lower-tercile gate |
| `strategy_atr_period` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.0 | frozen hard-stop distance |
| `strategy_max_spread_points` | 1500 | entry cost guard |
| `strategy_entry_grace_minutes` | 180 | restart-safe Monday boundary |
| `strategy_max_hold_days` | 8 | stale repair only |
| `strategy_reconcile_tolerance` | 1e-10 | weekly endpoint identity |
| `qm_friday_close_enabled` | true | ordinary exit |
| `qm_friday_close_hour_broker` | 21 | ordinary exit hour |

Changing the block count, rank boundary, inclusivity, week definition,
direction, or lifecycle creates a new identity and requires requalification.

## Data Requirements

Native `XTIUSD.DWX` D1 time and close history, broker clock, executable quote,
modeled spread, completed-bar ATR, symbol contract metadata, positions, deal
history, and terminal global variables only. No futures chain, position/COT
series, inventory, volume, open interest, file, API, analyst forecast, trained
output, optimizer result, or portfolio state enters the signal.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact week, attempt, history, return/RV blocks, rank, spread, ATR, sizing | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed and stale ownership repair | Trade Management | `Strategy_ManageOpenPosition` |
| framework Friday lifecycle | Trade Close | `Strategy_ExitSignal` leaves ordinary Friday close to the framework |
| kill switch, ownership, risk mode | Framework No-Trade | standard orchestration |
| news OFF | News hooks | `Strategy_NewsFilterHook` returns false; both axes OFF |

## Falsification And Requalification

Retire rather than tune on zero trades, fewer than five completed positions per
full post-warm-up year, nonpositive governed economics, wrong weekday or
endpoint reconstruction, current-bar leakage, overlapping return intervals,
wrong inclusive rank, late or repeated entry, direction different from the
completed weekly sign, survival beyond Friday without repair, invalid risk
mode, registry mismatch, or nondeterminism.

No weak result may be rescued by adding a return threshold, widening the rank
gate, switching to overlapping volatility windows, accepting a holiday-shifted
week, changing direction, adding an exit signal, or extending the hold.

## Validation Plan

Q01 must prove:

1. exact prior Monday-Friday plus anchor sequences pass and holiday-shifted,
   duplicate, or malformed sequences fail;
2. signal and baseline index sets share no return interval and exclude the
   current Monday bar;
3. five daily log returns reconcile to the Friday-to-Friday return;
4. inclusive rank counts 0..13 pass while 14..40 and boundary ties fail;
5. positive and negative admitted returns map to BUY and SELL, while exact
   zero or invalid RV remains flat;
6. the persistent attempt prevents same-Monday retry after failure or restart;
7. sizing uses fixed-dollar risk and the frozen completed-bar ATR stop;
8. Friday and stale repair remain reachable independently of entry gates; and
9. card lint, registry validation, resolver verification, reference tests,
   strict compile, setfile schema, and static Q01 checks pass.

Q02 alone may establish observed density and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Version History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-17 | initial exact-week low-volatility WTI card | G0 | APPROVED |
| v1-build | 2026-08-17 | deterministic EA, 13 passing mechanic fixtures, fixed-risk set, strict compile and build gates | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-17 | APPROVED | `decisions/2026-08-17_wti_exact_week_lowvol_momentum_g0.md` |
| Q01 Build Validation | 2026-08-17 | PASS | 13/13 reference fixtures; strict compile 0 errors/0 warnings; target build check 0 failures/0 warnings; static P1 artifact validation PASS |
| Q02 Baseline Screening | 2026-08-17 | PENDING | target-only capacity gate and enqueue required |

## Safety Boundary

This card authorizes one branch-only non-live build, one D1 `RISK_FIXED`
backtest setfile, strict Q01 validation, and one paced Q02 enqueue if capacity
permits. It does not authorize a manual backtest, tester control, live/demo/
shadow/stress/optimization preset, AutoTrading, `T_Live`, a deploy or T_Live
manifest, portfolio-gate change, portfolio admission, or correlation waiver.
