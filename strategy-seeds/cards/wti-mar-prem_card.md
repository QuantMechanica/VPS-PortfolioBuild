---
ea_id: QM5_12730
slug: wti-mar-prem
type: strategy
source_id: ARENDAS-OIL-SEASON-2018
source_citation: "Arendas, P., Tkacova, A. and Bukoven, M. Seasonal patterns in oil prices and their implications for investors. Journal of International Studies. URL https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf"
sources:
  - "[[sources/ARENDAS-OIL-SEASON-2018]]"
concepts:
  - "[[concepts/crude-oil-month-of-year-seasonality]]"
  - "[[concepts/calendar-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "March-only D1 WTI month-of-year positive-return sleeve; estimate 18-22 entries/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS academic oil-seasonality paper; R2 PASS deterministic March D1 long/time-flat rule with ATR stop; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.08
expected_dd_pct: 16.0
---

# WTI March Calendar Premium

## Source

- Source: [[sources/ARENDAS-OIL-SEASON-2018]]
- Primary citation: Arendas, P., Tkacova, A. and Bukoven, M., "Seasonal
  patterns in oil prices and their implications for investors", Journal of
  International Studies, URL
  https://www.jois.eu/files/12_547_Arendas%20et%20al.pdf.

## Concept

Academic crude-oil seasonality research reports positive average returns in
March, April, and August, and negative average returns in October and November.
This card isolates the unused March positive month as a clean QM book sleeve:
long-only exposure to `XTIUSD.DWX` during broker-calendar March D1 bars, with
each position flattened on the next D1 bar unless the ATR hard stop or framework
Friday close acts first.

## Hypothesis

WTI has documented month-of-year seasonality in the cited academic source. A
March-only long exposure should capture the positive spring seasonal component
without depending on inventories, futures curves, analyst forecasts, or any
runtime external data feed.

## Rules

- Trade only `XTIUSD.DWX` on D1.
- On a new D1 bar in broker-calendar March, open one long position if no
  position already exists for this EA magic and the spread cap is satisfied.
- Set a fixed ATR hard stop from prior completed D1 bars.
- Exit on the next D1 bar, on leaving March, or on the max-hold stale guard.

## Risk

Backtests use `RISK_FIXED=1000` with `RISK_PERCENT=0`. The strategy is
long-only, one-position-only, with no grid, martingale, pyramiding, partial
close, or adaptive sizing.

This is deliberately different from:

- `QM5_12727_wti-apr-prem`: April spring premium; this card isolates March.
- `QM5_12599_wti-feb-prem`: February premium from a separate Gorska-Krawiec
  source, not March.
- `QM5_12701_wti-oct-fade` and `QM5_12726_wti-nov-fade`: late-year short
  month-of-year fades, opposite direction and season.
- `QM5_12596_wti-mon-fade`, `QM5_12610_wti-tue-fade`, and
  `QM5_12597_wti-fri-prem`: weekday effects, not month-of-year March.
- `QM5_12576_eia-wti-season`: broad EIA refined-product demand seasonality
  with monthly rebalance plus SMA/ROC confirmation, not a pure March one-bar
  calendar premium.
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
- Current broker-calendar D1 bar must be in March.
- Entry direction is long only: BUY XTIUSD.DWX at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open XTIUSD.DWX position already exists for this EA magic.
- No entry if XTIUSD.DWX spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after entry.
- Close immediately if the current D1 bar is no longer in March.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade XTIUSD.DWX on D1.
- Skip entries when ATR is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Long-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_entry_month
  default: 3
  sweep_range: [3]
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
crude-oil returns, including March in the reported positive-return months. No
source performance number is imported into QM; the Q02+ pipeline tests the rule
on Darwinex XTIUSD.DWX bars.

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
- [x] R2 mechanical: fixed broker-calendar month, single D1 long entry, ATR
  stop, and next-bar/month-end time exit.
- [x] R3 testable: XTIUSD.DWX exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: March month-of-year long is not the existing April or
  February premium, October/November fades, weekday, WTI event, WTI
  momentum/reversal, XNG, ratio-basket, or RSI commodity sleeve.

## Framework Alignment

- no_trade: D1 and XTIUSD.DWX guard, parameter guard, spread cap.
- trade_entry: March broker-calendar long entry.
- trade_management: first post-entry D1 bar, month-end, and max-hold
  stale-position exits.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-06-28 | initial structural WTI March calendar-premium build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |

