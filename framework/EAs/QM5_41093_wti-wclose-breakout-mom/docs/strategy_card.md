---
card_schema_version: 2
type: strategy
strategy_id: MOP-SZAKMARY-WTI-WCLOSE-BRK-2026_S01
variant_id: MOP-SZAKMARY-WTI-WCLOSE-BRK-2026_S01
source_id: MOP-SZAKMARY-WTI-WCLOSE-BRK-2026
ea_id: QM5_41093
slug: wti-wclose-breakout-mom
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_41093_wti-wclose-breakout-mom_card.md
execution_contract_status: APPROVED
created: 2026-08-21
created_by: Research+Development
last_updated: 2026-08-21
g0_status: APPROVED
g0_decision: decisions/2026-08-21_qm5_41093_wti_weekly_closing_breakout_momentum_g0.md
source_approval: decisions/2026-08-21_wti_weekly_closing_breakout_momentum_source_approval.md
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Andrew C. Szakmary; Qian Shen; Subhash C. Sharma"
source_authors: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen; Andrew C. Szakmary; Qian Shen; Subhash C. Sharma"
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250; Szakmary, Shen, and Sharma (2010), Trend-following trading strategies in commodity futures: A re-examination, Journal of Banking & Finance 34(2), 409-426."
source_citations:
  - type: academic_paper
    citation: "Moskowitz, Tobias J.; Ooi, Yao Hua; and Pedersen, Lasse Heje (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250."
    location: "DOI 10.1016/j.jfineco.2011.11.003; complete-read packet strategy-seeds/sources/MOP-TSMOM-2012/source.md; bounded translation strategy-seeds/sources/MOP-SZAKMARY-WTI-WCLOSE-BRK-2026/source.md"
    quality_tier: A
    role: own_price_continuation_and_wti_carrier_lineage
  - type: academic_paper
    citation: "Szakmary, Andrew C.; Shen, Qian; and Sharma, Subhash C. (2010), Trend-following trading strategies in commodity futures: A re-examination, Journal of Banking & Finance 34(2), 409-426."
    location: "DOI 10.1016/j.jbankfin.2009.08.004; complete mechanical record strategy-seeds/sources/SZAKMARY-WTI-MCH3-2010/source.md; bounded translation strategy-seeds/sources/MOP-SZAKMARY-WTI-WCLOSE-BRK-2026/source.md"
    quality_tier: A
    role: completed_extrema_channel_breakout_lineage
strategy_mechanic: normalized-week-boundary-wti-two-consecutive-completed-weekly-ohlc-packages-newest-final-close-strictly-outside-parent-high-low-range-continuation-one-week-hold
sources:
  - "[[sources/MOP-SZAKMARY-WTI-WCLOSE-BRK-2026]]"
concepts:
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/completed-week-closing-breakout]]"
  - "[[concepts/wti-structural-trend]]"
indicators:
  - "[[indicators/completed-parent-week-range]]"
  - "[[indicators/completed-week-final-close]]"
  - "[[indicators/atr-risk-stop]]"
strategy_type_flags: [commodity, energy, wti-crude, time-series-momentum, completed-week-closing-breakout, symmetric-long-short, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, energy, wti_crude]
timeframes: [D1]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
host_symbol: XTIUSD.DWX
symbol_slot: 0
magic: 410930000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately 10-25 completed WTI positions per full post-warm-up year after strict weekly-package and execution gates; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 18
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS_WITH_WEEKLY_CHANNEL_TRANSLATION_RISK
r2_mechanical: PASS
r3_data_available: PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: NOT_ENQUEUED
q01_build_report: D:/QM/reports/framework/21/build_check_20260821_160421.json
q01_p1_evidence: D:/QM/reports/pipeline/QM5_41093/P1/P1_QM5_41093_result.json
review_focus: "Falsify a direct-WTI completed-week closing-breakout sleeve outside the certified XAU/SP500/NDX/XNG book. Verify uniform energy labels, exact Monday anchors, two consecutive 3-5-session completed packages, parent high-low aggregation, newest chronologically final close, strict outside-range comparisons, equality flat, one attempt, and next-week exit. Q09 alone may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [exact_symbol_period, normalized_energy_label, first_tradable_week_bar, consecutive_monday_anchors, completed_weekly_ohlc, bounded_week_session_counts, parent_high_low, newest_final_close, strict_closing_breakout, threshold_equality_flat, no_current_week_leakage, weekly_attempt_state, risk_mode_dual, hard_stop_present, next_week_exit, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized build; R1 one governed child source with complete peer-reviewed WTI momentum/channel lineage and weekly translation disclosed; R2 exact clock, weekly packages, extrema, close, side, attempt, risk, and lifecycle; R3 native WTI D1; R4 deterministic one-position logic without ML."
---

