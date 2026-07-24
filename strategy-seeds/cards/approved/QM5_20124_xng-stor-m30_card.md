---
ea_id: QM5_20124
slug: xng-stor-m30
type: strategy
strategy_id: EIA-XNG-STORAGE-INTRADAY-2026_S01
source_id: EIA-XNG-STORAGE-AFTERSHOCK-2026
status: APPROVED
g0_status: APPROVED
created: 2026-07-25
created_by: Research+Development
last_updated: 2026-07-25
source_authors: "U.S. Energy Information Administration"
strategy_mechanic: standard-thursday-eia-xng-m30-release-impulse-continuation
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
  - "[[concepts/information-event-continuation]]"
  - "[[concepts/energy-event-risk]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [scheduled-event, intraday-momentum, structural, same-session-exit, low-frequency, long-short, atr-hard-stop]
markets: [commodities, energy, natural_gas]
timeframes: [M30]
period: M30
primary_target_symbols: [XNGUSD.DWX]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_20124_XNG_STORAGE_M30
expected_trade_frequency: "At most one consumed standard-Thursday decision per week; release-range/body/breakout filters estimate 8-30 entries/year before spread, risk, and execution gates."
expected_trades_per_year_per_symbol: 10
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: QUEUED
review_focus: "Falsify whether post-release XNG impulse continuation survives CFD spread/slippage, missing holiday releases, DST conversion, event whipsaw, gas gaps, and same-session time exits."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode_dual, magic_schema, one_position_per_magic_symbol, restart_safe_attempt, event_clock_dst, same_session_flat, source_claim_boundary, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission authorizes one new structural low-frequency card/build: R1 PASS official U.S. EIA WNGSR and release schedule; R2 PASS fixed standard-Thursday New York clock, completed release bar, prior-range breakout, body/range/ATR thresholds, consumed attempt, ATR stop, and same-session exit; R3 PASS registered XNGUSD.DWX M30 route; R4 PASS deterministic OHLC/calendar/ATR arithmetic only with no ML, banned indicator, external runtime feed, grid, or martingale. Deterministic dedup returned CLEAN and the manual storage-family audit found no M30 post-release continuation duplicate."
---

# EIA XNG Storage-Release M30 Impulse Continuation

## Hypothesis

The EIA Weekly Natural Gas Storage Report creates a scheduled, commodity-
specific information clock. This card tests whether an unusually directional
XNGUSD.DWX release bar that closes beyond the preceding one-hour range retains
enough order-flow persistence to continue after the bar is complete.

The strategy does not predict the storage number and does not enter before or
during the release bar. It waits for the 10:30-11:00 New York M30 bar to close,
trades only a source-timed price impulse, and exits in the same New York
session. This is a Q02 falsification candidate, not a performance or
decorrelation claim.

## Source and interpretation boundary

The durable lineage packet is
`strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/source.md`. The official
EIA natural-gas data page identifies the WNGSR as a regular Thursday 10:30 a.m.
eastern-time release. The official WNGSR schedule states that holiday weeks can
use alternate days or times.

Version 1 trades only the standard Thursday 10:30 release. It intentionally
skips holiday-shifted weeks rather than guessing without an external schedule.
At runtime it reads no EIA report, storage level, survey, forecast, surprise,
calendar file, API, futures chain, or external market data.

EIA supports the event identity and clock only. EIA does not claim that the
release-bar direction continues, that these filters are profitable, or that a
Darwinex natural-gas CFD replicates Henry Hub futures. The continuation rule,
thresholds, ATR stop, and time exit are explicit QM hypotheses to falsify.

## Non-duplicate decision

The deterministic check for slug `xng-stor-m30`, strategy ID
`EIA-XNG-STORAGE-INTRADAY-2026_S01`, and the full mechanic returned `CLEAN`
across 4,181 registry rows and 374 cards.

Manual review also separates this card from the closest systems:

- `QM5_12584_eia-xng-storage` is a D1 post-event aftershock using the completed
  daily range/body and a slow trend filter, then holds for days.
