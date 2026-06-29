---
ea_id: QM5_12773
slug: opec-wti-fade
type: strategy
source_id: OPEC-WTI-POSTFADE-2026
source_citation: "OPEC. OPEC holds 181st Meeting of the Conference. URL https://www.opec.org/pn-detail/86-15-june-2021.html; U.S. Energy Information Administration. Oil supply and OPEC. URL https://www.eia.gov/finance/markets/crudeoil/supply-opec.php"
sources:
  - "[[sources/OPEC-WTI-POSTFADE-2026]]"
concepts:
  - "[[concepts/opec-policy-risk-window]]"
  - "[[concepts/post-event-impulse-fade]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [policy-risk-window, post-event-fade, mean-reversion, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "D1 WTI post-OPEC impulse-fade sleeve; estimate 4-10 trades/year across June/December windows after event-impulse, stretch, spread, and framework filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS official OPEC/EIA source packet; R2 PASS deterministic post-OPEC D1 impulse-fade rules with SMA/ATR/time exits; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 18.0
---

# OPEC WTI Post-Window Impulse Fade

## Source

- Source: [[sources/OPEC-WTI-POSTFADE-2026]]
- Primary citation: OPEC, "OPEC holds 181st Meeting of the Conference", URL
  https://www.opec.org/pn-detail/86-15-june-2021.html.
- Supplement: U.S. Energy Information Administration, "Oil supply and OPEC",
  URL https://www.eia.gov/finance/markets/crudeoil/supply-opec.php.

## Concept

OPEC ordinary-meeting windows are recurring crude-oil supply-policy risk
windows. This card does not forecast the policy decision and does not read OPEC
or EIA data at runtime. It uses the official source only to define the June and
December policy-risk windows, then trades the WTI market's own post-window
resolution.

The rule waits for a visible event-window impulse during days 1-14 of June or
December. After the risk window, during days 15-24, it fades same-direction
follow-through only when the prior D1 close is stretched away from a slow SMA
by an ATR-normalized distance. The thesis is structural post-event digestion:
policy-window shocks can overshoot, and late continuation after the official
window is tested as a mean-reversion entry.

## Hypothesis

OPEC ordinary-meeting windows can produce D1 WTI impulses that continue briefly
after the policy-risk window has passed. When that late continuation leaves
price stretched away from a slow D1 mean, a bounded fade may capture post-event
digestion without forecasting the OPEC decision itself.

## Rules

- Trade only `XTIUSD.DWX` on D1.
- Use only broker calendar, D1 OHLC, SMA, ATR, and framework filters.
- Detect the largest qualifying June/December event-window impulse during days
  1-14.
- During days 15-24, fade same-direction continuation only when the prior
  closed bar is ATR-stretched away from SMA(`strategy_trend_period`).
- Exit on SMA mean reversion, fade-window end, max-hold expiry, Friday close,
  or ATR hard stop.

## Risk

Backtests use `RISK_FIXED=1000` with `RISK_PERCENT=0`. The strategy opens at
most one `XTIUSD.DWX` position per magic, never grids, never martingales, never
uses ML, and does not read external OPEC/EIA/news/futures data at runtime.

This is deliberately different from:

- `QM5_12598_opec-wti-brk`: event-window Donchian breakout continuation during
  days 1-14. This card trades only after that window and takes the opposite
  side of stretched continuation.
- `QM5_12576_eia-wti-season`: broad petroleum-demand monthly seasonality.
- `QM5_12579`, `QM5_12590`, `QM5_12592`, and `QM5_12752`: weekly WPSR
  aftershock/fade/pre-event/inside-day logic, not OPEC post-window fade.
- `QM5_12591`, `QM5_12593`, `QM5_12754`, and `QM5_12755`: hurricane, refinery,
  hurricane fade, and SPR policy-zone sleeves, not OPEC ordinary-meeting
  digestion.