# QM5_41093 WTI Completed-Week Closing-Breakout Momentum

## Hypothesis

A completed WTI broker week whose final settlement closes strictly beyond the
entire high-low auction range of its parent week may represent accepted price
discovery rather than an intraperiod probe. At the first tradable bar of the
next week, the strategy follows an upside or downside closing breakout for one
broker week.

The sources establish broad own-return continuation, WTI membership, and a
completed-extrema channel family. They do not test this exact two-week WTI
OHLC construction, weekly horizon, standalone continuous-CFD result, or
portfolio relationship. The rule is falsifiable and carries no ex-ante
profitability or decorrelation claim.

## Source Traceability And Claim Boundary

The source of record is
`strategy-seeds/sources/MOP-SZAKMARY-WTI-WCLOSE-BRK-2026/source.md`, approved
before complete reading and extraction in
`decisions/2026-08-21_wti_weekly_closing_breakout_momentum_source_approval.md`
at commit `f0d8fe585`.

Moskowitz, Ooi, and Pedersen document own-return continuation over monthly
horizons and include NYMEX WTI in their futures universe. Szakmary, Shen, and
Sharma define a monthly commodity channel family whose newest completed value
is long above prior completed extrema, short below them, and flat inside.

Neither source tests the newest completed weekly final close against one
parent week's aggregate high-low range. They do not test Darwinex continuous
CFDs, fixed-dollar ATR risk, or the QM book. Every weekly clock, OHLC endpoint,
execution, and risk choice below is a declared QM interpretation. No source
return, significance, WTI-only alpha, trade count, drawdown, CFD equivalence,
or correlation result transfers.

## Non-Duplicate Decision

The canonical pre-allocation checker included all source authors and the full
mechanic. It scanned 4,582 registry rows, 1,255 repository cards, and all 45
Strategy Wiki nodes. It found no exact identity and surfaced five fuzzy
weekly-OHLC family matches. Manual review fixes the load-bearing boundaries:

- `QM5_41091_wti-winside-body-mom` requires the newest weekly range to be
  strictly contained by the parent and follows the newest body's sign. This
  card requires the newest final close outside the parent range, making their
  eligible geometries mutually exclusive.
- `QM5_41080_wti-wclose-location-mom` uses parent-final to newest-final return
  sign plus the newest close's location inside its own range. This card ignores
  parent close and newest own-range location and compares only newest final
  close with parent high and low.
- `QM5_41081_xng-wclose-location-mom` uses the nonidentical close-location
  family on natural gas.
- `QM5_41073_wti-woutside-settle` requires the newest week to exceed both
  parent extremes, agree with its own body, and settle in its own matching
  outer quartile. This card requires only a final close beyond one parent
  extreme and has no opposite-side expansion, body, or close-location gate.
- `QM5_41089_wti-wrange-migrate-mom` compares both weekly range endpoints and
  never makes the final close decisive. This card ignores newest-range
  migration.
- `QM5_41061_wti-week-nr7-brk` ranks seven completed ranges and then waits for
  an in-progress next-week completed D1 close to escape the NR7 range. This
  card has no range rank or current-week signal and decides only at the next
  week boundary.
- `QM5_20008_wti-month-ch3` compares a completed month-end close with three
  prior month-end closes. This card uses one parent weekly high-low auction,
  not a monthly close-only channel.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  cumulative-RSI2 pullback under a slow mean on a different carrier.

The exact WTI carrier, two consecutive completed weekly packages, parent high
and low, newest chronologically final close, strict outside-range comparison,
equality-flat behavior, boundary entry, durable attempt, fixed risk, and
one-week hold are jointly load-bearing. Verdict:
`NO_EXACT_DUPLICATE_PARENT_WEEK_RANGE_FINAL_CLOSE_BREAKOUT_MANUALLY_DISTINCT`.

