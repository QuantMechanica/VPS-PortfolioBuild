---
card_schema_version: 2
type: strategy
strategy_id: TGIF-XNG-WEEKEND-2017_S04
variant_id: TGIF-XNG-WEEKEND-2017_S04
source_id: TGIF-EIA-XNG-WKEND-2026
ea_id: QM5_21519
slug: xng-wkend-hold
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_21519_xng-wkend-hold_card.md
execution_contract_status: DRAFT
created: 2026-08-14
created_by: Research+Development
last_updated: 2026-08-14
g0_status: APPROVED
g0_decision: decisions/2026-08-14_xng_wkend_hold_g0.md
source_author: "Seth A. Hoelscher; Cedric L. Mbanga; Walt A. Nelson; U.S. Energy Information Administration"
source_authors: "Seth A. Hoelscher; Cedric L. Mbanga; Walt A. Nelson; U.S. Energy Information Administration"
source_citation: "Hoelscher, Mbanga, and Nelson (2017), TGIF? The Weekend Effect in Energy Commodities, Journal of Finance Issues 16(1), 47-68, DOI 10.58886/jfi.v16i1.2264; U.S. EIA, Factors affecting natural gas prices."
source_citations:
  - type: peer_reviewed_trading_paper
    citation: "Hoelscher, S. A., Mbanga, C. L., and Nelson, W. A. (2017). TGIF? The Weekend Effect in Energy Commodities. Journal of Finance Issues 16(1), 47-68."
    location: "DOI 10.58886/jfi.v16i1.2264; complete 22-page governed review at strategy-seeds/sources/TGIF-WTI-WEEKEND-2017/source.md"
    quality_tier: B
    role: natural_gas_positive_monday_close_to_close_return_family
  - type: official_government_context
    citation: "U.S. Energy Information Administration. Factors affecting natural gas prices."
    location: "Governed packet strategy-seeds/sources/EIA-XNG-WEEKEND-GAP-2026/source.md"
    quality_tier: A
    role: weather_sensitive_heating_and_power_demand_structure
strategy_mechanic: friday-2100-broker-long-xng-hold-across-weekend-and-exit-monday-2100-with-one-week-attempt-and-d1-atr-stop
sources:
  - "[[sources/TGIF-EIA-XNG-WKEND-2026]]"
concepts:
  - "[[concepts/natural-gas-weekend-effect]]"
  - "[[concepts/closed-market-information-window]]"
strategy_type_flags: [natural-gas, calendar-seasonality, weekend-hold, long-only, atr-hard-stop, weekly, structural, low-frequency]
markets: [commodities, energy, natural_gas]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_21519_XNG_WKEND_HOLD_H1
symbol: XNGUSD.DWX
period: H1
timeframe: H1
timeframes: [H1]
expected_trade_frequency: "At most one consumed Friday-to-Monday package per broker week; approximately 45-51 completed trades/year after holidays, spread, and execution gates. This is a prior, not test evidence."
expected_trades_per_year_per_symbol: 48
expected_pf: 1.01
expected_dd_pct: 30.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: BLOCKED_FACTORY_OFF
review_focus: "Adds a closed-market natural-gas weekend-information driver rather than the certified XNG cumulative-RSI pullback; Q09 must still reject or challenger-test realized correlation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, risk_mode_dual, magic_schema, one_position_per_magic_symbol, restart_safe_attempt, natural_gas_weekend_gap, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "OWNER-authorized commodity sleeve: R1 complete governed peer-reviewed energy-weekend review plus official EIA gas-driver context; R2 locked Friday/Monday 21:00 broker boundaries, long-only XNG carrier, consumed week, fixed risk, D1 ATR stop, and stale repair; R3 native registered XNG H1/D1; R4 deterministic non-trained arithmetic; exact dedup clean and one source-family fuzzy neighbor manually separated."
---

# XNG Pre-Weekend To Monday Hold

## Hypothesis

Natural-gas information can accumulate while the market is closed because
weather-sensitive heating and power-demand expectations continue to change.
The peer-reviewed energy-weekend study reports a positive natural-gas Monday
close-to-close effect; an executable XNG long opened at the established V5
Friday risk cutoff and closed at the matching Monday cutoff may retain part of
that structural window after CFD costs and weekend gap risk.

This is a weekly calendar/event-risk sleeve. It has no oscillator, pullback,
trend mean, storage number, realized gap filter, or cross-asset leg. Its return
driver is intended to differ from the certified XNG cumulative-RSI sleeve and
the XAU/SP500/NDX book, but only Q09 may establish realized independence.

## Source Traceability And Claim Boundary

The bounded composite packet is
`strategy-seeds/sources/TGIF-EIA-XNG-WKEND-2026/source.md`. It uses the fully
reviewed Hoelscher-Mbanga-Nelson paper for the natural-gas Monday return family
and official EIA material only for structural weather-sensitive demand
context.

