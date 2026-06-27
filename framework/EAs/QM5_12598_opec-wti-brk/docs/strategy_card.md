---
ea_id: QM5_12598
slug: opec-wti-brk
type: strategy
source_id: OPEC-WTI-CONF-BRK-2026
source_citation: "OPEC. OPEC holds 181st Meeting of the Conference. URL https://www.opec.org/pn-detail/86-15-june-2021.html; U.S. Energy Information Administration. Oil supply and OPEC. URL https://www.eia.gov/finance/markets/crudeoil/supply-opec.php"
sources:
  - "[[sources/OPEC-WTI-CONF-BRK-2026]]"
concepts:
  - "[[concepts/opec-policy-risk-window]]"
  - "[[concepts/energy-supply-breakout]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [donchian-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, news-blackout]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "D1 WTI OPEC ordinary-meeting risk-window breakout; estimate 3-8 trades/year across June/December windows after channel and trend filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS official OPEC/EIA source packet; R2 PASS deterministic June/December D1 breakout rules; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.12
expected_dd_pct: 18.0
---

# OPEC WTI Conference Breakout

## Source

- Source: [[sources/OPEC-WTI-CONF-BRK-2026]]
- Primary citation: OPEC, "OPEC holds 181st Meeting of the Conference", URL
  https://www.opec.org/pn-detail/86-15-june-2021.html.
- Supplement: U.S. Energy Information Administration, "Oil supply and OPEC",
  URL https://www.eia.gov/finance/markets/crudeoil/supply-opec.php.

## Concept

OPEC ordinary-meeting windows are recurring crude-oil supply-policy risk
windows. This card does not forecast the decision and does not read OPEC or EIA
data at runtime. It trades the WTI market's own D1 resolution: inside fixed
June/December meeting-risk windows, follow a strong channel breakout in the
direction confirmed by the slow trend, then exit quickly if the breakout fails
or the window ends.

This is deliberately different from:

- `QM5_12576_eia-wti-season`: broad petroleum-demand monthly seasonality.
- `QM5_12579`, `QM5_12590`, and `QM5_12592`: weekly WPSR event reaction,
  fade, and pre-event positioning.
- `QM5_12591`: hurricane-season supply-risk breakout, not OPEC policy timing.
- `QM5_12593`: refinery-turnaround shoulder-month mean reversion.
- `QM5_12596` and `QM5_12597`: day-of-week calendar effects.
- `QM5_12567_cum-rsi2-commodity`: short-horizon oscillator pullback logic.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 3-8 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no OPEC feed, EIA
  feed, inventory feed, futures curve, news API, CSV, analyst forecast, or ML
  model.

## Entry Rules

- Evaluate only on a new D1 bar.
- The prior closed D1 bar must fall inside the OPEC risk window:
  `strategy_event_month_a` or `strategy_event_month_b`, with day-of-month
  between `strategy_window_start_day` and `strategy_window_end_day`.
- Compute prior closed D1 OHLC, ATR(`strategy_atr_period`),
  SMA(`strategy_trend_period`), and prior-channel highs/lows.
- Prior-bar range must be at least `strategy_min_range_atr` times ATR.
- Long breakout: prior close is above the highest high of the previous
  `strategy_entry_channel` completed bars, above SMA, and closes in the upper
  `strategy_min_close_location` of its D1 range.
- Short breakout: prior close is below the lowest low of the previous
  `strategy_entry_channel` completed bars, below SMA, and closes in the lower
  `strategy_min_close_location` complement of its D1 range.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit if the current broker-calendar date leaves the OPEC risk window.
- Exit long if the prior D1 close breaks below the lowest low of the previous
  `strategy_exit_channel` completed bars or below SMA.
- Exit short if the prior D1 close breaks above the highest high of the previous
  `strategy_exit_channel` completed bars or above SMA.
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Skip entries when ATR, SMA, or channel state is unavailable.
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
  default: 10
  sweep_range: [8, 10, 14, 20]
- name: strategy_exit_channel
  default: 5
  sweep_range: [4, 5, 8, 10]
- name: strategy_trend_period
  default: 50
  sweep_range: [34, 50, 84]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_range_atr
  default: 0.70
  sweep_range: [0.50, 0.70, 0.90, 1.10]
- name: strategy_min_close_location
  default: 0.65
  sweep_range: [0.60, 0.65, 0.75]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 8
  sweep_range: [5, 8, 12]
- name: strategy_event_month_a
  default: 6
  sweep_range: [6]
- name: strategy_event_month_b
  default: 12
  sweep_range: [12]
- name: strategy_window_start_day
  default: 1
  sweep_range: [1]
- name: strategy_window_end_day
  default: 14
  sweep_range: [10, 14, 18]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is taken from OPEC or EIA. The sources are used only for
structural lineage around recurring OPEC policy-risk timing and the crude-oil
supply role of OPEC. The Q02+ pipeline tests the mechanical rule on Darwinex
`XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 18
- expected_trade_frequency: approximately 3-8 trades/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: OPEC and EIA official source packet.
- [x] R2 mechanical: fixed June/December calendar windows, D1 channel breakout,
  SMA trend filter, ATR stop, and deterministic exits.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: OPEC meeting-risk windows use different timing and entry
  logic than existing WTI seasonality, WPSR, hurricane, refinery, weekday, and
  return-reversal sleeves.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, parameter guard, spread cap.
- trade_entry: June/December OPEC-window D1 breakout with SMA/range/close
  location confirmation.
- trade_management: window end, failed breakout, SMA failure, and max-hold exits.
- trade_close: framework Friday close and strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural OPEC WTI policy-window breakout build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
