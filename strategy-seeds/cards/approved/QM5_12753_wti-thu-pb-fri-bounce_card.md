---
ea_id: QM5_12753
slug: wti-thu-pb-fri-bounce
type: strategy
source_id: MEEK-HOELSCHER-WTI-DOW-2023
source_citation: "Meek, H. and Hoelscher, S. A. Day-of-the-week effect: Petroleum and petroleum products. Cogent Economics and Finance 11(1), 2023. DOI https://doi.org/10.1080/23322039.2023.2213876; open pointer https://www.econstor.eu/handle/10419/304091"
sources:
  - "[[sources/MEEK-HOELSCHER-WTI-DOW-2023]]"
concepts:
  - "[[concepts/crude-oil-day-of-week-seasonality]]"
  - "[[concepts/thursday-pullback-friday-bounce]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, day-of-week, pullback-continuation, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Conditional Thursday-down to Friday WTI bounce on D1; estimate 10-25 trades/year after decline threshold, spread, broker-holiday, and framework filters."
expected_trades_per_year_per_symbol: 16
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS peer-reviewed petroleum DOW source; R2 PASS deterministic Thursday-drop/Friday-long/ATR-stop/time-exit rules; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 17.0
---

# WTI Thursday Pullback Friday Bounce

## Source

- Source: [[sources/MEEK-HOELSCHER-WTI-DOW-2023]]
- Primary citation: Meek, H. and Hoelscher, S. A., "Day-of-the-week effect: Petroleum and petroleum products", Cogent Economics and Finance, 11(1), 2023, DOI https://doi.org/10.1080/23322039.2023.2213876.
- Open repository pointer: https://www.econstor.eu/handle/10419/304091.

## hypothesis

The source studies day-of-week structure across petroleum markets and reports
WTI weekday seasonality. This card tests a narrower, conditional expression
rather than another unconditional weekday sleeve: buy the Friday D1 session
only when Thursday produced a significant close-to-close decline, then flatten
by the framework Friday close or by the next D1 bar.

The thesis is a structural oil calendar/pullback effect: Thursday weakness is
treated as the setup; Friday is the rebound window. Runtime data remains
Darwinex MT5 OHLC and broker calendar only. No futures curve, inventory feed,
EIA feed, CFTC data, CSV, API, analyst forecast, or ML model is used.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, cumulative oscillator, or SMA trend
  filter.
- `QM5_12596_wti-mon-fade` and `QM5_12610_wti-tue-fade`: those are
  unconditional short weekday fades.
- `QM5_12597_wti-fri-prem`: that buys the Friday bar unconditionally; this card
  requires a material Thursday pullback and therefore trades a different subset.
- `QM5_12750_wti-weekend-gap-fade`: not a Monday gap-fill strategy.
- Month-of-year, WPSR, hurricane, refinery, OPEC, expiry, roll, CAD,
  oil/gold, oil/silver, XTI/XNG, Donchian, and long-horizon momentum WTI
  sleeves already in the registry.

## Markets And Timeframe

- Target symbol: XTIUSD.DWX.
- Period: D1.
- Expected trade frequency: about 10-25 trades/year.
- Backtest risk mode: RISK_FIXED.

## rules

- Evaluate only on a new D1 bar.
- The current D1 bar must be broker-calendar Friday.
- The previous completed D1 bar must be broker-calendar Thursday.
- Compute Thursday close-to-close return as
  `(ThursdayClose / WednesdayClose - 1) * 100`.
- Entry direction is long only: BUY XTIUSD.DWX when the Thursday return is at
  or below `-strategy_min_thu_drop_pct`.
- Use ATR(`strategy_atr_period`) on completed D1 bars for the hard stop.
- No entry if an open XTIUSD.DWX position already exists for this EA magic.
- No entry if XTIUSD.DWX spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Framework Friday close remains enabled and is the primary same-session
  flattening path.
- If Friday close is disabled or missed, close the position on the first new D1
  bar whose broker-calendar day is not Friday.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.

## Filters

- Only trade XTIUSD.DWX on D1.
- Magic slot must be 0.
- Skip entries when ATR, D1 closes, or Thursday/Friday calendar state is
  unavailable.
- Standard framework news, kill-switch, magic, and Friday-close guards remain
  active.

## Trade Management Rules

- Long-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_min_thu_drop_pct
  default: 1.00
  sweep_range: [0.50, 0.75, 1.00, 1.25, 1.50]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.25
  sweep_range: [1.5, 2.25, 3.0]
- name: strategy_max_hold_days
  default: 2
  sweep_range: [1, 2]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source is used for structural lineage around petroleum day-of-week effects.
No source performance number is imported into QM. The edge must be earned by
Q02 and later evidence on Darwinex XTIUSD.DWX bars.

## risk

- expected_pf: 1.10
- expected_dd_pct: 17
- expected_trade_frequency: approximately 10-25 trades/year.
- risk_class: medium-high for crude-oil event and weekend risk.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: peer-reviewed petroleum DOW article with DOI and
  repository pointer.
- [x] R2 mechanical: fixed broker-calendar Thursday/Friday condition, fixed
  decline threshold, ATR stop, and time exit.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: conditional Thursday pullback into Friday long is not the
  existing unconditional Friday premium, Monday/Tuesday short, weekend-gap
  fade, month sleeve, WTI event sleeve, WTI trend/reversal, XNG, or commodity
  RSI logic.

## Framework Alignment

- no_trade: D1 and XTIUSD.DWX guard, slot guard, parameter guard, spread cap.
- trade_entry: Friday long after a Thursday close-to-close drop.
- trade_management: non-Friday stale exit and max-hold guard.
- trade_close: hard ATR stop plus deterministic time exits and framework
  Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-28 | initial structural WTI Thursday pullback/Friday bounce card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