- `QM5_12596`, `QM5_12597`, `QM5_12610`, `QM5_12599`, `QM5_12701`,
  `QM5_12726`, `QM5_12727`, `QM5_12729`, `QM5_12730`, `QM5_12734`,
  `QM5_12750`, `QM5_12753`, ETF-roll, CME-expiry, CAD/oil, XTI/XNG, XAU/XAG,
  XNG, and RSI commodity sleeves.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: approximately 4-10 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no OPEC feed, EIA
  feed, inventory feed, futures curve, news API, CSV, analyst forecast, or ML
  model.

## Entry Rules

- Evaluate only on a new D1 bar.
- The current broker-calendar D1 bar must be in the post-OPEC fade window:
  `strategy_event_month_a` or `strategy_event_month_b`, with day-of-month
  between `strategy_fade_start_day` and `strategy_fade_end_day`.
- Scan completed D1 bars in the same month and inside the event window
  `strategy_window_start_day` through `strategy_window_end_day`.
- Event impulse proof requires a completed event-window bar with:
  - absolute close-to-close return at least `strategy_min_event_return_pct`;
  - high-low range at least `strategy_min_event_range_atr` times ATR;
  - close location in the upper/lower part of the bar in the impulse
    direction.
- The impulse direction is the largest qualifying absolute return in the
  event window.
- Fade short: if the event impulse was up, the prior completed D1 return is at
  least `strategy_min_follow_return_pct`, prior close is above
  SMA(`strategy_trend_period`), and prior close is at least
  `strategy_min_stretch_atr` ATR above that SMA, SELL `XTIUSD.DWX`.
- Fade long: if the event impulse was down, the prior completed D1 return is
  less than or equal to `-strategy_min_follow_return_pct`, prior close is below
  SMA(`strategy_trend_period`), and prior close is at least
  `strategy_min_stretch_atr` ATR below that SMA, BUY `XTIUSD.DWX`.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Exit a short when the prior completed D1 close is at or below
  SMA(`strategy_trend_period`).
- Exit a long when the prior completed D1 close is at or above
  SMA(`strategy_trend_period`).
- Exit if the current broker-calendar date leaves the fade window.
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip entries when ATR, SMA, or D1 OHLC state is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short fade.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

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
- name: strategy_fade_start_day
  default: 15
  sweep_range: [12, 15, 18]
- name: strategy_fade_end_day
  default: 24
  sweep_range: [21, 24, 27]
- name: strategy_trend_period
  default: 50
  sweep_range: [34, 50, 84]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_event_return_pct
  default: 1.00
  sweep_range: [0.75, 1.00, 1.50]
- name: strategy_min_event_range_atr
  default: 0.80
  sweep_range: [0.60, 0.80, 1.00]
- name: strategy_min_follow_return_pct
  default: 0.35
  sweep_range: [0.20, 0.35, 0.60]
- name: strategy_min_close_location
  default: 0.65
  sweep_range: [0.60, 0.65, 0.75]
- name: strategy_min_stretch_atr
  default: 0.65
  sweep_range: [0.45, 0.65, 0.90]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.0, 2.75, 3.5]
- name: strategy_max_hold_days
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is taken from OPEC or EIA. The sources are used only for
structural lineage around recurring OPEC policy-risk timing and the crude-oil
supply role of OPEC. The Q02+ pipeline tests the mechanical rule on Darwinex
`XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 18
- expected_trade_frequency: approximately 4-10 trades/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: OPEC and EIA official source packet.
- [x] R2 mechanical: fixed June/December event windows, fixed post-window fade
  window, deterministic event-impulse proof, ATR/SMA stretch entry, ATR stop,
  and deterministic exits.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no external runtime data,
  no grid, no martingale, one position per magic.
- [x] Non-duplicate: post-window stretched-continuation fade is not the
  existing OPEC event-window breakout, WTI calendar/month/weekday, WPSR,
  hurricane, refinery, SPR, roll, expiry, CAD/oil, XTI/XNG, XAU/XAG, XNG, or
  RSI commodity logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, parameter guard, spread cap.
- trade_entry: June/December post-OPEC-window fade after event-window impulse
  proof and ATR/SMA stretch.
- trade_management: fade-window end, SMA mean reversion, and max-hold exits.
- trade_close: framework Friday close and strategy exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-29 | initial structural OPEC WTI post-window fade build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | this card |
