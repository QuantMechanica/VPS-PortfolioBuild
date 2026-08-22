---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-MBODY-DOMINANCE-MOM-2026_S01
variant_id: MOP-WTI-MBODY-DOMINANCE-MOM-2026_S01
source_id: MOP-WTI-MBODY-DOMINANCE-MOM-2026
ea_id: QM5_41106
slug: wti-mbody-dominance-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41106_wti-mbody-dominance-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-22
created_by: Research+Development
last_updated: 2026-08-22
g0_status: APPROVED
g0_decision: decisions/2026-08-22_qm5_41106_wti_monthly_body_dominance_momentum_g0.md
source_approval: decisions/2026-08-22_wti_monthly_body_dominance_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-WTI-MBODY-DOMINANCE-MOM-2026/source.md"
    quality_tier: A
    role: monthly_own_price_continuation_and_wti_carrier_lineage
strategy_mechanic: normalized-month-boundary-wti-one-immediately-completed-monthly-ohlc-package-strict-real-body-greater-than-one-half-of-range-own-body-sign-continuation-one-month-hold
sources:
  - "[[sources/MOP-WTI-MBODY-DOMINANCE-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-month-body-dominance]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-real-body-share]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, completed-month-body-dominance, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 411060000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 5-9 completed WTI positions per full post-warm-up year after exact monthly history, strict majority-body qualification, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 7
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_MONTHLY_BODY_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a direct-WTI completed-month body-dominance trend outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact month boundaries, one immediately completed 17-23-session monthly OHLC package, strict 2*abs(close-open)>high-low, own-body side, equality flat, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_month_bar, immediate_completed_calendar_month, completed_monthly_ohlc, bounded_month_session_count, first_open_final_close, strict_majority_body_share, own_body_direction, no_current_month_leakage, monthly_attempt_state, risk_mode_dual, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized WTI sleeve; R1 complete-read peer-reviewed WTI monthly-continuation source with body-share translation risk; R2 locked monthly OHLC/body/attempt/risk/lifecycle; R3 registered native XTI D1; R4 deterministic native arithmetic; no foreign identity collision"
---

# QM5_41106 WTI Completed-Month Body-Dominance Momentum

## Hypothesis

A completed WTI broker month whose open-to-close real body occupies strictly
more than one half of its full high-low range represents a directional monthly
auction with more displacement than combined rejection. Its body direction
may persist over the next broker month. At the first tradable bar of the new
month, the strategy follows that completed body's sign and exits at the next
month boundary.

