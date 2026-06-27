---
ea_id: QM5_12726
slug: wti-nov-fade
type: strategy
source_id: ARENDAS-OIL-SEASON-2018
source_citation: "Arendas, P., Chovancova, B. and Balaz, V. Seasonal patterns in oil prices and their implications for investors. Journal of Investment Strategies. URL https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf"
sources:
  - "[[sources/ARENDAS-OIL-SEASON-2018]]"
concepts:
  - "[[concepts/crude-oil-month-of-year-seasonality]]"
  - "[[concepts/calendar-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "November-only D1 WTI month-of-year negative-return sleeve; estimate 18-22 entries/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS academic oil-seasonality paper; R2 PASS deterministic November D1 short/next-bar flat rule with ATR stop; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.08
expected_dd_pct: 16.0
---

# WTI November Calendar Fade

## Source

- Source: [[sources/ARENDAS-OIL-SEASON-2018]]
- Primary citation: Arendas, P., Chovancova, B. and Balaz, V., "Seasonal
  patterns in oil prices and their implications for investors", Journal of
  Investment Strategies, URL
  https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf.

## Concept

Academic crude-oil seasonality research reports a late-year negative
month-of-year cluster in crude-oil returns, with November included in that weak
seasonal window. This card isolates the November side as a low-frequency
XTIUSD.DWX sleeve: short only on broker-calendar November D1 bars and flatten on
the next D1 bar.

This is deliberately different from:

- `QM5_12701_wti-oct-fade`: October month-of-year fade from a separate Gorska
  card; this card isolates November and uses the Arendas source lineage.
- `QM5_12599_wti-feb-prem`: February long month-of-year premium, opposite month
  and direction.
- `QM5_12596_wti-mon-fade`, `QM5_12610_wti-tue-fade`, and
  `QM5_12597_wti-fri-prem`: weekday effects, not month-of-year November.
- `QM5_12576_eia-wti-season`: broad EIA refined-product demand seasonality with
  SMA/ROC confirmation; November is neutral there.
- `QM5_12579`, `QM5_12590`, and `QM5_12592`: not WPSR continuation, fade, or
  pre-event positioning.
- `QM5_12591`, `QM5_12593`, `QM5_12598`, and `QM5_12600`: not hurricane,
  refinery, OPEC, or expiry-window logic.
- `QM5_12603` and `QM5_12616`: not medium-term WTI time-series momentum.
- `QM5_12567_cum-rsi2-commodity`: no RSI or oscillator pullback logic.

## Markets And Timeframe

- Symbol: XTIUSD.DWX.
- Period: D1.
- Expected trade frequency: about 18-22 trades/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no futures curve,
  inventory feed, EIA feed, CFTC data, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar D1 bar must be in November.
- Entry direction is short only: SELL XTIUSD.DWX at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open XTIUSD.DWX position already exists for this EA magic.
- No entry if XTIUSD.DWX spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after entry.
- Close immediately if the current D1 bar is no longer in November.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade XTIUSD.DWX on D1.
- Skip entries when ATR is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Short-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_entry_month
  default: 11
  sweep_range: [11]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.25
  sweep_range: [1.5, 2.25, 3.0]
- name: strategy_max_hold_days
  default: 1
  sweep_range: [1, 2]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source is used for structural lineage around month-of-year seasonality in
crude-oil returns, including November weakness. No source performance number is
imported into QM; the Q02+ pipeline tests the rule on Darwinex XTIUSD.DWX bars.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 16
- expected_trade_frequency: approximately 18-22 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: academic crude-oil seasonality paper.
- [x] R2 mechanical: fixed broker-calendar month, single D1 short entry, ATR
  stop, and next-bar/month-end time exit.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: November month-of-year short is not the existing October
  fade, February premium, weekday, WTI event, WTI momentum/reversal, XNG,
  ratio-basket, or RSI commodity sleeve.

## Framework Alignment

- no_trade: D1 and XTIUSD.DWX guard, parameter guard, spread cap.
- trade_entry: November broker-calendar short entry.
- trade_management: first post-entry D1 bar, month-end, and max-hold
  stale-position exits.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural WTI November calendar-fade build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
