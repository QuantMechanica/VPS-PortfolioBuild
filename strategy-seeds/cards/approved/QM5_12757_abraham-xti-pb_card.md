---
ea_id: QM5_12757
slug: abraham-xti-pb
type: strategy
strategy_id: ABRAHAM_TREND_BIBLE_RETRACEMENT_XTI_D1
source_id: ABRAHAM-TREND-BIBLE-2012
source_citation: "Abraham, Andrew. The Trend Following Bible: How Professional Traders Compound Wealth and Manage Risk. John Wiley & Sons, 2013, Chapters 6-7."
sources:
  - "[[sources/ABRAHAM-TREND-BIBLE-2012]]"
concepts:
  - "[[concepts/channel-breakout]]"
  - "[[concepts/retracement-entry]]"
  - "[[concepts/time-series-momentum]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/macd-zero-line]]"
  - "[[indicators/atr]]"
strategy_type_flags: [channel-breakout, retracement-entry, macd-zero-filter, atr-trailing-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Breakout must occur first, then the next D1 bars must pull back to the old 20-day channel boundary while the MACD zero filter remains aligned."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS single Wiley practitioner source; R2 PASS deterministic D1 20-day channel breakout, MACD(12,26,9) zero-line filter, pullback confirmation, 10-day structural hard stop, ATR(39) trail, and stale-position guard; R3 PASS XTIUSD.DWX is testable as the DWX WTI CFD proxy; R4 PASS no ML, grid, martingale, external data, or multiple-position mechanic."
expected_pf: 1.08
expected_dd_pct: 22.0
---

# Abraham WTI Breakout Pullback

## Source

- Source: [[sources/ABRAHAM-TREND-BIBLE-2012]]
- Primary citation: Abraham, Andrew. *The Trend Following Bible: How
  Professional Traders Compound Wealth and Manage Risk*. John Wiley & Sons,
  2013, Chapters 6-7.
- Repo evidence: `docs/research/LIBRARY_MINING_trend-bible-2012_2026-06.md`
  documents the dedup review, source quality, and mechanical extraction.

## Concept

This card ports Abraham's retracement-entry variant to `XTIUSD.DWX` as a
structural WTI sleeve. The strategy first requires a D1 close beyond the prior
20-day channel with MACD aligned above/below zero. It then waits for price to
pull back to the old breakout boundary before entering in the breakout
direction.

This is deliberately different from:

- `QM5_12563_donchian-turtle-trend-commodity`: this card does not enter on the
  breakout close and adds the Abraham MACD-zero filter plus post-breakout
  pullback confirmation.
- `QM5_12603_wti-tsmom12m`, `QM5_12616_tsmom-9m-commodity-xtiusd`,
  `QM5_12708_commodity-tsmom-6m`, and `QM5_12711_commodity-tsmom-dual-6-12`:
  this is not a monthly return-sign package.
- WTI event/calendar sleeves: no weekday, month, expiry, EIA, SPR, hurricane,
  driving-season, roll-window, or post-roll trigger.
- `QM5_12567` XNG logic: no cumulative RSI or natural-gas signal is used.
- Gold/silver ratio sleeves: the exposure is WTI crude, not metals relative
  value.

## Markets And Timeframe

- Symbol: XTIUSD.DWX.
- Period: D1.
- Expected trade frequency: about 4-8 entries/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 D1 OHLC plus framework MACD and ATR readers only.
  No futures curve, inventory feed, EIA feed, CFTC data, CSV, API, analyst
  forecast, or ML model is used.

## Entry Rules

- Evaluate only on a new completed D1 bar.
- Compute the previous 20-bar channel excluding the most recently closed bar.
- Long setup: the most recently closed D1 bar closes above that prior 20-day
  high and MACD(12,26,9) main is above zero.
- Short setup: the most recently closed D1 bar closes below that prior 20-day
  low and MACD(12,26,9) main is below zero.
- Do not enter on the setup bar.
- Long entry: after a long setup, enter when a later closed D1 bar trades down
  to the stored breakout boundary and closes back at or above it while MACD is
  still above zero.
- Short entry: after a short setup, enter when a later closed D1 bar trades up
  to the stored breakout boundary and closes back at or below it while MACD is
  still below zero.
- No entry if an open XTIUSD.DWX position already exists for this EA magic.
- No entry if the XTIUSD.DWX spread exceeds `strategy_max_spread_points`.
- Expire a setup after `strategy_setup_max_days` calendar days.

## Exit Rules

- Initial hard stop: 10-day structural low for longs and 10-day structural high
  for shorts at entry time.
- ATR trail: once price moves at least `strategy_trail_activation_atr` times
  ATR(39) in favor, trail the stop with ATR(39) x
  `strategy_atr_trail_mult`.
- Exit any stale position after `strategy_max_hold_days` calendar days.
- No fixed take profit.
- Friday close remains enabled by the V5 framework.

## Parameters To Test

- name: strategy_channel_period
  default: 20
  sweep_range: [15, 20, 25, 55]
- name: strategy_stop_period
  default: 10
  sweep_range: [8, 10, 15]
- name: strategy_setup_max_days
  default: 15
  sweep_range: [8, 15, 25]
- name: strategy_atr_period
  default: 39
  sweep_range: [20, 39, 55]
- name: strategy_atr_trail_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 45
  sweep_range: [25, 45, 70]

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 22.0.
- expected_trade_frequency: about 4-8 entries/year/symbol.
- risk_class: medium-high because crude-oil gaps and reversals can be sharp.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- R1: PASS, single source ID `ABRAHAM-TREND-BIBLE-2012`.
- R2: PASS, entry and exit are deterministic closed-D1 OHLC/indicator rules.
- R3: PASS, `XTIUSD.DWX` is available as the DWX crude-oil CFD proxy.
- R4: PASS, no ML, randomization, martingale, grid, external data, or multiple
  positions per magic number.

## Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-06-28 | initial build | Q02 queued | IN_PROGRESS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
| P1 Build Validation | 2026-06-28 | PASS | `framework/EAs/QM5_12757_abraham-xti-pb/` |
| Q02 Baseline Screening | TBD | QUEUED | farm work item |
