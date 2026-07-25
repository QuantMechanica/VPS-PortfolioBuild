---
ea_id: QM5_20134
slug: wti-wpsr-fail
type: strategy
strategy_id: EIA-WTI-WPSR-INTRADAY-2026_S02
source_id: EIA-WTI-WPSR-INTRADAY-2026
status: APPROVED
g0_status: APPROVED
created: 2026-07-25
created_by: Research+Development
last_updated: 2026-07-25
source_authors: "U.S. Energy Information Administration"
strategy_mechanic: standard-wednesday-eia-wti-m30-deep-reclaim-failed-break-fade
source_citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report and official release schedule. Existing durable repository packet reviewed under the OWNER commodity/energy sleeve mission."
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
  - "[[concepts/failed-auction]]"
  - "[[concepts/deep-range-reclaim]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [scheduled-event, failed-break-fade, structural, same-session-exit, low-frequency, symmetric-long-short, atr-hard-stop]
markets: [commodities, energy, crude_oil]
timeframes: [M30]
period: M30
primary_target_symbols: [XTIUSD.DWX]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_20134_WTI_WPSR_FAIL_M30
expected_trade_frequency: "At most one consumed standard-Wednesday decision per week; a completed release-range break plus a separate deep reclaim through the far half of the old range is expected to produce approximately 5-15 completed trades/year."
expected_trades_per_year_per_symbol: 10
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
review_focus: "Falsify whether a standard-WPSR WTI release break that is fully rejected through the far half of the pre-release range continues to reverse after CFD costs, DST conversion, one-shot execution, structural target geometry and same-session truncation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode_dual, magic_schema, one_position_per_magic_symbol, restart_safe_attempt, event_clock_dst, same_session_flat, structural_stop, source_claim_boundary, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission: R1 tier-A official EIA WPSR packet; R2 exact M30 impulse-break, deep pre-range reclaim, reversal, stop, target and exits; R3 registered XTIUSD.DWX M30 route; R4 deterministic OHLC/calendar/ATR only; deterministic and manual dedup clean."
---

# EIA WTI WPSR M30 Deep-Reclaim Failure Fade

## Hypothesis

The EIA Weekly Petroleum Status Report supplies a recurring,
commodity-specific information clock. This card tests whether a directional
`XTIUSD.DWX` release impulse that breaks the completed pre-release range but
is then rejected through the far half of that old range continues to reverse
during the same New York session.

The strategy predicts no inventory value and reads no report number. It waits
until both the 10:30-11:00 New York release bar and the 11:00-11:30 reclaim
bar are complete. The second bar must reverse the impulse, return inside the
old range, cross its midpoint, and close in the far half. Entry at 11:30 fades
the failed release break. The thresholds, direction, stop, target, and
lifecycle are QM research hypotheses, not source performance claims.

## Source and interpretation boundary

The durable lineage is
`strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md`. That
OWNER-approved packet relies on existing repository evidence for the official
WPSR event family and standard Wednesday 10:30 New York clock. Holiday weeks
can shift the schedule.

The repository packet records that deterministic generic-URL retrieval of the
official report and schedule was policy-deferred on 2026-07-25. No new webpage
text is imported here and no browser, proxy, cache, authentication, or policy
bypass is used. Version 1 trades standard Wednesdays only and deliberately
skips holiday-shifted releases.

Runtime reads no inventory value, consensus, surprise, external calendar,
API, futures curve, volume, open interest, or other non-MT5 data. EIA supports
only event identity and schedule lineage. It does not claim this price rule is
profitable or certify a Darwinex CFD as a NYMEX-futures replica.

## Non-duplicate decision

The deterministic slug/strategy scan returned CLEAN against 4,191 registry
rows and 376 research cards. The closest mechanics were then resolved
manually:

- `QM5_1121_unger-crude-inventory-release` places an M5 pre-release stop
  straddle and can trigger inside the release window. This card places no
  pending orders and cannot decide until two post-release M30 bars close.
- `QM5_10319_eia-oil-momo` follows a completed release-bar sign in a later
  broker-time window. It does not require a pre-range break followed by a
  midpoint-crossing deep reclaim.
- `QM5_12579_eia-wti-aftershock` follows a completed D1 event bar.
  `QM5_12590_eia-wti-wpsr-fade` fades a stretched completed D1 event bar on
  the next daily decision. Neither isolates this intraday failed auction.
- `QM5_12752_eia-wti-wpsr-idbrk` waits for a post-event D1 inside bar and then
  trades its breakout; this card instead fades a completed M30 range reclaim.
- `QM5_12988_xti-eia-inventory-momentum` requires two aligned weekly WPSR
  proxy reactions rather than one intraday rejection.
- `QM5_20133_wti-wpsr-pb` requires the 11:00 pullback to remain outside the
  pre-release range and trades continuation. This card requires the opposite
  state: a reclaim through the midpoint into the far half, then trades
  reversal.