## Market, Clock, And State

- Host and traded symbol: exact `XTIUSD.DWX` only.
- Timeframe: exact D1 only.
- EA ID, slot, and magic: `41093`, `0`, and `410930000`.
- Decision: first executable tick of a new normalized Monday-anchored broker
  week, within 180 elapsed minutes of the raw D1 session open.
- Signal data: the exact two immediately preceding completed weekly packages;
  current-week OHLC is excluded.
- Position count: at most one owned position and at most one consumed attempt
  per normalized week anchor.

## Energy-Label Normalization

Infer one label convention from the current D1 bar. Accept native same-day
labels or a uniform `+1` calendar-day energy convention when the raw bar label
is exactly one date behind broker time. Apply the same choice to the current
bar and every historical bar used in aggregation. Never shift broker time,
mix label conventions, or infer a different offset per bar.

The normalized current bar must belong to a Monday-anchored week whose anchor
is seven calendar days after the newest package anchor. The parent anchor must
be seven calendar days before the newest. Holiday-shortened packages remain
valid only with three to five unique, strictly ordered sessions. Two or six
sessions, duplicate dates, mixed labels, bad OHLC, nonadjacent anchors, or
unclassifiable history stay flat.

## Formula

Let `PH` and `PL` be the parent completed week's aggregate high and low. Let
`NC` be the chronologically final close of the immediately completed newest
week:

```text
NC > PH  => BUY
NC < PL  => SELL
else     => FLAT
```

Equality at `PH` or `PL` is flat. The newest open, high, low, and body do not
enter the signal. The parent open and close do not enter the signal. Current-
week prices are execution-only.

## Rules

The entry, exit, filter, and management contracts below are the complete
authorized baseline. Anything not stated here is out of scope.

### Entry Rules

1. Repair malformed owned exposure before entry-only filters.
2. Require exact symbol, D1, EA ID, slot, risk mode, news modes, Friday-close
   inputs, and every locked strategy input.
3. Observe a new D1 bar and derive the normalized Monday anchor for the current
   decision week under one uniform energy-label convention.
4. Admit only within `strategy_entry_grace_minutes = 180` elapsed minutes of
   the raw current D1 bar open. Late attachment consumes the week flat.
5. Persist the normalized current Monday-anchor attempt before history,
   aggregation, signal, news, spread, quote, ATR, sizing, or order gates.
   Never retry that week after a downstream failure.
6. Require no owned position and no same-magic entry deal already recorded in
   the current normalized week.
7. Within a bounded D1 buffer, reconstruct exactly the newest and parent
   completed broker weeks. Require anchors at current minus seven and fourteen
   calendar days, three to five unique valid sessions in each package, and
   strict reverse-time source ordering that resolves to unique chronological
   dates.
8. Validate every session's positive finite OHLC and geometry. Aggregate
   `parent_high` as the maximum parent high and `parent_low` as the minimum
   parent low. Select `newest_close` from the chronologically final newest-
   week session. Require `parent_high > parent_low` and all three values finite
   and positive.
9. BUY only when `newest_close > parent_high`. SELL only when
   `newest_close < parent_low`. Equality at either extreme, an interior close,
   invalid arithmetic, and every other state stay flat. Breakout distance
   never changes the risk budget or volume.
10. Require spread no greater than 1,500 points and a valid completed-bar
    `ATR(20,D1)`.
11. Freeze one hard stop `3.5 * ATR` from entry and use no take-profit.
12. Open at most one fixed-risk slot-zero position. Submit no pending order,
    retry, scale-in, hedge, grid, martingale, or pyramid.

The current decision week's open, high, low, and close never enter the signal.
Current quotes are execution-only after the completed-week decision.

### Attempt And Restart Contract

The attempt key is terminal-global, scoped by EA, symbol, and timeframe, and
stores the normalized current Monday-anchor date. It is written before every
fallible gate. Initialization after the 180-minute grace consumes the missed
week without creating a late trade. Owned deal history and open-position
checks provide additional fail-closed guards. A rejected order, stop-out,
news block, spread failure, restart, invalid ATR, or invalid history cannot
create a same-week retry.

