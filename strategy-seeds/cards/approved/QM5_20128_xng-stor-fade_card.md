---
ea_id: QM5_20128
slug: xng-stor-fade
type: strategy
strategy_id: EIA-XNG-STORAGE-INTRADAY-2026_S02
source_id: EIA-XNG-STORAGE-AFTERSHOCK-2026
status: APPROVED
g0_status: APPROVED
created: 2026-07-25
created_by: Research+Development
last_updated: 2026-07-25
source_authors: "U.S. Energy Information Administration"
strategy_mechanic: standard-thursday-eia-xng-m30-failed-release-break-reclaim-fade
source_citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report; Natural Gas Data regular weekly release schedule; WNGSR holiday release schedule. Reviewed 2026-07-25."
source_citations:
  - type: official_government_release
    citation: "U.S. Energy Information Administration. Weekly Natural Gas Storage Report."
    location: "https://www.eia.gov/naturalgas/storage/"
    quality_tier: A
    role: primary
  - type: official_government_schedule
    citation: "U.S. Energy Information Administration. Natural Gas Data and Weekly Natural Gas Storage Report Schedule."
    location: "https://www.eia.gov/naturalgas/data.php and https://ir.eia.gov/ngs/schedule.html"
    quality_tier: A
    role: timing
sources:
  - "[[sources/EIA-XNG-STORAGE-AFTERSHOCK-2026]]"
concepts:
  - "[[concepts/natural-gas-storage]]"
  - "[[concepts/failed-information-break]]"
  - "[[concepts/intraday-mean-reversion]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [scheduled-event, failed-breakout-fade, structural, same-session-exit, low-frequency, long-short, structural-hard-stop]
markets: [commodities, energy, natural_gas]
timeframes: [M30]
period: M30
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_20128_XNG_STORAGE_FADE_M30
expected_trade_frequency: "At most one consumed standard-Thursday decision per week; release-impulse and completed reclaim filters estimate approximately 6-18 completed trades/year before spread, reward/risk, and execution gates."
expected_trades_per_year_per_symbol: 8
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
q02_status: QUEUED_FACTORY_OFF
review_focus: "Falsify whether an exact-clock XNG release false break that reclaims the pre-release range mean-reverts to the release open after CFD costs, DST conversion, gas gaps, and same-session truncation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode_dual, magic_schema, one_position_per_magic_symbol, restart_safe_attempt, event_clock_dst, same_session_flat, structural_stop, source_claim_boundary, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission: R1 tier-A official EIA WNGSR clock; R2 exact completed M30 impulse/reclaim, stop, target and exits; R3 registered XNG M30 route; R4 deterministic OHLC/calendar/ATR only; fuzzy neighbors manually resolved as different mechanics."
---

# EIA XNG Storage-Release M30 Failed-Break Fade

## Hypothesis

The EIA Weekly Natural Gas Storage Report supplies a recurring,
commodity-specific information clock. This card tests whether an unusually
directional `XNGUSD.DWX` release bar that breaks the preceding one-hour range
but is fully rejected by the next completed M30 bar mean-reverts toward its
release open before the New York session ends.

The strategy does not predict or read the storage number. It waits until both
the 10:30-11:00 New York release bar and the 11:00-11:30 confirmation bar are
complete. The failed-break direction, thresholds, target, and stop are QM
research hypotheses. This card makes no performance, decorrelation, or
portfolio-admission claim.

## Source and interpretation boundary

The durable lineage packet is
`strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/source.md`. The official
EIA natural-gas data page identifies the regular Weekly Natural Gas Storage
Report release as Thursday at 10:30 a.m. eastern time. The official schedule
documents holiday-week exceptions.

Version 1 trades only the standard Thursday clock and deliberately skips
holiday-shifted releases. Runtime reads no storage level, consensus, surprise,
calendar file, API, futures curve, weather input, or external market data.
EIA supports the event identity and timing only; it does not claim that a
failed intraday release break is profitable or that a Darwinex CFD replicates
Henry Hub futures.

## Non-duplicate decision

The deterministic dedup scan checked 4,185 registry rows and 375 cards. It
returned only two expected fuzzy neighbors, both manually rejected as exact
duplicates:

