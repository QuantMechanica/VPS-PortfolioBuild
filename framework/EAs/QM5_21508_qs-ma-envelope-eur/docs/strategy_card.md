---
ea_id: QM5_21508
slug: qs-ma-envelope-eur
type: strategy
source_id: 0b564ef2-810c-5b1d-9084-342ddb20575c
sources:
  - "[[sources/quantifiedstrategies-moving-average-envelope]]"
concepts:
  - "[[concepts/moving-average-envelope]]"
  - "[[concepts/mean-reversion]]"
  - "[[concepts/percentage-band]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr-stop]]"
strategy_type_flags: [ma-envelope-meanrev, single-symbol, atr-hard-stop, both-direction, mid-frequency]
target_symbols: [EURUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_21508_EUR_MAENV_MR_D1
period: D1
expected_trade_frequency: "A fixed +/-percent band around a 20-period SMA is touched by EURUSD D1 closes on the order of 25-40 times/year; estimate 25 completed round-trips/year after the return-to-band exit."
expected_trades_per_year_per_symbol: 25
last_updated: 2026-08-14
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Anonymous-author-OK per 2026-06-30 revision; source is QuantifiedStrategies.com 'Moving Average Envelope - Strategy, Rules, Returns' (https://www.quantifiedstrategies.com/moving-average-envelope/), which documents the fixed-percentage-band-around-an-SMA construction (Upper = SMA*(1+pct), Lower = SMA*(1-pct)) and its use both for mean-reversion entries and as a stop-placement guide."
r2_mechanical: PASS
r2_reasoning: "Deterministic: SMA plus a fixed percentage offset defines upper/lower bands; entry triggers on a close beyond a band, exit on reversion back inside the SMA. No discretion. Exact tie/gap handling specified below."
r3_data_available: PASS
r3_reasoning: "Native EURUSD.DWX D1 close and SMA are sufficient; no external data, no volume."
r4_ml_forbidden: PASS
r4_reasoning: "No ML, no adaptive/PnL-dependent parameters; fixed percentage band computed only from price history. No grid/martingale."
pipeline_phase: G0
expected_pf: 1.15
expected_dd_pct: 18.0
risk_class: medium
ml_required: false
g0_approval_reasoning: "R1 lineage recorded to one QuantifiedStrategies article; R2 PASS fixed-percent SMA-envelope breach entries with mean, ATR, and time exits, and plausible approximately 25/year fresh-breach cadence; R3 PASS EURUSD.DWX D1 price-only; R4 PASS deterministic, ML-free, one-position, no grid/martingale."
---

# EURUSD Moving Average Envelope Mean-Reversion

## Source

- Source: [[sources/quantifiedstrategies-moving-average-envelope]]
- Citation: QuantifiedStrategies.com, "Moving Average Envelope - Strategy,
  Rules, Returns." https://www.quantifiedstrategies.com/moving-average-envelope/
- Key finding used here: the article defines the envelope as a fixed
  percentage deviation added to and subtracted from a simple moving
  average (e.g. `Upper = SMA_20 + SMA_20*0.05`, `Lower = SMA_20 -
  SMA_20*0.05`), and separately notes the bands are commonly used both as
  mean-reversion trade triggers and as a stop-placement guide (stop a few
  pips beyond the opposite band).

## Edge / Thesis

A fixed-percentage band around a short SMA defines a "stretched from
trend" threshold. Price closing outside the band is a larger deviation
from the recent average than typical daily noise; reversion back inside
the band captures the pullback. Unlike a Bollinger Band (standard
deviation, adaptive width) or a Donchian channel (extreme-price
envelope, no central tendency), this is a fixed-percentage-of-SMA band --
a structurally different width mechanic already distinguished from both
families elsewhere in the book.

This is a price-only implementation on a major FX pair, which the source
generalizes to (the article frames the construction as instrument-agnostic).

## Markets And Timeframe

- Target symbol: `EURUSD.DWX` only.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: native MT5 D1 OHLC on EURUSD only; no external feed.

## Entry Rules

- Evaluate only on a new completed D1 bar.
- Compute `SMA(strategy_ma_period, D1)` on completed closes.
- `Upper = SMA[1] * (1 + strategy_envelope_pct)`.
- `Lower = SMA[1] * (1 - strategy_envelope_pct)`.
- Open LONG when `Close[1] < Lower` (close beyond the lower band) AND no
  long position is already open.
- Open SHORT when `Close[1] > Upper` (close beyond the upper band) AND no
  short position is already open.
- Exact band touch without breach (`Close[1] == Upper` or `== Lower`): no
  entry this bar.
- No entry if EURUSD spread exceeds `strategy_max_spread_points`.
- No entry if fewer than `strategy_ma_period + 5` completed D1 bars of
  history are available.

## Exit Rules

- Reversion exit: close LONG when `Close[1] >= SMA[1]` (price has reverted
  back to or above the average); close SHORT when `Close[1] <= SMA[1]`.
- Stop loss: fixed hard SL at `strategy_atr_sl_mult` x `ATR(strategy_atr_period,
  D1)` from entry (source's "stop beyond the opposite band" guidance is
  implemented as a bounded ATR distance rather than an unbounded
  opposite-band stop, to keep worst-case loss deterministic).
- Max-hold exit: close after `strategy_max_hold_bars` completed D1 bars
  (default 20) as a stale-position guard.
- Friday close remains enabled by the V5 framework.
- No trailing stop, no take-profit, no partial close in v1.

## Filters

- Only trade `EURUSD.DWX` on D1.
- Framework news, kill-switch, magic, and Friday-close guards remain active.
- Spread cap via `strategy_max_spread_points`.

## Trade Management Rules

- Both long and short.
- One open position per magic.
- No pyramiding, gridding, martingale, or scale-in.
- No partial close.
- No re-entry in the same direction until price has reverted inside the
  band and produced a fresh breach (prevents re-entering on a single
  extended excursion beyond the band).

## Parameters To Test

- name: strategy_ma_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_envelope_pct
  default: 0.015
  sweep_range: [0.01, 0.015, 0.02, 0.03]
- name: strategy_atr_period
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_atr_sl_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5]
- name: strategy_max_hold_bars
  default: 20
  sweep_range: [10, 20, 30]
- name: strategy_max_spread_points
  default: 20
  sweep_range: [10, 20, 30]

## Dedup Assessment

| Card | Overlap? | Verdict |
|---|---|---|
| Any `bollinger*` card (9 in book) | Both are "band around a moving average" mean-reversion family | DIFFERENT WIDTH MECHANIC -- Bollinger width is a rolling standard deviation (adapts to volatility regime); this envelope width is a fixed percentage of the SMA (constant proportional width regardless of realized volatility) |
| Any `donchian*` / `turtle*` card (29 + 13 in book) | All are "price-envelope breakout/reversion" family | DIFFERENT CONSTRUCTION -- Donchian bands are the rolling highest-high/lowest-low (extreme price envelope, no central average); this envelope is a fixed-percent offset from a central SMA and trades reversion INTO the average, not breakout beyond an extreme |
| Book-wide keyword scan | `envelope` / `moving-average-envelope` | ZERO existing cards in the current ~3500-card book use this term (verified by full-book slug grep 2026-08-13) |

## Low-Correlation Argument

- Fixed-percentage-of-SMA band width is structurally distinct from every
  other band/channel mechanic already in the book (std-dev Bollinger,
  extreme-price Donchian/turtle, ATR-multiple channels).
- Mean-reversion role (fade the breach, exit at the average) rather than
  breakout/trend role, on a major FX pair chosen for its typically
  range-bound multi-week character.

## Net-Cost Check

EURUSD commission/spread is the lowest-cost pair in the DWX universe.
~25 trades/year with short average holds (bounded by 20-bar max hold and
the reversion-to-SMA exit) keeps turnover manageable; gross should
closely approximate net given the tight spread.

## Initial Risk Profile

- expected_pf: 1.15
- expected_dd_pct: 18.0
- expected_trade_frequency: approximately 25-40 band touches/year, ~25
  completed round-trips/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Framework Alignment

- no_trade: D1 EURUSD.DWX guard, history-length guard, spread cap.
- trade_entry: fixed-percent SMA envelope breach.
- trade_management: ATR hard stop, 20-bar max-hold time stop.
- trade_close: reversion-to-SMA exit, ATR stop, time stop, framework Friday
  close.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-13 | PENDING | this card |
