---
ea_id: QM5_20133
slug: wti-wpsr-pb
type: strategy
strategy_id: EIA-WTI-WPSR-INTRADAY-2026_S01
source_id: EIA-WTI-WPSR-INTRADAY-2026
status: APPROVED
g0_status: APPROVED
created: 2026-07-25
created_by: Research+Development
last_updated: 2026-07-25
source_authors: "U.S. Energy Information Administration"
strategy_mechanic: standard-wednesday-eia-wti-m30-completed-release-shallow-pullback-continuation
source_citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report and official release schedule. Repository packet reviewed and OWNER-approved 2026-07-25."
source_citations:
  - type: official_government_release
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: "https://www.eia.gov/petroleum/supply/weekly/"
    quality_tier: A
    role: primary
  - type: official_government_schedule
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report release schedule."
    location: "https://www.eia.gov/petroleum/supply/weekly/schedule.php"
    quality_tier: A
    role: timing
sources:
  - "[[sources/EIA-WTI-WPSR-INTRADAY-2026]]"
concepts:
  - "[[concepts/crude-oil-inventory-event]]"
  - "[[concepts/information-impulse-continuation]]"
  - "[[concepts/shallow-pullback]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [scheduled-event, impulse-pullback-continuation, structural, same-session-exit, low-frequency, long-short, structural-hard-stop]
markets: [commodities, energy, crude_oil]
timeframes: [M30]
period: M30
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_20133_WTI_WPSR_PB_M30
expected_trade_frequency: "At most one consumed standard-Wednesday decision per week; completed impulse, breakout, shallow counter-bar, hold, gap, spread and geometry gates estimate approximately 8-20 completed trades/year."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 22.0
risk_class: high
ml_required: false
r1_track_record: TIER_A
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
review_focus: "Falsify whether a completed standard-WPSR WTI impulse that survives one shallow counter-direction M30 pullback continues after CFD costs, DST conversion, one-shot execution and same-session truncation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode_dual, magic_schema, one_position_per_magic_symbol, restart_safe_attempt, event_clock_dst, same_session_flat, structural_stop, source_claim_boundary, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission: R1 tier-A official EIA WPSR event and schedule lineage in an approved durable repository packet; R2 exact completed M30 impulse, counter-bar pullback, hold, direction, stop, target and exits; R3 registered XTIUSD.DWX M30 history route; R4 deterministic OHLC/calendar/ATR arithmetic only; deterministic and targeted dedup checks found no exact mechanic."
---

# EIA WTI WPSR M30 Shallow-Pullback Continuation

## Hypothesis

The EIA Weekly Petroleum Status Report supplies a recurring,
commodity-specific information clock. This card tests whether a directional
`XTIUSD.DWX` release impulse that breaks the completed pre-release range and
then survives one shallow counter-direction M30 pullback continues during the
same New York session.

The strategy does not predict or read the inventory number. It waits until
both the 10:30-11:00 New York release bar and the 11:00-11:30 pullback bar are
complete. It enters only when the second bar retraces, but does not invalidate,
the first bar's breakout. The thresholds, continuation direction, stop,
target, and lifecycle are QM research hypotheses. This card makes no
performance, decorrelation, certification, or portfolio-admission claim.

## Source and interpretation boundary

The sole durable lineage is
`strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md`. That
OWNER-approved packet relies on existing repository evidence for the official
WPSR event family and the standard Wednesday 10:30 New York clock. Holiday
weeks can shift the schedule.

Fresh deterministic routing of the official report and schedule URLs on
2026-07-25 returned `DEFERRED:SOURCE_POLICY`. No new webpage text is imported.
Version 1 trades only the standard Wednesday clock and deliberately skips
holiday-shifted releases. Runtime reads no inventory value, consensus,
surprise, calendar file, API, futures curve, volume, open interest, or
external market data. EIA supports only the event identity and schedule
lineage; it does not claim this price rule is profitable or that a Darwinex
CFD replicates NYMEX futures.

## Non-duplicate decision

The deterministic dedup check scanned 4,190 EA-registry rows and 376 research
cards and returned CLEAN. A targeted repository mechanic search was then
manually resolved against the closest event-family neighbors:

- `QM5_1121_unger-crude-inventory-release` places an M5 pre-release stop
  straddle and can trigger inside the release window. This card places no
  pending orders and cannot decide until two post-release M30 bars are closed.
- `QM5_10319_eia-oil-momo` reads the completed release-bar direction but waits
  until a late broker-time window; it has no required shallow counter-bar or
  pre-release-range breakout. This card decides at 11:30 New York.
- `QM5_12579_eia-wti-aftershock`, `QM5_12590_eia-wti-wpsr-fade`,
  `QM5_12752_eia-wti-wpsr-idbrk`, and
  `QM5_12988_xti-eia-inventory-momentum` operate on D1 event, consolidation,
  or multiweek states rather than this exact two-bar intraday sequence.