- `QM5_20124_xng-stor-m30` enters at 11:00 with the completed release impulse
  and has no profit target. This card waits until 11:30, requires the next bar
  to close back inside the old range and through the release midpoint, then
  trades in the opposite direction toward the release open.
- `QM5_12744_eia-xng-storfade` evaluates a completed D1 bar on Wednesday,
  Thursday, or Friday, requires a slow-SMA stretch, and can hold for days.
  This card uses no SMA, trades one exact standard-Thursday M30 sequence, and
  must be flat in the same New York session.
- `QM5_12567_cum-rsi2-commodity` is a D1 cumulative-RSI pullback. This card has
  no oscillator, trend mean, or multi-day lifecycle.

The source event family overlaps, but signal state, decision time, direction,
target, and holding interval do not. Q09 and the unchanged portfolio gate
remain responsible for realized correlation.

## Markets, timeframe, and cadence

- Target symbol: exact `XNGUSD.DWX`.
- Timeframe: M30.
- Magic slot: 0; registered magic `201280000`.
- Decision clock: first executable tick of the 11:30 New York M30 bar on a
  standard Thursday.
- Maximum cadence: one consumed decision per standard Thursday.
- Expected cadence: approximately 6-18 completed trades/year; retire below
  five completed trades/year on average.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Rules

The following rules are the complete authorized baseline. A different event
clock, holiday treatment, reclaim definition, direction, target, stop, or
holding interval requires a new card.

## 4. Entry Rules

1. Require exact `XNGUSD.DWX`, M30, magic slot 0, and all locked inputs.
2. Convert broker bar timestamps to New York time with the V5 broker/UTC and
   U.S. DST helpers.
3. Evaluate only when the current M30 bar opens at 11:30 New York on Thursday.
   Persist the New York date as consumed before history, signal, news, spread,
   reward/risk, or order checks. Rejection, restart, stop, or a blocked gate
   cannot retry that date.
4. Require the first observed tick within 15 minutes of the 11:30 bar open.
   Late attachment consumes the date and remains flat.
5. Require exact same-date M30 bars beginning 09:30, 10:00, 10:30, and 11:00
   New York. The first two bars define the pre-release range, the 10:30 bar is
   the release impulse, and the 11:00 bar is the completed reclaim.
6. Compute ATR(20) on the completed release bar. Require release range at
   least `0.75 * ATR(20)` and release body/range at least `0.50`.
7. A bullish release impulse requires a bullish 10:30 bar closing strictly
   above the prior-hour high. Its short fade requires the 11:00 bar to be
   bearish and close strictly inside the prior-hour range and strictly below
   the release midpoint.
8. A bearish release impulse requires a bearish 10:30 bar closing strictly
   below the prior-hour low. Its long fade requires the 11:00 bar to be
   bullish and close strictly inside the prior-hour range and strictly above
   the release midpoint.
9. Require no EA-owned open position and entry spread no greater than 2,500
   points.
10. Enter at market opposite the failed release direction. Put the hard stop
    beyond the more extreme of the release and reclaim bars plus
    `0.25 * ATR(20)`. Set take profit at the release open.
11. Require the executable entry, stop, and target to be correctly ordered and
    the target distance divided by stop distance to be at least `0.50`.

## 5. Exit Rules

1. Broker-side structural hard stop or release-open take profit.
2. Close on the first tick at or after 15:55 New York on the entry date.
3. If the session close is missed, close on the first tick whose New York date
   differs from the entry date.
4. Close after six elapsed hours as a stale guard.
5. Framework Friday close and kill-switch closures remain authoritative.

Lifecycle exits always run before entry-only news checks. No news condition
may delay the session or stale close.

## 6. Filters (No-Trade Module)

- Fail closed for the wrong symbol, timeframe, slot, or unlocked input.
- Fail closed for a non-Thursday clock, wrong bar timestamps, missing or
  invalid OHLC/ATR, inadequate release impulse, reclaim close outside the
  prior range, failure to cross the release midpoint, wrong reclaim body,
  late attach, consumed date, invalid stop/target, reward/risk below `0.50`,
  negative/excess spread, or an owned position.
- Q02 freezes both news axes OFF because the storage release is the strategy
  event and no external calendar dependency is permitted.

## 7. Trade Management Rules