### Exit Rules

1. The broker hard stop and framework kill switch remain authoritative.
2. Duplicate, wrong-side, wrong-magic, missing-stop, or otherwise malformed
   owned exposure is flattened.
3. Close the position on the first tick whose normalized Monday anchor is
   later than the anchor stored for the position's entry week.
4. Ten elapsed calendar days is a stale repair only.

There is no take-profit, opposite-signal exit, trailing stop, break-even move,
partial close, Friday flattening, scale-in, reversal, grid, martingale, hedge,
or discretionary close.

### Filters And No-Trade Contract

- Require exact `XTIUSD.DWX`, D1, EA ID `41093`, and slot 0.
- Require `RISK_FIXED > 0`, `RISK_PERCENT = 0`, valid stop inputs, news
  temporal OFF, news compliance NONE, and Friday close disabled.
- Framework kill-switch, broker, and ownership controls remain authoritative.
- Apply the entry grace, durable attempt, exact label and calendar contract,
  weekly history and OHLC validity, strict closing-breakout rule, spread
  ceiling, valid quote, and completed ATR gate fail-closed.
- No own-body, close-location, outside-week, range-migration, range-rank,
  return-magnitude, current-week breakout, moving average, oscillator, volume,
  open interest, inventory, event calendar, futures curve, external file, API,
  or manual runtime input is used.

### Trade Management Rules

- Own at most one position on the registered magic and symbol.
- Flatten duplicate, wrong-side, missing-stop, or otherwise malformed owned
  exposure before considering a new entry.
- Leave the frozen server-side stop unchanged; do not trail, widen, partial-
  close, reverse, scale, or pyramid.
- Close a survivor at the first later normalized weekly boundary; use the
  ten-calendar-day guard only when that boundary repair was missed.
- Management remains reachable on every tick before any entry-only gate.

## Parameters To Test

No optimization surface is approved. The sole baseline uses:

| Parameter | Locked value | Role |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | exact first-week-bar execution window |
| `strategy_history_bars` | 30 | bounded D1 OHLC buffer |
| `strategy_required_weeks` | 2 | exact completed weekly packages |
| `strategy_min_week_bars` | 3 | minimum sessions in each package |
| `strategy_max_week_bars` | 5 | maximum sessions in each package |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale repair only |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | full-week identity |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework value |

There is no breakout buffer or fitted magnitude threshold. Strict comparison
with the exact parent extremes is the frozen baseline.

## Source-Defined Rules

Moskowitz, Ooi, and Pedersen supply own-return continuation and WTI membership.
Szakmary, Shen, and Sharma supply a completed-value-versus-prior-extrema
channel family with long, short, and flat states. They do not supply this
weekly parent high-low construction or one-week lifecycle.

## QM Interpretations

`MOP-SZAKMARY-WTI-WCLOSE-BRK-2026_S01` fixes the weekly horizon, two
completed OHLC packages, parent session-high/low extrema, newest final-close
endpoint, continuous-CFD Monday anchors and label normalization, entry grace,
persistent attempt, fixed-dollar ATR risk, spread cap, and lifecycle.

## Framework Execution Overrides

Both news axes and Friday close are OFF. Framework kill switch and ownership
closure precede entry. No live execution override exists.

## Exit Precedence

1. Broker hard stop and framework kill switch.
2. Malformed or unsafe owned-position repair.
3. Later normalized broker-week closure.
4. Ten-calendar-day stale repair.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` native D1 OHLC, broker time, symbol metadata, quotes,
completed-bar ATR, framework position/deal state, and persistent terminal
global-variable attempt state. No finite external dataset or event calendar
exists.

## Risk

- Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)` from completed data.
- No target and no signal-strength sizing.
- Major risks are false weekly breakouts, weekend gaps, continuous-CFD
  roll/basis, energy-session label ambiguity, financing, spread, density below
  the floor, weekly source translation, and realized book correlation.
- No live, demo, shadow, stress, or optimization preset is authorized.

## Strategy Allowability Check

