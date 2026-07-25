---
ea_id: QM5_20132
slug: xng-stor-orb
type: strategy
strategy_id: EIA-XNG-STORAGE-INTRADAY-2026_S03
source_id: EIA-XNG-STORAGE-AFTERSHOCK-2026
status: APPROVED
g0_status: APPROVED
created: 2026-07-25
created_by: Research+Development
last_updated: 2026-07-25
source_authors: "U.S. Energy Information Administration"
strategy_mechanic: standard-thursday-eia-xng-m30-live-release-prehour-range-breakout
source_citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report; Natural Gas Data regular weekly release schedule; WNGSR holiday release schedule. Repository packet reviewed and OWNER-approved 2026-07-25."
source_citations:
  - type: official_government_release
    citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report and official release schedule."
    location: "https://www.eia.gov/naturalgas/storage/ ; https://ir.eia.gov/ngs/schedule.html"
    quality_tier: A
    role: primary
sources:
  - "[[sources/EIA-XNG-STORAGE-AFTERSHOCK-2026]]"
concepts:
  - "[[concepts/natural-gas-storage]]"
  - "[[concepts/scheduled-event-breakout]]"
  - "[[concepts/opening-range-breakout]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [scheduled-event, range-breakout, structural, same-session-exit, low-frequency, long-short, structural-hard-stop]
markets: [commodities, energy, natural_gas]
timeframes: [M30]
period: M30
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_20132_XNG_STORAGE_ORB_M30
expected_trade_frequency: "At most one consumed standard-Thursday release-window breakout per week; the completed-range, ATR-width and first-escape rules estimate approximately 10-30 completed trades/year before spread and execution gates."
expected_trades_per_year_per_symbol: 20
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: TIER_A
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
review_focus: "Falsify whether the first live XNG escape from an ATR-bounded pre-release range persists through the standard storage-report window after CFD spread, slippage, DST conversion, one-shot execution and same-session truncation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode_dual, magic_schema, one_position_per_magic_symbol, restart_safe_attempt, event_clock_dst, same_session_flat, structural_stop, source_claim_boundary, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission: R1 tier-A official EIA WNGSR clock from the approved repository packet; R2 exact completed pre-range, live first escape, one-shot state, stop, target and exits; R3 registered XNG M30 route; R4 deterministic OHLC/calendar/ATR only; fuzzy storage siblings manually resolved as different decision states."
---

# EIA XNG Storage-Release M30 Live Range Breakout

## Hypothesis

The EIA Weekly Natural Gas Storage Report supplies a recurring,
commodity-specific information clock. This card tests whether the first live
escape from the completed 09:30-10:30 New York pre-release range persists
after the standard 10:30 release begins.

The strategy does not predict or read the storage number. It freezes the prior
hour before the release bar begins, trades at most the first buffered escape,
and must be flat in the same New York session. The range thresholds, direction,
stop, target, and lifecycle are QM research hypotheses. This card makes no
performance, decorrelation, or portfolio-admission claim.

## Source and interpretation boundary

The sole durable lineage is
`strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/source.md`. That
OWNER-approved repository packet records the official EIA natural-gas storage
event and the regular Thursday 10:30 New York release clock. Holiday-week
exceptions exist.

Version 1 trades only the standard Thursday clock and deliberately skips
holiday-shifted releases. Runtime reads no storage level, consensus, surprise,
calendar file, API, futures curve, weather input, or external market data.
EIA supports only the event identity and clock; it does not claim that this
breakout rule is profitable or that a Darwinex CFD replicates Henry Hub
futures.

A fresh generic-source-router request on 2026-07-25 was policy-deferred.
No new webpage content is imported into this card; it relies on the already
approved same-day repository packet.

## Non-duplicate decision

The deterministic dedup scan checked 4,189 registry rows and 376 cards. It
returned two expected source-family fuzzy matches, manually resolved as
different mechanics:

- `QM5_20124_xng-stor-m30` waits until 11:00 New York, after the complete
  10:30-11:00 release bar is known. It requires that completed bar's range,
  body, and close to confirm continuation. This card freezes only pre-release
  bars and enters during the still-forming release bar on the first buffered
  escape.
- `QM5_20128_xng-stor-fade` waits until 11:30, requires the 11:00 bar to
  reclaim the old range and cross the release midpoint, then fades the failed
  break toward the release open. This card never waits for a reclaim and
  always trades in the first-break direction.