The paper studies EIA spot close-to-close returns, not Darwinex CFDs, and does
not prescribe Friday H1 execution, the 21:00 broker cutoff, a hard stop, fixed
risk, or costs. EIA does not claim a trading premium. The exact execution
window and all risk/lifecycle rules below are transparent QM hypotheses. No
source coefficient, significance level, return, hit rate, drawdown, trade
count, CFD equivalence, or correlation statistic transfers.

A fresh generic URL route on 2026-08-14 returned
`DEFERRED:SOURCE_POLICY`; no access workaround was used and no new webpage
text is imported.

## Non-Duplicate Decision

The canonical checker scanned 4,391 EA-registry rows and 487 root cards. It
found no exact slug or strategy-ID collision and one expected source-family
fuzzy match:

- `QM5_20016_xti-xng-mon-rv` enters a short-WTI/long-XNG package only after
  Monday begins, exits at the next D1 boundary, and forbids either standalone
  leg. This card is XNG-only and enters before the closed-market interval.
- `QM5_12806_xng-rev-weekend` buys XNG on Monday and separately sells Friday;
  it never holds a long XNG position across the weekend.
- `QM5_12738_xng-weekend-gap` observes a completed Monday gap and confirming
  body before entering in the gap direction. This card enters before a gap is
  known and has no gap/body condition.
- XNG weekday-trend, storage, seasonality, freeze, hurricane, carry, expiry,
  reversal, and relative-value systems use other state objects or packages.
- `QM5_12567_cum-rsi2-commodity` buys short-horizon cumulative-RSI pullbacks
  under a slow trend filter; this card never calculates an oscillator or trend.

The Friday 21:00 pre-weekend entry, long-only XNG carrier, deliberate weekend
hold, Monday matching-cutoff exit, and consumed weekly attempt are jointly
load-bearing. Verdict:
`CLEAN_AUTHORIZED_XNG_PREWEEKEND_TO_MONDAY_HOLD_AFTER_FAMILY_REVIEW`.

## Markets, Timeframe, And Clock

- Host and traded symbol: exact `XNGUSD.DWX`.
- Host timeframe: H1.
- EA ID/slot/magic: `QM5_21519` / 0 / `215190000`.
- Decision: first tick of the genuine Friday H1 bar stamped 21:00 broker time.
- Exit: first tick at or after Monday 21:00 broker time, or the first later-
  week tick when that cutoff was not tradable.
- Maximum cadence: one consumed Friday attempt per framework broker week.

## Rules

The entry, exit, filter, sizing, and lifecycle rules below are the entire
authorized baseline. A different weekday, clock, direction, seasonal window,
signal filter, stop, or hold is a new card.

## 4. Entry Rules

1. Require exact `XNGUSD.DWX`, H1, the allocated EA ID, slot 0, and all locked
   baseline inputs.
2. Run lifecycle repair before entry-only gates. Evaluate entry only on a
   genuine new H1 bar whose broker timestamp is Friday 21:00 exactly and
   whose first executable tick arrives within five minutes of that boundary.
3. Derive the current `PERIOD_W1` start key. Persist that key as attempted
   before owned-position, history, news, spread, quote, sizing, stop, or order
   checks. A blocked/rejected order, restart, or stop cannot retry that week.
4. Require no owned exposure or same-week entry deal, a nonnegative spread no
   greater than 1,000 points, an executable ask, and a positive finite
   completed `ATR(20,D1)`.
5. BUY one XNG position with exactly one `RISK_FIXED=1000` budget. Place a
   frozen broker hard stop `3.5 * ATR(20,D1)` below executable entry and no
   take-profit.
6. Return magnitude, gap size, weekday price action, volatility rank, season,
   and recent PnL may not change direction or risk.

## 5. Exit Rules

1. Close at the first tick at or after Monday 21:00 broker time.
2. If Monday's cutoff was not tradable or the EA was detached, close on the
   first later broker-week tick after Monday.
3. Close after 96 elapsed hours as an absolute stale guard.
4. Close immediately for an owned wrong-symbol, non-buy, duplicate, or
   missing/invalid-stop position.
5. The frozen broker stop and framework kill switch remain authoritative.
6. Framework Friday close is deliberately disabled because the weekend hold
   is the signal. There is no target, trail, break-even, partial close,
   opposite signal, gap-fill exit, scale-in, grid, martingale, or pyramid.

## 6. Filters (No-Trade Module)

- Fail closed for wrong symbol/timeframe, EA ID, slot, risk mode, news/Friday
  contract, or unlocked baseline input.
- Fail closed outside the exact Friday 21:00 entry bar, after a consumed week,
  with owned exposure/same-week deal, invalid week/H1/D1 time state, missing
  completed D1 ATR, negative/excessive spread, invalid quote, or invalid stop.
- Q02 locks both news axes and legacy news mode OFF. Lifecycle exits run before
  entry-only gates and cannot be delayed by news state.
- Runtime may not read weather, EIA storage, a calendar file, API, futures
  curve, analyst forecast, portfolio state, or external data.

## 7. Trade Management Rules

- Maintain at most one long `XNGUSD.DWX` position under the registered magic.
- Preserve the original hard stop and execute Monday/later-week/stale repair
  on every tick.