- `QM5_20128_xng-stor-fade` trades a different commodity and report. It only
  requires an XNG reclaim inside the old range and through the release-bar
  midpoint, then targets the release open. This WTI rule requires a deeper
  pre-range-midpoint cross, targets the opposite pre-range boundary, imposes
  an executable-gap ceiling, and freezes a stop-distance band.
- `QM5_12567_cum-rsi2-commodity` is a D1 cumulative-RSI pullback with a
  multiday lifecycle. This card uses no oscillator, slow trend mean, or
  overnight hold.

The new decision state is therefore the completed WTI impulse-break followed
by a deep old-range reclaim. Realized correlation remains a downstream Q09
and unchanged portfolio-gate question.

## Markets, timeframe, and cadence

- Target symbol: exact `XTIUSD.DWX`.
- Timeframe: M30.
- Magic slot: 0; allocated magic `201340000`.
- Decision clock: first executable tick of the 11:30 New York M30 bar on a
  standard Wednesday.
- Maximum cadence: one consumed decision per standard Wednesday.
- Expected cadence: approximately 5-15 completed trades/year; retire below
  five completed trades/year on average.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Rules

The following rules are the complete authorized baseline. A different event
clock, holiday treatment, range definition, reclaim depth, direction, stop,
target, or holding interval requires a new card.

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
   and 11:00 New York. The first two bars define the frozen pre-release high,
   low, and midpoint; the 10:30 bar is the release impulse; the 11:00 bar is
   the reclaim.
6. Compute ATR(20) on the completed release bar. Require release range at
   least `0.75 * ATR(20)`, body/range at least `0.50`, and the release close at
   least `0.05 * ATR(20)` beyond the pre-release range in its body direction.
7. For a bullish release break, require the reclaim bar to be bearish and
   close strictly below the pre-release midpoint while remaining strictly
   above the pre-release low. Enter short.
8. For a bearish release break, require the reclaim bar to be bullish and
   close strictly above the pre-release midpoint while remaining strictly
   below the pre-release high. Enter long.
9. Reject when executable price gaps farther than `0.25 * ATR(20)` from the
   reclaim close, when an EA-owned position exists, or when entry spread
   exceeds 1,000 points.
10. For a short, place the hard stop above the higher of the release and
    reclaim highs by `0.10 * ATR(20)`. For a long, place it below the lower of
    their lows by the same buffer. Reject stop distance below
    `0.25 * ATR(20)` or above `3.00 * ATR(20)`.
11. For a short, set the structural target at the frozen pre-release low. For
    a long, set it at the frozen pre-release high. Require target reward of at
    least `0.75R` from the executable price and reject invalid or
    broker-noncompliant geometry.

## 5. Exit Rules

1. Broker-side event-sequence hard stop or frozen opposite-range target.
2. Close on the first tick at or after 15:55 New York on the entry date.
3. If the session close is missed, close on the first tick whose New York
   date differs from the entry date.
4. Close after six elapsed hours as a stale guard.
5. Framework Friday close and kill-switch closures remain authoritative.

Lifecycle exits always run before entry-only news checks. No news condition
may delay session, date-change, stale, hard-stop, or target exits.

## 6. Filters (No-Trade Module)

- Fail closed for the wrong symbol, timeframe, slot, or unlocked input.
- Fail closed for a non-Wednesday clock, wrong bar timestamps, missing or
  invalid OHLC/ATR, inadequate release impulse, release close not beyond the
  old range, absent/opposite-color failure bar, reclaim not through the old
  midpoint, reclaim beyond the opposite range edge, late attach, consumed
  date, excess entry gap, invalid stop/target, inadequate reward/risk,
  negative/excess spread, or an owned position.
- Q02 freezes both news axes OFF because the scheduled WPSR release is the
  strategy event and no external calendar dependency is permitted.

## 7. Trade Management Rules

- One market position per magic/symbol and one consumed attempt per standard
  Wednesday.
- Maintain the original server-side stop and target; never trail or move
  either level.
- No holiday-shift inference, retry, reversal, pending order, scale-in,
  partial close, break-even, grid, martingale, pyramid, random path, adaptive
  fit, or external runtime feed.
- Run every-tick same-session, date-change, and stale lifecycle checks.

