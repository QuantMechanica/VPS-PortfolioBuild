---
card_schema_version: 2
type: strategy
strategy_id: MOP-WTI-MCLOSE-LOCATION-MOM-2026_S01
variant_id: MOP-WTI-MCLOSE-LOCATION-MOM-2026_S01
source_id: MOP-WTI-MCLOSE-LOCATION-MOM-2026
ea_id: QM5_41105
slug: wti-mclose-location-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41105_wti-mclose-location-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-22
created_by: Research+Development
last_updated: 2026-08-22
g0_status: APPROVED
g0_decision: decisions/2026-08-22_qm5_41105_wti_monthly_close_location_momentum_g0.md
source_approval: decisions/2026-08-22_wti_monthly_close_location_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-WTI-MCLOSE-LOCATION-MOM-2026/source.md"
    quality_tier: A
    role: monthly_own_return_continuation_and_wti_carrier_lineage
strategy_mechanic: normalized-month-boundary-wti-two-consecutive-completed-monthly-packages-parent-close-to-new-close-strict-return-sign-confirmed-by-newest-month-own-high-low-strict-outer-quartile-close-location-continuation-one-month-hold
sources:
  - "[[sources/MOP-WTI-MCLOSE-LOCATION-MOM-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-month-close-location]]"
  - "[[concepts/crude-oil-structural-trend]]"
indicators:
  - "[[indicators/completed-month-return-sign]]"
  - "[[indicators/completed-month-close-location]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, structural-trend, completed-month-close-location, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 411050000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 6-10 completed WTI positions per full post-warm-up year after exact monthly history, strict return/location agreement, and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 8
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_MONTHLY_CLOSE_LOCATION_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PENDING_BUILD
q02_status: NOT_QUEUED
review_focus: "Falsify a direct-WTI completed-month close-location trend outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact month boundaries, two consecutive completed monthly packages, 17-23 sessions each, strict parent-close-to-new-close sign, strict 0.75/0.25 newest-month close location, agreement-only entry, one attempt, fixed risk, and next-month exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_month_bar, consecutive_calendar_months, completed_monthly_ohlc, bounded_month_session_counts, parent_and_new_final_closes, strict_return_sign, strict_own_range_close_location, no_current_month_leakage, monthly_attempt_state, risk_mode_dual, hard_stop_present, next_month_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized WTI sleeve; R1 complete-read peer-reviewed WTI monthly-continuation source with close-location translation risk; R2 locked monthly OHLC/sign/location/attempt/risk/lifecycle; R3 registered native XTI D1; R4 deterministic native arithmetic; no foreign identity collision"
---

# QM5_41105 WTI Completed-Month Close-Location Momentum

## Hypothesis

The sign of WTI's immediately completed broker-month return may persist into
the next month when that month also settles in the matching outer quartile of
its own realized high-low range. At the first tradable bar of the next month,
the strategy follows a positive return only after a strict upper-quartile
close and follows a negative return only after a strict lower-quartile close.