This is a direct physical-energy price carrier outside the certified
XAU/SP500/NDX/XNG book. That carrier difference does not establish
profitability or decorrelation. Q02 owns frequency and baseline economics;
unchanged Q09 alone may establish realized portfolio correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-WTI-MBODY-DOMINANCE-MOM-2026/source.md`, authorized
before extraction by
`decisions/2026-08-22_wti_monthly_body_dominance_momentum_source_approval.md`
at commit `e0eb12c16`. The bounded extraction was committed at `b1eedd804`.
The complete parent source hash is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons, explicitly test one-month formation/holding rules within pooled
commodities, and include WTI in their futures universe. They do not test a
WTI-only completed-month real-body share, a strict one-half threshold, a
continuous CFD, fixed-dollar ATR risk, or the QM book. Every body-state,
execution, and risk choice below is a declared QM interpretation.

No source return, WTI-only alpha, profit factor, drawdown, trade count,
transaction cost, CFD equivalence, neutrality, or correlation statistic is
imported.

## Non-Duplicate Decision

The canonical pre-allocation checker included author and mechanic fields,
scanned 4,595 registry identities, 1,274 repository cards, and 45 Strategy-
Wiki nodes. It found no exact identity and returned only the expected weekly
body-family matches. Manual semantic review fixes the boundaries:

- `QM5_41092_wti-wbody-dominance-mom` uses one completed broker week,
  three-to-five sessions, a strict two-thirds body share, and a one-week hold.
  This card uses one completed calendar month, 17-to-23 sessions, a strict
  majority body share, and a one-month hold. Formation sample, auction
  horizon, state threshold, turnover, financing exposure, and lifecycle are
  jointly different; no weekly result transfers.
- `QM5_41094_xng-wbody-dominance-mom` is both weekly and a natural-gas
  carrier. This card is monthly direct WTI.
- `QM5_20187_wti-tsmom1m` reads two completed month-end closes and follows
  every nonzero return sign. This card reads one completed month's first open
  and final close and additionally requires that real body to occupy a strict
  majority of the month's aggregate range. A weak body is flat, and a month-
  boundary gap can make the two direction states disagree.
- `QM5_41105_wti-mclose-location-mom` derives return from two consecutive
  final closes and confirms the newest close in the matching outer quartile.
  This card needs no parent-month close and instead makes the newest month's
  first open and strict body-to-range share load-bearing.
- `QM5_41102_wti-mrange-migrate-mom` compares aggregate highs and lows across
  two months and deliberately excludes opens and closes. This card compares
  no endpoints across months.
- `QM5_41091_wti-winside-body-mom` requires weekly parent-range containment;
  this card has no parent geometry and owns one complete calendar month; and
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not symmetric monthly WTI continuation.

The exact WTI carrier, immediately completed calendar-month OHLC package,
17-to-23-session contract, first-open/final-close body, strict
`2*body>range`, own-body side, equality-flat rule, consumed monthly attempt,
and full-next-month hold are jointly load-bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_STRICT_MAJORITY_BODY_CONTINUATION_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Cadence

- Target symbol and host: exact `XTIUSD.DWX`.
- Timeframe: exact D1; magic slot 0; planned magic `411060000`.
- Decision: first tradable normalized D1 bar of a new broker-calendar month,
  within 180 elapsed raw-session minutes.
- Formation: the immediately preceding completed calendar-month OHLC package,
  containing 17 through 23 completed sessions.
- Normal exit: first tick whose normalized broker month is later than the
  position-open month.
- Expected frequency: approximately 5-9 completed positions/year; Q02 must
  prove at least five per full post-warm-up year or retire.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `O0`, `C0`, `H0`, and `L0` be the immediately completed month's first
open, final close, aggregate high, and aggregate low:

```text
body  = abs(C0 - O0)
range = H0 - L0

2 * body > range and C0 > O0  => BUY
2 * body > range and C0 < O0  => SELL
otherwise                      => FLAT
```

All values complete before the decision month begins. The current D1 open,
high, low, close, volume, and tick price never enter the signal. Equality at
the threshold, `C0==O0`, invalid endpoints, or zero range is flat. Body
magnitude beyond qualification never changes eligibility or risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XTIUSD.DWX` D1 bar under EA 41106 and
   magic slot zero.
2. Repair malformed, later-month, or stale owned exposure before entry-only
   gates.
3. Select label offset zero when the raw current D1 date equals broker date,
   or `+1` day only when it is exactly one calendar day behind. Apply the same
   convention to every historical bar and reject every other or mixed state.
4. Derive the current and immediately completed `yyyymm` values from
   normalized time. Require calendar adjacency across year boundaries and
   prove that the newest completed bar is older than the current month.
5. Require attachment within 180 elapsed minutes of raw current D1 bar open.
   Persist the current decision `yyyymm` before history, signal, spread,
   quote, ATR, sizing, news, or order gates. Never retry that month.
6. Require no owned position and no same-magic entry deal already recorded in
   the current broker month.
7. Within a fixed 40-bar buffer, reconstruct exactly the immediately completed
   month. Require 17 to 23 unique bars, strict reverse-time order, positive
   finite OHLC, each high/low enclosing its open and close, exact month
   membership, and no current-month observation.
8. Aggregate `O0=chronologically first open`, `C0=chronologically final
   close`, `H0=max(high)`, and `L0=min(low)`. Require `H0>L0` and compute the
   strict integer condition `2*abs(C0-O0)>H0-L0` without a floating threshold.
9. Buy only when the strict body condition holds and `C0>O0`. Sell only when
   it holds and `C0<O0`. Threshold equality, body equality, zero range, or
   invalid arithmetic consumes the month flat.
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

- Exact host, D1, EA 41106, slot zero, and registered magic.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes, legacy news mode, and Friday close are OFF; lifecycle repair
  is never delayed by an entry-only gate.
- Uniform label normalization, first-month-bar clock, 180-minute grace,
  monthly adjacency, session count, OHLC geometry, strict majority-body
  condition, own-body side, durable attempt, spread, quote, ATR, and sizing
  fail closed.
- Runtime cannot read a futures chain, inventory, volume, open interest,
  event feed, external file, API, regression, trained output, prior-result
  state, or manual signal.