- `QM5_13042_xti-distdraw-mom`, `QM5_13044_xti-padd3-draw`, and
  `QM5_13063_xti-padd2-draw` are seasonal D1 long-only proxy sleeves. They
  use multi-day pullbacks, SMA filters, and monthly caps; this card is
  symmetric, exact-clock, intraday, and same-session flat.
- `QM5_20124_xng-stor-m30` enters XNG immediately after a release impulse with
  no completed pullback. `QM5_20128_xng-stor-fade` requires a full reclaim and
  trades opposite the failed break. This WTI card waits for a shallow
  non-reclaiming pullback and trades continuation in the original direction.
- `QM5_12567_cum-rsi2-commodity` is a D1 cumulative-RSI trend pullback with a
  multiday lifecycle. This card has no oscillator, slow trend mean, or
  multiday hold.

The source event family overlaps other WPSR work, but information state,
decision latency, pullback geometry, direction, stop, target, and holding
interval do not. Q09 and the unchanged portfolio gate remain authoritative
for realized correlation and any eventual admission.

## Markets, timeframe, and cadence

- Target symbol: exact `XTIUSD.DWX`.
- Timeframe: M30.
- Magic slot: 0; allocated magic `201330000`.
- Decision clock: first executable tick of the 11:30 New York M30 bar on a
  standard Wednesday.
- Maximum cadence: one consumed decision per standard Wednesday.
- Expected cadence: approximately 8-20 completed trades/year; retire below
  five completed trades/year on average.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Rules

The following rules are the complete authorized baseline. A different event
clock, holiday treatment, range definition, pullback geometry, direction,
stop, target, or holding interval requires a new card.

## 4. Entry Rules

1. Require exact `XTIUSD.DWX`, M30, magic slot 0, and all locked inputs.
2. Convert broker bar timestamps to New York time with the V5 broker/UTC and
   U.S. DST helpers.
3. Evaluate only when the current M30 bar opens at 11:30 New York on
   Wednesday. Persist the New York date as consumed before history, signal,
   news, spread, quote, gap, geometry, or order checks. Rejection, restart,
   stop, or a blocked gate cannot retry that date.
4. Require the first observed tick within 15 minutes of the 11:30 bar open.
   Late attachment consumes the date and remains flat.
5. Require exact same-date completed M30 bars beginning 09:30, 10:00, 10:30,
   and 11:00 New York. The first two bars define the pre-release high and low;
   the 10:30 bar is the release impulse; the 11:00 bar is the pullback.
6. Compute ATR(20) on the completed release bar. Require release range at least
   `0.75 * ATR(20)`, body/range at least `0.50`, and a release close at least
   `0.05 * ATR(20)` beyond the pre-release range in its body direction.
7. For a bullish release, require the pullback bar to be bearish, close below
   the release close, remain strictly above the pre-release high, and retrace
   between `0.15` and `0.50` of the release-bar range measured from the
   release close.
8. For a bearish release, require the pullback bar to be bullish, close above
   the release close, remain strictly below the pre-release low, and retrace
   between `0.15` and `0.50` of the release-bar range measured from the
   release close.
9. Enter at market in the original release direction. Reject when executable
   price gaps farther than `0.25 * ATR(20)` from the pullback close, when an
   EA-owned position exists, or when entry spread exceeds 1,000 points.
10. For a long, place the hard stop below the lower of the release and
    pullback lows by `0.10 * ATR(20)`. For a short, place it above the higher
    of their highs by the same buffer. Reject stop distance below
    `0.25 * ATR(20)` or above `3.00 * ATR(20)`.
11. Set take profit at `1.50R`, measured from executable market price to the
    frozen structural stop. Reject invalid or broker-noncompliant geometry.

## 5. Exit Rules

1. Broker-side structural hard stop or fixed `1.50R` take profit.
2. Close on the first tick at or after 15:55 New York on the entry date.
3. If the session close is missed, close on the first tick whose New York date
   differs from the entry date.
4. Close after six elapsed hours as a stale guard.
5. Framework Friday close and kill-switch closures remain authoritative.

Lifecycle exits always run before entry-only news checks. No news condition
may delay the session, date-change, stale, hard-stop, or target exit.

## 6. Filters (No-Trade Module)

- Fail closed for the wrong symbol, timeframe, slot, or unlocked input.
- Fail closed for a non-Wednesday clock, wrong bar timestamps, missing or
  invalid OHLC/ATR, inadequate release impulse, close not beyond the
  pre-release range, absent or excessive pullback, pullback reclaim into the
  old range, wrong pullback body, late attach, consumed date, excess entry
  gap, invalid stop/target, negative/excess spread, or an owned position.
- Q02 freezes both news axes OFF because the scheduled WPSR release is the
  strategy event and no external calendar dependency is permitted.

## 7. Trade Management Rules

- One market position per magic/symbol and one consumed attempt per standard
  Wednesday.
- Maintain the original server-side stop and target; do not trail or move
  either one.
- No holiday-shift inference, retry, reversal, pending order, scale-in,
  partial close, break-even, grid, martingale, pyramid, random path, adaptive
  fit, or external runtime feed.