| Gate | Verdict | Evidence |
|---|---|---|
| R1 | PASS_WITH_WEEKLY_CHANNEL_TRANSLATION_RISK | Named authors, two peer-reviewed DOI lineages, complete-read evidence, explicit WTI membership, and a mechanical completed-extrema channel family; the weekly translation risk is disclosed. |
| R2 | PASS | Exact clock, label, anchors, OHLC aggregation, session counts, parent extrema, newest final close, strict comparisons, equality flat, attempt, risk, stop, spread, and lifecycle. |
| R3 | PASS_WITH_ENERGY_LABEL_AND_CFD_BASIS_RISK | Registered native `XTIUSD.DWX` D1 history and MT5 state supply every runtime field; energy-label and continuous-CFD basis remain Q02 falsification items. |
| R4 | PASS | Deterministic timestamp/OHLC/extrema arithmetic only; no trained or adaptive signal, external feed, grid, martingale, scale-in, or pyramid. |

## Falsification And Requalification

Q02 retires rather than tunes on zero trades, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics, wrong
or mixed labels, nonconsecutive anchors, invalid session counts or OHLC,
selection of any newest close other than the chronological final close, entry
at equality or inside the parent range, wrong side, current-week leakage, late
or repeated attempt, missing hard stop, wrong next-week close,
nondeterminism, or invalid fixed-risk mode.

Changing the WTI carrier, weekly aggregation, parent extrema, newest final-
close endpoint, strict inequalities, direction, attempt clock, risk, stop, or
lifecycle requires a new identity and full Q00/Q01 cycle. A failed result may
not be rescued by accepting equality, adding a breakout buffer, substituting
newest high/low, changing the hold, reversing the side, or adding a body,
close-location, outside-range, migration, range-rank, volatility, volume,
calendar, moving-average, inventory, event, or external-data filter.

## Framework Alignment

| Card rule | V5 module | Implementation obligation |
|---|---|---|
| exact host/period, label, week anchors, weekly OHLC, session counts, parent extrema, newest final close, attempt, spread, ATR | Trade Entry | `Strategy_EntrySignal` plus deterministic helpers |
| malformed, later-week, and stale repair | Trade Management | `Strategy_ManageOpenPosition` plus lifecycle helper |
| next-week and survivor repair | Trade Close | strategy lifecycle helper |
| kill switch, ownership, magic resolver, fixed-risk mode | Framework No-Trade | standard framework orchestration |
| news OFF | News hooks | both news axes locked OFF |

## Validation Plan

Q01 must prove native and uniformly shifted label equivalence; first-week-bar
and 180-minute clock; Monday anchors across year boundaries; exactly two
consecutive weekly packages; parent high/low aggregation; chronological newest
final-close selection; three/four/five-session acceptance and two/six-session
rejection; strict long and short closing breakouts; exact equality and
inside-range flat states; no current-bar leakage; persistent weekly attempts;
fixed-risk frozen-stop sizing; next-week and stale repair; card lint; strict
compile; setfile schema; resolver identity; and static artifact validation.

Q02 alone may measure frequency and baseline economics. Q09 alone may
establish realized correlation with the certified book.

## Pipeline History

| Version | Date | Change | Gate | Status |
|---|---|---|---|---|
| v1 | 2026-08-21 | initial WTI completed-week closing-breakout card | G0 | APPROVED |
| v2 | 2026-08-21 | exact card implementation, deterministic reference contract, strict compile, and static build validation | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Status | Evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-21 | APPROVED | `decisions/2026-08-21_qm5_41093_wti_weekly_closing_breakout_momentum_g0.md` |
| Q01 Build Validation | 2026-08-21 | PASS | 13 deterministic reference checks; strict compile 0 errors/0 warnings; build check 0 failures |
| Q02 Baseline Screening | pending | NOT_ENQUEUED | one paced target-only handoff after capacity preflight |

## Safety Boundary

This card requests a branch-only non-live build, Q01 validation, one D1
`RISK_FIXED` backtest setfile, and one paced target-only Q02 enqueue only below
tester and CPU ceilings. It does not authorize a manual backtest, terminal
control, live/demo/shadow/stress/optimization preset, AutoTrading, `T_Live`,
deploy or `T_Live` manifest, portfolio-gate change, portfolio admission,
decorrelation claim, or correlation waiver.