- One market position per magic/symbol and one consumed attempt per standard
  Thursday.
- Maintain the original server-side stop and target; do not trail or move
  either one.
- No holiday-shift inference, retry, pending order, scale-in, partial close,
  break-even, grid, martingale, pyramid, random path, adaptive fit, or external
  runtime feed.
- Run every-tick same-session, date-change, and stale lifecycle checks.

## Parameters to test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_release_hhmm_ny` | 1030 | [1030] | official standard WNGSR clock |
| `strategy_confirmation_hhmm_ny` | 1100 | [1100] | completed reclaim bar |
| `strategy_entry_hhmm_ny` | 1130 | [1130] | post-confirmation entry |
| `strategy_pre_release_bars` | 2 | [2] | prior-hour range |
| `strategy_min_release_range_atr` | 0.75 | [0.75] | impulse floor |
| `strategy_min_body_ratio` | 0.50 | [0.50] | impulse direction floor |
| `strategy_reclaim_mid_fraction` | 0.50 | [0.50] | midpoint cross |
| `strategy_atr_period` | 20 | [20] | release-bar risk estimator |
| `strategy_stop_buffer_atr` | 0.25 | [0.25] | stop beyond event extremes |
| `strategy_min_reward_risk` | 0.50 | [0.50] | entry geometry floor |
| `strategy_entry_grace_minutes` | 15 | [15] | late-attach tolerance |
| `strategy_session_flat_hhmm_ny` | 1555 | [1555] | same-session flat |
| `strategy_max_hold_hours` | 6 | [6] | stale guard |
| `strategy_max_spread_points` | 2500 | [2500] | spread ceiling |

There is no baseline parameter sweep.

## Kill criteria

- Retire on zero trades or fewer than five completed trades/year on average.
- Fail on entry before both event bars complete, entry outside the standard
  Thursday clock, wrong fade direction, no completed reclaim, duplicate
  same-date entry, overnight hold, nondeterminism, invalid risk mode, missing
  hard stop/target, or any governed PF/DD failure.
- Do not rescue failure by reading an external surprise feed, adding observed
  holiday dates, lowering the reclaim threshold, moving the target, widening
  the stop, extending overnight, or fitting direction after results.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses the executable distance to the
frozen structural stop. Natural-gas gaps, release slippage, CFD/futures basis,
wide spreads, reward/risk truncation, DST mapping, and post-event whipsaw are
first-order kill risks. The same-session lifecycle limits, but does not remove,
event and liquidity risk.

## Strategy allowability check

- [x] R1: one official U.S. EIA source lineage and release schedule, tier A.
- [x] R2: fixed event clock, completed bars, deterministic impulse/reclaim
  tests, direction, stop, target, attempt state, and exits.
- [x] R3: registered `XNGUSD.DWX` M30 route.
- [x] R4: deterministic OHLC/calendar/ATR arithmetic; no ML, banned indicator,
  external signal, grid, or martingale.
- [x] Dedup: fuzzy neighbors manually resolved as different mechanics.

## Framework alignment

- no_trade: exact host/timeframe/slot and locked-input guards.
- trade_entry: DST-aware Thursday sequence, persisted attempt, impulse/reclaim
  tests, spread and reward/risk gates, opposite market entry, structural stop,
  and release-open target.
- trade_management: every-tick 15:55 New York, date-change, and stale closure.
- trade_close: broker stop/target, framework kill switch/Friday close, and
  explicit same-session closure.

## Safety boundary

This approval request covers one card, deterministic registries, EA build,
strict compile, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue.
It does not authorize a live setfile, AutoTrading, `T_Live`, a deploy or
T_Live manifest, portfolio admission, a portfolio-gate change, portfolio
KPIs, or a correlation waiver.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-25 | initial source-backed failed-release-break card | Q01 | PASS |
| v1 | 2026-07-25 | paced baseline handoff; no backtest launched | Q02 | QUEUED_FACTORY_OFF |

## Pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-25 | APPROVED | this card |
| Q01 Build Validation | 2026-07-25 | PASS | `D:/QM/reports/framework/21/build_check_20260724_233226.json` |
| Q02 Baseline Screening | 2026-07-25 | QUEUED_FACTORY_OFF | work item `7120d80d-a807-4353-901a-6cde7013a88f` |