- Run every-tick same-session, date-change, and stale lifecycle checks.

## Parameters to test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_release_hhmm_ny` | 1030 | [1030] | standard WPSR release-bar open |
| `strategy_pullback_hhmm_ny` | 1100 | [1100] | completed counter-bar open |
| `strategy_entry_hhmm_ny` | 1130 | [1130] | post-pullback decision |
| `strategy_pre_release_bars` | 2 | [2] | completed 09:30-10:30 range |
| `strategy_atr_period` | 20 | [20] | completed M30 risk estimator |
| `strategy_min_release_range_atr` | 0.75 | [0.75] | event impulse floor |
| `strategy_min_release_body_ratio` | 0.50 | [0.50] | directional body floor |
| `strategy_break_buffer_atr` | 0.05 | [0.05] | close beyond pre-range |
| `strategy_min_retrace_fraction` | 0.15 | [0.15] | minimum counter-bar pullback |
| `strategy_max_retrace_fraction` | 0.50 | [0.50] | maximum non-failure pullback |
| `strategy_max_entry_gap_atr` | 0.25 | [0.25] | executable-price gap ceiling |
| `strategy_stop_buffer_atr` | 0.10 | [0.10] | stop beyond event-sequence extreme |
| `strategy_min_stop_atr` | 0.25 | [0.25] | minimum risk geometry |
| `strategy_max_stop_atr` | 3.00 | [3.00] | maximum risk geometry |
| `strategy_target_rr` | 1.50 | [1.50] | fixed take-profit multiple |
| `strategy_entry_grace_minutes` | 15 | [15] | late-attach tolerance |
| `strategy_session_flat_hhmm_ny` | 1555 | [1555] | same-session flat |
| `strategy_max_hold_hours` | 6 | [6] | stale guard |
| `strategy_max_spread_points` | 1000 | [1000] | spread ceiling |

There is no baseline parameter sweep.

## Author claims

The source packet establishes an official recurring petroleum-report event and
schedule lineage. It makes no trading-performance claim for the impulse,
pullback, continuation, fixed-R target, or Darwinex CFD carrier. No source
return, hit rate, profit factor, drawdown, or correlation estimate is
imported.

## Initial risk profile

- `expected_pf: 1.01` is a conservative sequencing prior only.
- `expected_dd_pct: 22.0` reflects release-gap, crude-oil, and intraday
  execution risk.
- Expected frequency is approximately 8-20 completed trades/year.
- Risk class is high.
- Gridding, scalping, and ML are false.

## Kill criteria

- Retire on zero trades or fewer than five completed trades/year on average.
- Fail on entry before both event bars complete, entry outside the standard
  Wednesday clock, entry against the impulse, no shallow counter-bar,
  pullback close inside the pre-release range, duplicate same-date entry,
  overnight hold, nondeterminism, invalid risk mode, missing hard stop/target,
  or any governed PF/DD failure.
- Do not rescue failure by reading an external surprise feed, adding observed
  holiday dates, lowering the impulse or breakout threshold, widening the
  retracement band, removing the hold rule, moving the stop, extending
  overnight, or fitting direction after results.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses executable distance to the frozen
event-sequence stop. WTI gaps, release slippage, CFD/futures basis, spread
expansion, entry gaps, DST mapping, and intrabar path dependence are
first-order kill risks. The same-session lifecycle limits, but does not
remove, event and liquidity risk.

## Strategy allowability check

- [x] R1: official U.S. EIA WPSR event and schedule lineage in an
  OWNER-approved durable repository packet, tier A.
- [x] R2: fixed event clock, completed pre-range/impulse/pullback bars,
  deterministic direction, stop, target, attempt state, and exits.
- [x] R3: registered `XTIUSD.DWX` M30 history for 2017-2025.
- [x] R4: deterministic OHLC/calendar/ATR arithmetic; no ML, banned indicator,
  external signal, grid, or martingale.
- [x] Dedup: deterministic CLEAN plus manual WPSR/intraday-family
  differentiation.

## Framework alignment

- no_trade: exact host/timeframe/slot, locked-input, timestamp, history,
  release, pullback, gap, spread, and geometry guards.
- trade_entry: DST-aware Wednesday sequence, persisted attempt, pre-range,
  impulse and shallow-pullback tests, continuation market entry, structural
  stop, and fixed-R target.
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
| v1 | 2026-07-25 | initial source-backed WTI release pullback-continuation card | G0 | APPROVED |
| v1 | 2026-07-25 | strict compile and targeted build validation complete | Q01 | PASS |
| v1 | 2026-07-25 | paced baseline handoff; no backtest launched | Q02 | ENQUEUED |

## Pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-25 | APPROVED | this card |
| Q01 Build Validation | 2026-07-25 | PASS | `docs/ops/evidence/2026-07-25_qm5_20133_wti_wpsr_pullback_build_q02_enqueue.md` |
| Q02 Baseline Screening | 2026-07-25 | ENQUEUED | work item `c8f77304-f43b-4d5b-bd00-a4b9afbaa482`; same evidence |