This is a direct physical-energy price carrier outside the certified
XAU/SP500/NDX/XNG book. That carrier difference does not establish
profitability or decorrelation. Q02 owns frequency and baseline economics;
unchanged Q09 alone may establish realized portfolio correlation.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-WTI-MCLOSE-LOCATION-MOM-2026/source.md`, authorized
before extraction by
`decisions/2026-08-22_wti_monthly_close_location_momentum_source_approval.md`
at commit `896f3cd59`. The bounded extraction was committed at `678af6b6d`.
The complete parent source hash is
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons, explicitly test one-month formation/holding rules within pooled
commodities, and include WTI in their futures universe. They do not test a
WTI-only monthly close-location condition, outer-quartile thresholds, a
continuous CFD, fixed-dollar ATR risk, or the QM book. Every range-state,
execution, and risk choice below is a declared QM interpretation.

No source return, WTI-only alpha, profit factor, drawdown, trade count,
transaction cost, CFD equivalence, neutrality, or correlation statistic is
imported.

## Non-Duplicate Decision

The canonical pre-allocation checker included author and mechanic fields,
scanned 4,594 registry identities, 1,273 repository cards, and 45 Strategy-
Wiki nodes. It found no exact identity and returned expected fuzzy weekly-
family matches. Manual semantic review fixes the boundaries:

- `QM5_41080_wti-wclose-location-mom` uses two completed broker weeks,
  three-to-five-session packages, strict outer-fifth thresholds, and a one-
  week hold. This card uses two completed calendar months, 17-to-23-session
  packages, predeclared outer-quartile thresholds, and a one-month hold.
  Formation sample, auction horizon, threshold, turnover, financing exposure,
  and lifecycle are jointly different; no weekly result transfers.
- `QM5_41081_xng-wclose-location-mom` is both weekly and a natural-gas
  carrier. This card is monthly direct WTI.
- `QM5_20187_wti-tsmom1m` reads two completed month-end closes and follows
  every nonzero return sign. This card additionally aggregates the newest
  month's high and low and requires settlement in the matching outer
  quartile; an interior or contradictory close is flat.
- `QM5_41016_wti-mclose-mom` and `QM5_41021_wti-mdual-mom` form on a final-
  five-session segment and own only the first five new-month sessions. This
  card forms and holds complete calendar-month packages.
- `QM5_41102_wti-mrange-migrate-mom` compares aggregate highs and lows across
  two months and never reads a close. This card compares no range endpoint
  across months; it combines close-to-close sign with the newest month's own
  range position.
- weekly widest-range, outside-settlement, and inside-body cards require
  compression or parent-range geometry absent here; and
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not symmetric monthly WTI continuation.

The exact WTI carrier, two consecutive completed calendar-month packages,
17-to-23-session contract, parent-close-to-new-close sign, newest-month own-
range `0.75` / `0.25` confirmation, consumed monthly attempt, and full-next-
month hold are jointly load-bearing. Verdict:
`CLEAN_AFTER_EXPECTED_WEEKLY_CLOSE_LOCATION_FAMILY_FUZZY_REVIEW`.

## Markets, Timeframe, And Cadence

- Target symbol and host: exact `XTIUSD.DWX`.
- Timeframe: exact D1; magic slot 0; planned magic `411050000`.
- Decision: first tradable normalized D1 bar of a new broker-calendar month,
  within 180 elapsed raw-session minutes.
- Formation: the two immediately preceding consecutive completed calendar-
  month packages, with 17 through 23 completed sessions each.
- Normal exit: first tick whose normalized broker month is later than the
  position-open month.
- Expected frequency: approximately 6-10 completed positions/year; Q02 must
  prove at least five per full post-warm-up year or retire.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Formula

Let `C0`, `H0`, and `L0` be the newest completed month's final close,
aggregate high, and aggregate low. Let `C1` be its consecutive parent's final
close:

```text
r   = ln(C0 / C1)
clv = (C0 - L0) / (H0 - L0)