- Terminal-persistent weekly attempt state plus owned deal history prevents
  restart-driven same-week re-entry. Tester initialization clears future
  terminal-global state for deterministic historical runs.
- No short, hedge, retry, pending order, target, trail, break-even, partial
  close, scale-in, grid, martingale, pyramid, random path, or adaptive fit.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_entry_hour_broker` | 21 | [21] | exact Friday H1 entry boundary |
| `strategy_entry_grace_minutes` | 5 | [5] | maximum late-attach delay from the H1 boundary |
| `strategy_exit_hour_broker` | 21 | [21] | exact Monday exit boundary |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 hard-stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen hard-stop multiple |
| `strategy_max_hold_hours` | 96 | [96] | absolute missed-cutoff stale guard |
| `strategy_max_spread_points` | 1000 | [1000] | XNG entry spread ceiling |

There is no baseline sweep. Weekdays, H1 clock semantics, long direction,
week-key persistence, D1 stop timeframe, risk, and exit behavior are locked.

## Author Claims

The complete governed review records positive natural-gas Monday
coefficients across the paper's five full-sample estimators and persistent
positive results in both source subperiods. Those are historical EIA spot
regressions, not an investable CFD backtest and not a performance promise for
this translation.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Risk is high: the EA deliberately carries XNG through
the weekend when the market can gap beyond the stop. Source-to-CFD timing,
21:00 cutoff basis, Monday holidays, roll effects, spreads, stop slippage,
weather shocks, regime decay, and correlation with the incumbent XNG sleeve
can dominate the premise.

## Kill Criteria

- Retire on zero trades or fewer than five completed positions per full year.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Fail on entry after Monday opens, any Friday short, gap/trend-conditioned
  direction, same-week retry, premature framework Friday flatten, hold beyond
  the governed Monday/later-week/96-hour boundary, missing hard stop, invalid
  risk mode, or nondeterminism.
- Do not rescue failure by changing weekdays/hours, selecting months, adding
  a gap or trend gate, adding a target, widening the stop, extending the hold,
  or retrying.

## Strategy Allowability Check

| gate | verdict | reasoning |
|---|---|---|
| R1 | PASS | One bounded lineage backed by a complete governed peer-reviewed energy-weekend review and official EIA gas-driver context. |
| R2 | PASS | Fixed carrier, Friday/Monday clock, direction, attempt state, risk, stop, exit, and repair. |
| R3 | PASS | Registered native XNG H1/D1 history and MT5 broker/position state; no external runtime series. |
| R4 | PASS | Deterministic native arithmetic only, without trained output, adaptive PnL state, grid, or martingale. |

- [x] Dedup: exact identity clean; one source-family fuzzy match and all
  closest XNG weekend/weekday systems manually separated.
- [x] Friday-close exception: explicitly required, bounded to one weekend,
  protected by a server hard stop, Monday exit, and 96-hour stale guard.

## Framework Alignment

- no_trade: exact identity, host, slot, fixed-risk, news-off, Friday-off, and
  locked-input guards.
- trade_entry: genuine Friday 21:00 H1 gate, persistent week attempt, spread,
  quote, completed-D1 ATR/stop checks, and one fixed-risk XNG buy.
- trade_management: malformed-state repair, Monday cutoff, later-week missed-
  cutoff repair, and 96-hour stale close on every tick.
- trade_close: framework close helper, frozen broker hard stop, and kill switch.

## Safety Boundary

This card authorizes only deterministic allocation, a non-live V5 build,
strict compile/Q01, and one paced Q02 handoff when CPU capacity permits. It
does not authorize a manual backtest; live/demo/shadow/stress/optimization
setfile; AutoTrading; `T_Live`; deploy or T_Live manifest; portfolio-gate
change; portfolio admission; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-14 | initial XNG pre-weekend to Monday structural hold | G0 | APPROVED; QM5_21519 allocated |
| v2 | 2026-08-14 | implement locked weekend-hold lifecycle and fixed-risk build | Q01 | PASS; strict compile/build validation complete |
| v2 | 2026-08-14 | canonical paced Q02 enqueue attempt | Q02 | BLOCKED_FACTORY_OFF; no work item created |

## Pipeline Phase Status

| phase | date | verdict | evidence |
|---|---|---|---|
| G0 Research Intake | 2026-08-14 | APPROVED; R1-R4 PASS | `decisions/2026-08-14_xng_wkend_hold_g0.md`; bounded source packet |
| Q01 Build Validation | 2026-08-14 | PASS | strict compile 0/0; final build check 0/0; seven reference tests; symbol scope PASS; P1 artifact PASS |
| Q02 Baseline Screening | 2026-08-14 | BLOCKED_FACTORY_OFF | canonical `enqueue-backtest` refused the OWNER forensic pause; 0/10 factory MT5 slots active and no work item created; see `docs/ops/evidence/2026-08-14_qm5_21519_xng_wkend_hold_q01_factory_off_handoff.md` |