- `QM5_12725_eia-xng-prestor` uses D1 compression and trend state before an
  expected storage day. It does not define an exact New York pre-release
  range or a live 10:30 breakout.
- `QM5_12567_cum-rsi2-commodity` is a D1 cumulative-RSI pullback with a slow
  trend filter and multiday hold. This card has no oscillator, trend mean, or
  multiday lifecycle.

The source event family overlaps, but information state, decision latency,
entry condition, stop geometry, target, and holding interval do not. Q09 and
the unchanged portfolio gate remain authoritative for realized correlation.

## Markets, timeframe, and cadence

- Target symbol: exact `XNGUSD.DWX`.
- Timeframe: M30.
- Magic slot: 0; registered magic `201320000`.
- Setup clock: completed 09:30 and 10:00 New York M30 bars on a standard
  Thursday.
- Entry window: 10:30 inclusive through 11:00 exclusive New York.
- Maximum cadence: one consumed breakout decision per standard Thursday.
- Expected cadence: approximately 10-30 completed trades/year; retire below
  five completed trades/year on average.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Rules

The following rules are the complete authorized baseline. A different event
clock, holiday treatment, range definition, breakout direction, stop, target,
or holding interval requires a new card.

## 4. Entry Rules

1. Require exact `XNGUSD.DWX`, M30, magic slot 0, and all locked inputs.
2. Convert broker timestamps to New York time with the V5 broker/UTC and U.S.
   DST helpers.
3. On the first tick of a standard-Thursday 10:30 New York M30 bar, load exact
   same-date completed bars beginning at 09:30 and 10:00. Their combined high
   and low define the pre-release range.
4. Compute M30 ATR(20) from completed bars. Arm the setup only when the
   pre-release range width is at least `0.25 * ATR(20)` and no more than
   `1.25 * ATR(20)`.
5. The long trigger is pre-release high plus `0.10 * ATR(20)`. The short
   trigger is pre-release low minus `0.10 * ATR(20)`.
6. During 10:30-11:00 New York, BUY on the first tick whose executable ask is
   at or above the long trigger, or SELL on the first tick whose executable
   bid is at or below the short trigger.
7. If both triggers are simultaneously true, consume the date and remain
   flat. Otherwise require trigger overshoot no greater than `0.30 * ATR(20)`.
8. Persist the New York date as consumed before news, spread, price geometry,
   or order checks. Rejection, restart, stop, or a blocked gate cannot retry
   that date or reverse into the opposite break.
9. Require no EA-owned open position and entry spread no greater than 2,500
   points.
10. For a long, place the hard stop below the pre-release low by
    `0.10 * ATR(20)`. For a short, place it above the pre-release high by the
    same buffer.
11. Set take profit at `1.50R`, measured from executable market price to the
    frozen structural stop. Reject invalid or broker-noncompliant geometry.

## 5. Exit Rules

1. Broker-side structural hard stop or fixed `1.50R` take profit.
2. Close on the first tick at or after 15:55 New York on the entry date.
3. If the session close is missed, close on the first tick whose New York
   date differs from the entry date.
4. Close after eight elapsed hours as a stale guard.
5. Framework Friday close and kill-switch closures remain authoritative.

Lifecycle exits always run before entry-only news checks. No news condition
may delay the session or stale close.

## 6. Filters (No-Trade Module)

- Fail closed for the wrong symbol, timeframe, slot, or unlocked input.
- Fail closed for a non-Thursday clock, missing or non-exact pre-release bar
  timestamps, invalid OHLC/ATR, pre-release width outside the locked band,
  ambiguous simultaneous triggers, excess overshoot, an elapsed entry window,
  consumed date, invalid stop/target, negative/excess spread, or an owned
  position.
- Q02 freezes both news axes OFF because the storage release is the strategy
  event and no external calendar dependency is permitted.

## 7. Trade Management Rules

- One market position per magic/symbol and one consumed attempt per standard
  Thursday.
- Maintain the original server-side stop and target; do not trail or move
  either one.
- No holiday-shift inference, retry, reversal after the first trigger,
  pending order, scale-in, partial close, break-even, grid, martingale,
  pyramid, random path, adaptive fit, or external runtime feed.
- Run every-tick same-session, date-change, and stale lifecycle checks.