r > 0 and clv > 0.75  => BUY
r < 0 and clv < 0.25  => SELL
otherwise              => FLAT
```

All values complete before the decision month begins. The current D1 open,
high, low, close, volume, and tick price never enter the signal. Exact zero,
equality at either threshold, invalid endpoints, zero range, or sign/location
disagreement is flat. Signal magnitude never changes eligibility or risk.

## Rules

The following entry, exit, filter, management, and risk rules are the complete
authorized baseline. There is no optimization surface or fallback mechanic.

## 4. Entry Rules

1. Evaluate only once on a new exact `XTIUSD.DWX` D1 bar under EA 41105 and
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
   strict reverse-time order, positive finite OHLC, valid high/low geometry,
   exact month membership, and no current-month observation.
8. Aggregate newest-month `H0=max(high)`, `L0=min(low)`, and
   `C0=chronologically final close`; select parent
   `C1=chronologically final close`. Compute `r` and `clv` exactly as above
   and require both finite.
9. Buy only on strict `r>0 && clv>0.75`. Sell only on strict
   `r<0 && clv<0.25`. Equality, zero, an interior close, or disagreement
   consumes the month flat.
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

- Exact host, D1, EA 41105, slot zero, and registered magic.
- Exact fixed-risk values and every frozen strategy input.
- Framework kill switch and ownership checks remain authoritative.
- Both news axes, legacy news mode, and Friday close are OFF; lifecycle repair
  is never delayed by an entry-only gate.
- Uniform label normalization, first-month-bar clock, 180-minute grace,
  consecutive months, monthly session counts, OHLC/endpoints, strict return
  and close-location conjunction, durable attempt, spread, quote, ATR, and
  sizing fail closed.
- Runtime cannot read a futures chain, inventory, volume, open interest,
  event feed, external file, API, regression, trained output, prior-result
  state, or manual signal.

## 7. Trade Management Rules

- Own at most one exact `XTIUSD.DWX` slot-zero position under magic
  `411050000`.
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
| `strategy_history_bars_d1` | 70 | bounded two-month buffer |
| `strategy_min_month_sessions` | 17 | complete-month lower bound |
| `strategy_max_month_sessions` | 23 | complete-month upper bound |
| `strategy_long_clv_min` | 0.75 | strict upper-quartile boundary |
| `strategy_short_clv_max` | 0.25 | strict lower-quartile boundary |
| `strategy_entry_grace_minutes` | 180 | first-month-bar window |
| `strategy_atr_period_d1` | 20 | completed-bar range estimate |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale repair only |
| `strategy_max_spread_points` | 1500 | entry cost guard |
| `qm_friday_close_enabled` | false | full-month identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive value |

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply monthly own-return-sign continuation and
explicit WTI carrier lineage. They do not supply a completed-month high-low
package, close-location gate, outer-quartile threshold, or CFD lifecycle.

## QM Interpretations

`MOP-WTI-MCLOSE-LOCATION-MOM-2026_S01` fixes the exact prior two calendar
months, completed monthly OHLC aggregation, final-close return, strict
outer-quartile agreement, continuous-CFD clock, durable attempt, fixed risk,
spread cap, stop, and lifecycle.

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
| R1 | PASS_WITH_MONTHLY_CLOSE_LOCATION_TRANSLATION_RISK | Named peer-reviewed DOI, complete-read evidence, durable hash, and explicit WTI membership; the monthly close-location gate is disclosed as an untested QM translation. |
| R2 | PASS | Clock, label, two completed months, final closes, monthly high/low, strict return/location conjunction, attempt, risk, and lifecycle are deterministic. |
| R3 | PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK | Registered native WTI D1 supplies all runtime inputs; Q02 owns label, density, cost, and CFD-basis sufficiency. |
| R4 | PASS | Native deterministic arithmetic and state only; no trained signal, banned indicator, external runtime feed, grid, or martingale. |

## Falsification And Requalification

Q02 retires rather than tunes on zero positions, fewer than five completed
positions per full post-warm-up year, nonpositive governed economics, wrong
label or month membership, invalid session count, current-month leakage,
incorrect final close or monthly high/low, accepting equality, wrong side,
duplicate monthly attempt, invalid risk mode, missing stop, wrong lifecycle,
or nondeterminism.

Requalification requires a new OWNER-approved card version before accepting
equality, moving either close-location threshold, dropping return-sign
agreement, changing direction or hold, changing history/session bounds, or
adding volatility, volume, season, weekday, moving-average, event, inventory,
external-data, or prior-result gates. No post-result parameter salvage is
authorized.

## Framework Alignment

| Card rule | V5 owner | Implementation target |
|---|---|---|
| exact carrier, timeframe, input, label, and month lock | No-Trade | `Strategy_NoTradeFilter` and `OnInit` |
| two monthly packages, return, close location, strict agreement, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-month, and stale repair | Trade Management | `Strategy_ManageOpenPosition` |
| next-month and safety closure | Trade Close | `Strategy_ExitSignal` |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove label equivalence; month arithmetic across year boundaries;
first-month-bar and 180-minute clock; exact two consecutive completed months
with 17-to-23 sessions each; chronological final-close selection; newest-
month high/low aggregation; both strict direction/location conjunctions;
equality, zero range, invalid arithmetic, incomplete-month, non-adjacent, and
disagreement flat states; no current-bar leakage; persistent monthly
attempts; fixed-risk frozen-stop sizing; next-month and stale repair; card
lint; strict compile; setfile schema; resolver identity; and static artifact
validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-22 | initial WTI completed-month close-location momentum card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-22 | APPROVED | `decisions/2026-08-22_qm5_41105_wti_monthly_close_location_momentum_g0.md` |
| Q01 Build Validation | - | PENDING_BUILD | - |
| Q02 Baseline Screening | - | NOT_QUEUED | - |

## Safety Boundary

This card authorizes a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or T_Live manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.