## Parameters to test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_release_hhmm_ny` | 1030 | [1030] | standard WPSR release-bar open |
| `strategy_reclaim_hhmm_ny` | 1100 | [1100] | completed deep-reclaim bar open |
| `strategy_entry_hhmm_ny` | 1130 | [1130] | post-reclaim decision |
| `strategy_pre_release_bars` | 2 | [2] | completed 09:30-10:30 range |
| `strategy_atr_period` | 20 | [20] | completed M30 risk estimator |
| `strategy_min_release_range_atr` | 0.75 | [0.75] | event impulse floor |
| `strategy_min_release_body_ratio` | 0.50 | [0.50] | directional body floor |
| `strategy_break_buffer_atr` | 0.05 | [0.05] | release close beyond old range |
| `strategy_deep_reclaim_fraction` | 0.50 | [0.50] | old-range midpoint cross |
| `strategy_max_entry_gap_atr` | 0.25 | [0.25] | executable-price gap ceiling |
| `strategy_stop_buffer_atr` | 0.10 | [0.10] | stop beyond event-sequence extreme |
| `strategy_min_stop_atr` | 0.25 | [0.25] | minimum risk geometry |
| `strategy_max_stop_atr` | 3.00 | [3.00] | maximum risk geometry |
| `strategy_min_reward_risk` | 0.75 | [0.75] | minimum structural-target reward |
| `strategy_entry_grace_minutes` | 15 | [15] | late-attach tolerance |
| `strategy_session_flat_hhmm_ny` | 1555 | [1555] | same-session flat |
| `strategy_max_hold_hours` | 6 | [6] | stale guard |
| `strategy_max_spread_points` | 1000 | [1000] | spread ceiling |

There is no baseline parameter sweep.

## Author claims

The source packet establishes an official recurring petroleum-report event and
schedule lineage. It makes no trading-performance claim for the release
break, deep reclaim, reversal direction, structural target, or Darwinex CFD
carrier. No source return, hit rate, profit factor, drawdown, or correlation
estimate is imported.

## Initial risk profile

- `expected_pf: 1.01` is a conservative sequencing prior only.
- `expected_dd_pct: 25.0` reflects release-gap, crude-oil, and intraday
  execution risk.
- Expected frequency is approximately 5-15 completed trades/year.
- Risk class is high.
- Gridding, scalping, pyramiding, and ML are false.

## Kill criteria

- Retire on zero trades or fewer than five completed trades/year on average.
- Fail on entry before both event bars complete, entry outside the standard
  Wednesday clock, entry in the release direction, no deep midpoint reclaim,
  reclaim through the opposite range edge, duplicate same-date entry,
  overnight hold, nondeterminism, invalid risk mode, missing hard stop/target,
  or any governed PF/DD failure.
- Do not rescue failure by reading an external surprise feed, adding observed
  holiday dates, lowering the impulse/break threshold, weakening the midpoint
  reclaim, extending the target, removing the reward/risk gate, moving the
  stop, extending overnight, or fitting direction after results.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses executable distance to the frozen
event-sequence stop. WTI gaps, release slippage, CFD/futures basis, spread
expansion, entry gaps, target geometry, DST mapping, and intrabar path
dependence are first-order kill risks. Same-session flattening limits, but
does not remove, event and liquidity risk.

## Strategy allowability check

- [x] R1: official U.S. EIA WPSR event and schedule lineage in an
  OWNER-approved durable repository packet, tier A.
- [x] R2: fixed event clock, completed pre-range/impulse/reclaim bars,
  deterministic direction, stop, target, attempt state, and exits.
- [x] R3: registered `XTIUSD.DWX` M30 history route.
- [x] R4: deterministic OHLC/calendar/ATR arithmetic; no ML, banned indicator,
  external signal, grid, or martingale.
- [x] Dedup: deterministic CLEAN plus manual WPSR/intraday-family
  differentiation.

## Framework alignment

- no_trade: exact host/timeframe/slot, locked-input, timestamp, history,
  impulse, reclaim, gap, spread, stop, target, and reward/risk guards.
- trade_entry: DST-aware Wednesday sequence, persisted attempt, pre-range,
  impulse-break and deep-reclaim tests, reversal market entry, structural
  stop, and opposite-range target.
- trade_management: every-tick 15:55 New York, date-change, and stale closure.
- trade_close: broker stop/target, framework kill switch/Friday close, and
  explicit same-session closure.

## Safety boundary

This approval covers one card, deterministic registries, EA build, strict
compile, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does
not authorize a live setfile, AutoTrading,
`T_Live`, a deploy or T_Live manifest, portfolio admission, a portfolio-gate
change, portfolio KPIs, or a correlation waiver.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-25 | initial source-backed WTI release-failure card | G0 | APPROVED |
| v1 | 2026-07-25 | strict compile and targeted build validation complete | Q01 | PASS |
| v1 | 2026-07-25 | paced baseline handoff; no manual backtest launched | Q02 | ENQUEUED |

## Pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-25 | APPROVED | this card |
| Q01 Build Validation | 2026-07-25 | PASS | `docs/ops/evidence/2026-07-25_qm5_20134_wti_wpsr_failure_build_q02_enqueue.md` |
| Q02 Baseline Screening | 2026-07-25 | ENQUEUED | work item `bba6ba7f-788d-46a6-9568-b5ad69c06613`; same evidence |