- `QM5_12744_xng-storage-fade` fades a completed D1 event-day exhaustion move.
- `QM5_12761_xng-stor-inside` waits for a later D1 inside-day breakout.
- `QM5_12725_xng-prestor-trend` is a D1 pre-storage compression/trend setup.
- `QM5_13110_xng-svol-brk` is an H4 seasonal-volatility-window breakout, not a
  release-clock strategy.
- `QM5_12567_cum-rsi2-commodity` is daily RSI pullback logic.
- `QM5_1121_unger-crude-inventory-release` and
  `QM5_10319_eia-oil-momo` trade the petroleum report on XTIUSD.DWX with
  different clocks and order mechanics.

No existing XNG storage EA owns the completed 10:30-11:00 New York M30
impulse, prior-hour range break, and same-session lifecycle.

## Markets, timeframe, and cadence

- Host: exact `XNGUSD.DWX`, M30, magic slot 0, magic `201240000`.
- Decision clock: first executable tick of the 11:00 New York M30 bar on a
  standard Thursday.
- Maximum cadence: one consumed attempt per eligible Thursday.
- Expected entries: approximately 8-30 per year before downstream gates.
- Normal hold: 11:00 to no later than 15:55 New York on the same day.
- Q02 risk: exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Rules

The rules below are the complete authorized v1 baseline. Changing the event
day/time, bar windows, thresholds, direction mapping, stop, or exit creates a
new card.

## 4. Entry Rules

1. Require exact `XNGUSD.DWX`, M30, magic slot 0, and every locked strategy
   input.
2. Convert broker bars to New York time using the V5 Darwinex/US-DST helpers.
3. Evaluate only when the current M30 bar opens at 11:00 New York on Thursday.
   Before history, signal, news, spread, ATR, price, or order checks, persist
   that New York date as consumed. A terminal-global marker plus position/deal
   history prevents a same-day retry after restart, rejection, stop, or block.
4. Require the first observed tick to be within
   `strategy_entry_grace_minutes=15` of the 11:00 bar open. Late attachment
   consumes the day and remains flat.
5. Require exact same-date M30 bars beginning 09:30, 10:00, and 10:30 New York.
   The first two bars define the pre-release high and low; the 10:30 bar is the
   completed release bar.
6. Compute ATR(20) on the completed 10:30 release bar. Require release-bar
   range at least `0.75 * ATR(20)` and body/range at least `0.50`.
7. BUY only when the release bar is bullish and closes strictly above the
   prior 60-minute high. SELL only when it is bearish and closes strictly
   below the prior 60-minute low. Otherwise remain flat.
8. Require no EA-owned open position and spread no greater than 2,500 points.
9. Enter at market with a broker hard stop `2.0 * ATR(20)` from executable
   price. No take-profit is authorized.

## 5. Exit Rules

1. Broker-side hard stop.
2. Close on the first tick at or after 15:55 New York on the entry date.
3. If the session close is missed, close on the first tick whose New York date
   differs from the entry date.
4. Close after eight elapsed hours as a final stale guard.
5. Framework Friday close and kill-switch closures remain authoritative.

News filtering may block new risk only. It may not delay the session, stale,
hard-stop, Friday, or kill-switch exits.

## 6. Filters (No-Trade Module)

- Fail closed for wrong symbol/timeframe/slot, unlocked inputs, non-Thursday
  clock, wrong bar timestamps, missing/invalid OHLC, invalid ATR/price/stop,
  release range/body below threshold, close inside the pre-release range,
  negative/excess spread, late attach, consumed date, or an open owned
  position.
- Q02 intentionally uses both news axes OFF because the storage release is the
  strategy event. No external calendar dependency is permitted.

## 7. Trade Management Rules

- One market position per magic/symbol and one consumed attempt per standard
  Thursday.
