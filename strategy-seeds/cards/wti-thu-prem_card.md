---
ea_id: QM5_12771
slug: wti-thu-prem
type: strategy
source_id: QUAY-WTI-DOW-2019
source_citation: "Quayyum, H. A., Khan, M. A. M. and Ali, S. M. Seasonality in crude oil returns. Soft Computing 24, 7857-7873 (2020). DOI https://doi.org/10.1007/s00500-019-04329-0"
sources:
  - "[[sources/QUAY-WTI-DOW-2019]]"
concepts:
  - "[[concepts/crude-oil-day-of-week-seasonality]]"
  - "[[concepts/thursday-calendar-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, day-of-week, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Weekly D1 WTI Thursday-calendar premium sleeve; estimate 45-52 trades/year after broker holidays and framework filters."
expected_trades_per_year_per_symbol: 48
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS peer-reviewed crude-oil day-of-week source; R2 PASS deterministic Thursday D1 long/next-bar flat rule with ATR stop; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 16.0
---

# WTI Thursday Calendar Premium

## Source

- Source: [[sources/QUAY-WTI-DOW-2019]]
- Primary citation: Quayyum, H. A., Khan, M. A. M. and Ali, S. M.,
  "Seasonality in crude oil returns", Soft Computing 24, 7857-7873 (2020),
  DOI https://doi.org/10.1007/s00500-019-04329-0.
- Public metadata pointer: https://pure.cardiffmet.ac.uk/en/publications/seasonality-in-crude-oil-returns/.

## Concept

Peer-reviewed crude-oil seasonality research reports statistically significant
day-of-week effects in Brent and WTI returns, including a Thursday premium in
the studied futures samples. This card isolates that side as a low-frequency
Darwinex CFD test: buy `XTIUSD.DWX` only on the broker-calendar Thursday D1
bar and flatten on the first subsequent D1 bar.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, cumulative oscillator, or short-term
  pullback logic.
- `QM5_12596_wti-mon-fade` and `QM5_12610_wti-tue-fade`: those are
  early-week short fades.
- `QM5_12597_wti-fri-prem`: that buys the Friday bar, not Thursday.
- `QM5_12753_wti-thu-pb-fri-bounce`: that waits for a material Thursday
  decline and enters on Friday; this card enters Thursday unconditionally and
  exits after the Thursday session.
- WTI month-of-year, WPSR, hurricane, refinery, OPEC, expiry, ETF-roll, CAD,
  oil/gold, oil/silver, XTI/XNG, XNG, XAU/XAG, Donchian, long-horizon
  momentum, and commodity RSI sleeves already in the registry.

## Markets And Timeframe

- Target symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 45-52 trades/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no futures curve,
  inventory feed, EIA feed, CFTC data, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar D1 bar must be Thursday, where Sunday=0 and
  Thursday=4 in MQL5 broker time.
- Entry direction is long only: BUY `XTIUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after Thursday.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Magic slot must be 0.
- Skip entries when ATR or the broker-calendar D1 bar is unavailable.
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

- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.25
  sweep_range: [1.5, 2.25, 3.0]
- name: strategy_max_hold_days
  default: 1
  sweep_range: [1, 2]
- name: strategy_entry_dow
  default: 4
  sweep_range: [4]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The source is used only for structural lineage around day-of-week seasonality
in WTI and Brent returns, including the reported Thursday premium. No source
performance number is imported into QM; Q02 and later phases must validate the
rule on Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 16
- expected_trade_frequency: approximately 45-52 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: peer-reviewed Soft Computing crude-oil seasonality
  paper with DOI.
- [x] R2 mechanical: fixed broker-calendar Thursday, single D1 long entry, ATR
  stop, next-bar exit.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: Thursday long premium is not existing Monday/Tuesday
  short fade, Friday premium, conditional Thursday-pullback/Friday-bounce,
  WTI month/event/roll/refinery/hurricane/reversal, XNG, XAU/XAG, or RSI
  commodity logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: Thursday broker-calendar long entry.
- trade_management: first non-Thursday D1 bar and max-hold stale-position
  exits.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-29 | initial structural WTI Thursday calendar-premium card | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | this card |