## 7. Trade Management Rules

- Own at most one exact `XTIUSD.DWX` slot-zero position under magic
  `411060000`.
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
| `strategy_history_bars_d1` | 40 | bounded one-month buffer |
| `strategy_min_month_sessions` | 17 | complete-month lower bound |
| `strategy_max_month_sessions` | 23 | complete-month upper bound |
| `strategy_body_numerator` | 2 | exact integer left side of strict ratio |
| `strategy_range_multiplier` | 1 | exact integer right side of strict ratio |
| `strategy_entry_grace_minutes` | 180 | first-month-bar window |
| `strategy_atr_period_d1` | 20 | completed-bar range estimate |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1500 | entry cost guard |
| `qm_friday_close_enabled` | false | full-month identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive value |

The ratio integers make the exact `2*body>range` contract visible in the
setfile. They are locked and are not an optimization surface.

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply monthly own-price continuation and
explicit WTI carrier lineage. They do not supply completed-month OHLC
aggregation, a real-body state, a majority threshold, or CFD lifecycle.

## QM Interpretations

`MOP-WTI-MBODY-DOMINANCE-MOM-2026_S01` fixes the exact prior calendar month,
completed monthly OHLC aggregation, strict integer body-share inequality,
own-body direction, continuous-CFD clock, durable attempt, fixed risk, spread
cap, stop, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later broker-month closure.
4. Forty-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 timestamps and OHLC, broker time, symbol metadata,
quotes, completed-bar ATR, framework position/deal state, and persistent
terminal global-variable attempt state. No external runtime dataset exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5*ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are false continuation, month-end gaps, one-contract continuous-
  CFD basis, financing, energy-label drift, strict-session sparsity, spread,
  density below the floor, source translation, and realized overlap with
  other momentum sleeves.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Reputable-Source Gate Findings

| Gate | Status | Finding |
|---|---|---|
| R1 | PASS_WITH_MONTHLY_BODY_TRANSLATION_RISK | Named peer-reviewed DOI, complete-read evidence, durable hash, and explicit WTI membership; the completed-month body-share gate is disclosed as an untested QM translation. |
| R2 | PASS | Clock, label, completed month, OHLC aggregation, strict body-share inequality, side, attempt, risk, and lifecycle are deterministic. |
| R3 | PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK | Registered native WTI D1 supplies all runtime inputs; Q02 owns label, density, cost, and CFD-basis sufficiency. |
| R4 | PASS | Native deterministic arithmetic and state only; no trained signal, banned indicator, external runtime feed, grid, or martingale. |

## Falsification And Requalification

Q02 retires rather than tunes on zero positions, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, wrong
label or month membership, invalid session count, current-month leakage,
incorrect first open/final close or monthly high/low, accepting threshold
equality, wrong body side, duplicate monthly attempt, invalid risk mode,
missing stop, wrong lifecycle, or nondeterminism.

Requalification requires a new OWNER-approved card version before accepting
equality, lowering the majority threshold, changing direction or hold,
changing history/session bounds, or adding volatility, volume, season,
weekday, moving-average, event, inventory, external-data, or prior-result
gates. No post-result parameter salvage is authorized.

## Framework Alignment

| Card rule | V5 owner | Implementation target |
|---|---|---|
| exact carrier, timeframe, input, label, and month lock | No-Trade | `Strategy_NoTradeFilter` and `OnInit` |
| monthly OHLC, strict body share, own-body side, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` |
| next-month and safety closure | Trade Close | `Strategy_ExitSignal` |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove label equivalence; month arithmetic across year boundaries;
first-month-bar and 180-minute clock; exact immediately completed month with
17-to-23 sessions; chronological first-open/final-close selection; aggregate
high/low; both strict body directions; threshold equality, body equality,
zero range, invalid arithmetic, incomplete-month, and non-adjacent flat
states; no current-bar leakage; persistent monthly attempts; fixed-risk
frozen-stop sizing; next-month and stale repair; card lint; strict compile;
setfile schema; resolver identity; and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-22 | initial WTI completed-month body-dominance momentum card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-22 | APPROVED | `decisions/2026-08-22_qm5_41106_wti_monthly_body_dominance_momentum_g0.md` |
| Q01 Build Validation | - | PENDING_BUILD | - |
| Q02 Baseline Screening | - | NOT_QUEUED | - |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.