## Parameters to test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_release_hhmm_ny` | 1030 | [1030] | official standard WNGSR clock |
| `strategy_entry_end_hhmm_ny` | 1100 | [1100] | live breakout window end |
| `strategy_pre_release_bars` | 2 | [2] | completed 09:30-10:30 range |
| `strategy_atr_period` | 20 | [20] | completed M30 risk estimator |
| `strategy_min_range_atr` | 0.25 | [0.25] | minimum usable range width |
| `strategy_max_range_atr` | 1.25 | [1.25] | maximum pre-event compression width |
| `strategy_break_buffer_atr` | 0.10 | [0.10] | trigger and stop buffer |
| `strategy_max_overshoot_atr` | 0.30 | [0.30] | maximum executable trigger overshoot |
| `strategy_target_rr` | 1.50 | [1.50] | fixed take-profit multiple |
| `strategy_session_flat_hhmm_ny` | 1555 | [1555] | same-session flat |
| `strategy_max_hold_hours` | 8 | [8] | stale guard |
| `strategy_max_spread_points` | 2500 | [2500] | spread ceiling |

There is no baseline parameter sweep.

## Author claims

The source packet establishes a recurring official natural-gas storage report
and its standard release clock. It makes no trading-performance claim for the
pre-release range, live breakout, fixed-R target, or Darwinex CFD carrier. No
source return, hit rate, profit factor, drawdown, or correlation estimate is
imported.

## Initial risk profile

- `expected_pf: 1.01` is a conservative sequencing prior only.
- `expected_dd_pct: 25.0` reflects event-gap and natural-gas tail risk.
- Expected frequency is approximately 10-30 completed trades/year.
- Risk class is high.
- Gridding, scalping, and ML are false.

## Kill criteria

- Retire on zero trades or fewer than five completed trades/year on average.
- Fail on entry before 10:30 or at/after 11:00 New York, use of a current or
  future bar in the range, entry without a buffered break, retry or reversal
  after the first trigger, overnight hold, nondeterminism, invalid risk mode,
  missing hard stop/target, or any governed PF/DD failure.
- Do not rescue failure by reading an external surprise feed, adding observed
  holiday dates, widening the entry window, removing the range-width band,
  shrinking the breakout buffer, moving the stop, extending overnight, or
  fitting direction after results.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses executable distance to the frozen
opposite-range stop. Natural-gas gaps, release slippage, CFD/futures basis,
spread expansion, trigger overshoot, DST mapping, and intrabar path dependence
are first-order kill risks. The same-session lifecycle limits, but does not
remove, event and liquidity risk.

## Strategy allowability check

- [x] R1: one official U.S. EIA source lineage in an OWNER-approved durable
  repository packet, tier A.
- [x] R2: fixed event clock, completed pre-range, deterministic first escape,
  direction, stop, target, attempt state, and exits.
- [x] R3: registered `XNGUSD.DWX` M30 route.
- [x] R4: deterministic OHLC/calendar/ATR arithmetic; no ML, banned indicator,
  external signal, grid, or martingale.
- [x] Dedup: source-family fuzzy neighbors manually resolved as different
  information states and mechanics.

## Framework alignment

- no_trade: exact host/timeframe/slot, locked-input, bar-timestamp, range-width,
  trigger-window, overshoot and spread guards.
- trade_entry: DST-aware pre-release range arming, every-tick first escape,
  persisted attempt, market entry, structural stop, and fixed-R target.
- trade_management: every-tick 15:55 New York, date-change, and stale closure.
- trade_close: broker stop/target, framework kill switch/Friday close, and
  explicit same-session closure.

## Safety boundary

This approval covers one card, deterministic registries, EA build, strict
compile, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does
not authorize a live setfile, AutoTrading, `T_Live`, a deploy or T_Live
manifest, portfolio admission, a portfolio-gate change, portfolio KPIs, or a
correlation waiver.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-25 | initial source-backed live storage-window breakout card | Q02 | ENQUEUED |

## Pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-25 | APPROVED | this card |
| Q01 Build Validation | 2026-07-25 | PASS | strict compile and targeted build check |
| Q02 Baseline Screening | 2026-07-25 | ENQUEUED | work item `58d05406-e34a-4764-ba22-ad40b4890c0e` |

## Lessons captured

- 2026-07-25: Fresh generic URL retrieval was policy-deferred; the card uses
  only the already approved same-day EIA repository packet.
