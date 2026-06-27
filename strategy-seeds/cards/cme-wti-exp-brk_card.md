---
ea_id: QM5_12600
slug: cme-wti-exp-brk
type: strategy
source_id: CME-WTI-EXPIRY-BRK-2026
source_citation: "CME Group. Chapter 200 Light Sweet Crude Oil Futures. URL https://www.cmegroup.com/rulebook/NYMEX/2/200.pdf; CME Group. Understanding Futures Expiration & Contract Roll. URL https://www.cmegroup.com/education/courses/introduction-to-futures/understanding-futures-expiration-contract-roll"
sources:
  - "[[sources/CME-WTI-EXPIRY-BRK-2026]]"
concepts:
  - "[[concepts/wti-futures-expiration]]"
  - "[[concepts/contract-roll-window]]"
  - "[[concepts/channel-breakout]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, channel-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Monthly WTI futures expiry/roll-window D1 breakout; estimate 5-12 trades/year after channel, trend, range, and spread filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS CME rulebook/education source packet; R2 PASS deterministic monthly expiry-window D1 breakout rules; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.12
expected_dd_pct: 18.0
---

# CME WTI Expiry/Roll Breakout

## Source

- Source: [[sources/CME-WTI-EXPIRY-BRK-2026]]
- Primary citation: CME Group, "Chapter 200 Light Sweet Crude Oil Futures",
  URL https://www.cmegroup.com/rulebook/NYMEX/2/200.pdf.
- Supplement: CME Group, "Understanding Futures Expiration & Contract Roll",
  URL https://www.cmegroup.com/education/courses/introduction-to-futures/understanding-futures-expiration-contract-roll.
- Supplement: CME Group, "Crude Oil Futures Contract Specs",
  URL https://www.cmegroup.com/markets/energy/crude-oil/light-sweet-crude.contractSpecs.html.

## Concept

WTI crude futures have a recurring monthly front-contract termination and roll
cycle. Futures holders must offset, roll, or settle positions before the
front-month contract expires, so liquidity and hedging pressure can cluster
around a narrow calendar window. This card does not forecast inventory or OPEC
news; it waits for `XTIUSD.DWX` itself to confirm a D1 breakout during the
approximated CME WTI expiry/roll window.

This is deliberately different from:

- `QM5_12596_wti-mon-fade`, `QM5_12597_wti-fri-prem`, and
  `QM5_12599_wti-feb-prem`: this is not a weekday or month-of-year average-return
  calendar premium.
- `QM5_12576`, `QM5_12579`, `QM5_12590`, and `QM5_12592`: this is not broad EIA
  seasonality, WPSR fade, pre-WPSR positioning, or post-WPSR aftershock logic.
- `QM5_12591`, `QM5_12593`, and `QM5_12598`: this is not hurricane, refinery, or
  OPEC event-window logic.
- `QM5_12594_yang-wti-reversal`: this follows breakouts inside a monthly roll
  window instead of fading medium-term return extremes.
- `QM5_12563_donchian-turtle-trend-commodity`: this is event-window gated and
  trades only the WTI roll/expiry window, not a continuous commodity trend
  basket.
- `QM5_12567_cum-rsi2-commodity`: no RSI or oscillator pullback logic.

## Markets And Timeframe

- Symbol: XTIUSD.DWX.
- Period: D1.
- Expected trade frequency: about 5-12 trades/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no CME feed,
  futures curve, open interest, volume, inventory feed, CSV, API, analyst
  forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Approximate the monthly CME WTI futures termination date as the third business
  day before the 25th calendar day; if the 25th is a weekend, use the prior
  business day as the anchor. Weekends are handled; exchange holidays are not
  imported.
- The prior closed D1 bar must be inside
  `strategy_expiry_pre_days` before through `strategy_expiry_post_days` after
  that approximated expiry day.
- Compute the prior closed D1 close, SMA(`strategy_trend_period`),
  ATR(`strategy_atr_period`), prior `strategy_entry_channel` high/low, and
  signal-bar close location.
- Entry Long: prior close breaks above the previous channel high, closes above
  SMA, has range at least `strategy_min_range_atr * ATR`, and closes in the
  top `strategy_min_close_location` fraction of the D1 range.
- Entry Short: prior close breaks below the previous channel low, closes below
  SMA, has the same range filter, and closes in the bottom range fraction.
- No entry if an open XTIUSD.DWX position already exists for this EA magic.
- No entry if XTIUSD.DWX spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit Long if the prior close falls below the previous
  `strategy_exit_channel` low or below SMA.
- Exit Short if the prior close rises above the previous
  `strategy_exit_channel` high or above SMA.
- Exit any position after the expiry/roll window ends.
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade XTIUSD.DWX on D1.
- Skip entries when SMA, ATR, channel, or range values are unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_entry_channel
  default: 12
  sweep_range: [8, 12, 16, 20]
- name: strategy_exit_channel
  default: 6
  sweep_range: [4, 6, 10]
- name: strategy_trend_period
  default: 50
  sweep_range: [34, 50, 84]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 0.75
  sweep_range: [0.60, 0.75, 1.00]
- name: strategy_min_close_location
  default: 0.65
  sweep_range: [0.60, 0.65, 0.75]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.25, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 6
  sweep_range: [4, 6, 9]
- name: strategy_expiry_pre_days
  default: 3
  sweep_range: [2, 3, 5]
- name: strategy_expiry_post_days
  default: 2
  sweep_range: [1, 2, 3]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is imported from CME. The sources are used only for
structural lineage: WTI is a listed futures market with a recurring expiration
and roll process that can force position management before settlement.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 18
- expected_trade_frequency: approximately 5-12 trades/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: CME exchange rulebook and CME education material.
- [x] R2 mechanical: fixed calendar approximation, D1 channel/SMA breakout,
  ATR stop, window exit, and max-hold exit.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: monthly futures-expiry/roll breakout is not the existing
  WTI weekday, month-of-year, WPSR, hurricane, refinery, OPEC, reversal,
  broad-trend, ratio, or RSI commodity sleeve.

## Framework Alignment

- no_trade: D1 and XTIUSD.DWX guard, parameter guard, spread cap, expiry-window
  calendar gate.
- trade_entry: monthly WTI expiry/roll-window D1 channel breakout with SMA,
  range, and close-location confirmation.
- trade_management: expiry-window end, failed-breakout exit, SMA failure exit,
  and max-hold stale-position exit.
- trade_close: hard ATR stop plus deterministic close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural WTI expiry/roll-window breakout build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