- No holiday-shift inference, retry, pending order, scale-in, partial close,
  trailing stop, break-even move, target, adaptive fit, grid, martingale,
  pyramid, random path, or external runtime feed.
- Lifecycle checks run every tick before entry-only news gates.

## Parameters to test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_release_hhmm_ny` | 1030 | [1030] | official standard WNGSR clock |
| `strategy_entry_hhmm_ny` | 1100 | [1100] | completed release-bar entry |
| `strategy_pre_release_bars` | 2 | [2] | 60-minute pre-release range |
| `strategy_min_release_range_atr` | 0.75 | [0.75] | event impulse floor |
| `strategy_min_body_ratio` | 0.50 | [0.50] | directional close filter |
| `strategy_atr_period` | 20 | [20] | completed release-bar risk estimator |
| `strategy_atr_sl_mult` | 2.0 | [2.0] | broker hard-stop distance |
| `strategy_entry_grace_minutes` | 15 | [15] | late-attach tolerance |
| `strategy_session_flat_hhmm_ny` | 1555 | [1555] | same-session exit |
| `strategy_max_hold_hours` | 8 | [8] | stale guard |
| `strategy_max_spread_points` | 2500 | [2500] | entry spread ceiling |

There is no baseline parameter sweep.

## Kill criteria

- Retire on zero trades, fewer than five completed trades/year on average,
  entry outside the standard Thursday release clock, entry before release-bar
  completion, wrong direction, close not beyond the prior range, duplicate
  same-day entry, overnight hold, nondeterminism, invalid risk mode, or any
  governed PF/DD failure.
- Treat holiday omissions, DST conversion, post-release whipsaw, CFD/futures
  basis, XNG spread and gap tails, stop slippage, and same-session truncation as
  first-order falsification risks.
- Do not rescue failure by reading an external surprise feed, adding holiday
  dates after inspection, entering during the release, lowering thresholds,
  extending overnight, or fitting direction by sample.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The frozen `2.0 * ATR(20)` stop is the only initial risk
distance. Natural-gas gap risk, release slippage, CFD spread, and abrupt
reversals make the carrier high risk. No live preset is authorized.

## Strategy allowability check

- [x] R1: official U.S. EIA report, natural-gas data page, and release schedule.
- [x] R2: fixed source clock, completed bars, deterministic range/body/ATR
  tests, direction, consumed attempt, hard stop, and exits.
- [x] R3: registered native `XNGUSD.DWX` M30 route.
- [x] R4: deterministic OHLC/calendar/ATR arithmetic; no ML, banned indicator,
  external signal, grid, or martingale.
- [x] Dedup: deterministic CLEAN plus manual storage-family differentiation.

## Framework alignment

- no_trade: exact host/timeframe/slot and locked-input guards.
- trade_entry: DST-aware Thursday bar validation, consumed-date persistence,
  prior-hour range and release-bar tests, spread cap, market direction, and ATR
  hard stop.
- trade_management: every-tick 15:55 New York and stale repair closure.
- trade_close: broker stop, framework Friday close/kill switch, and explicit
  same-session closure.

## Safety boundary

This approval covers the card, deterministic registries, EA build, strict
compile, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does
not authorize a live setfile, AutoTrading, `T_Live`, a deploy/T_Live manifest,
portfolio admission, a portfolio-gate change, portfolio KPIs, or a correlation
waiver.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-25 | source/card/build/strict compile complete; one paced Q02 row enqueued | Q02 | Q01 PASS; Q02 QUEUED_FACTORY_OFF |

## Pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-25 | APPROVED under OWNER mission; R1-R4 PASS | this card |
| Q01 Build Validation | 2026-07-25 | PASS; strict compile/build check zero errors and warnings | `docs/ops/evidence/2026-07-25_qm5_20124_xng_storage_m30_build_q02_enqueue.md` |
| Q02 Baseline Screening | 2026-07-25 | QUEUED_FACTORY_OFF; pending, attempts 0 | work item `6ecb71e5-84f6-41ac-b257-507f6aef38e0`; same evidence |
