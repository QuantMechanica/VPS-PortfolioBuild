---
ea_id: QM5_12777
slug: wti-dec-fade
type: strategy
source_id: QUAY-WTI-DEC-2019
source_citation: "Quayyum, H. A., Khan, M. A. M. and Ali, S. M. Seasonality in crude oil returns. Soft Computing 24, 7857-7873 (2020). DOI https://doi.org/10.1007/s00500-019-04329-0"
source_citations:
  - type: peer_reviewed_article
    citation: "Quayyum, H. A., Khan, M. A. M. and Ali, S. M. Seasonality in crude oil returns. Soft Computing 24, 7857-7873 (2020)."
    location: "https://doi.org/10.1007/s00500-019-04329-0"
    quality_tier: A
    role: primary
sources:
  - "[[sources/QUAY-WTI-DEC-2019]]"
concepts:
  - "[[concepts/crude-oil-month-of-year-seasonality]]"
  - "[[concepts/december-calendar-fade]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12777_XTI_DEC_FADE_D1
period: D1
expected_trade_frequency: "December-only D1 WTI month-of-year negative-return sleeve; estimate 18-22 entries/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-29
expected_pf: 1.08
expected_dd_pct: 16.0
g0_approval_reasoning: "R1 PASS peer-reviewed crude-oil seasonality source; R2 PASS deterministic December D1 short/next-bar flat rule with ATR stop; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
---

# WTI December Calendar Fade

## Source

- Source: [[sources/QUAY-WTI-DEC-2019]]
- Primary citation: Quayyum, H. A., Khan, M. A. M. and Ali, S. M.,
  "Seasonality in crude oil returns", Soft Computing 24, 7857-7873 (2020),
  DOI https://doi.org/10.1007/s00500-019-04329-0.

## Concept

Peer-reviewed crude-oil seasonality research documents month-of-year structure
in WTI returns, including late-year weakness around November and December. This
card isolates the December side as a low-frequency `XTIUSD.DWX` sleeve: short
only on broker-calendar December D1 bars and flatten on the next D1 bar.

This is deliberately different from:

- `QM5_12726_wti-nov-fade`: November-only fade; this card isolates December.
- `QM5_12701_wti-oct-fade`: October-only fade from a separate source.
- `QM5_12599_wti-feb-prem`, `QM5_12730_wti-mar-prem`,
  `QM5_12727_wti-apr-prem`, and `QM5_12729_wti-aug-prem`: long month premia,
  opposite direction and different calendar windows.
- `QM5_12576_eia-wti-season`: broad refined-product demand seasonality with
  trend/ROC confirmation; this card is a pure fixed-month calendar short.
- `QM5_12773_opec-wti-fade`: June/December post-OPEC impulse fade with event
  proof and SMA/ATR stretch; this card uses no OPEC window, no event proof, and
  no SMA stretch.
- Weekday, weekend, WPSR, hurricane, refinery, expiry, ETF-roll, CAD/oil,
  XTI/XNG, oil/gold, oil/silver, XNG, and RSI commodity sleeves already in the
  registry.
- `QM5_12567_cum-rsi2-commodity`: no RSI, oscillator, short-horizon pullback,
  ML, grid, or martingale logic.

## Hypothesis

If WTI has a persistent late-year calendar weakness component, a December-only
short sleeve with one-D1-bar holding periods should produce a return stream that
is structurally different from the existing index/gold/natural-gas book and from
medium-term WTI trend/reversal rules.

## Rules

- Trade only `XTIUSD.DWX` on D1.
- Use only broker calendar, D1 OHLC, ATR, and framework filters.
- Enter short on a new broker-calendar December D1 bar.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- Exit on the first post-entry D1 bar, December end, max-hold expiry, Friday
  close, or ATR hard stop.

## Risk

Backtests use `RISK_FIXED=1000` with `RISK_PERCENT=0`. The strategy opens at
most one `XTIUSD.DWX` position per magic, never grids, never martingales, never
uses ML, and does not read external energy/news/futures data at runtime.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 18-22 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no futures curve,
  inventory feed, EIA feed, CFTC data, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar D1 bar must be in December.
- Entry direction is short only: SELL `XTIUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after entry.
- Close immediately if the current D1 bar is no longer in December.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Magic slot must be 0.
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
  default: 12
  sweep_range: [12]
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
crude-oil returns, including late-year weakness. No source performance number
is imported into QM; the Q02+ pipeline tests the rule on Darwinex `XTIUSD.DWX`
bars.

## Initial Risk Profile

- expected_pf: 1.08
- expected_dd_pct: 16
- expected_trade_frequency: approximately 18-22 trades/year.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: peer-reviewed crude-oil seasonality article with
  DOI and source citation.
- [x] R2 mechanical: fixed broker-calendar December, single D1 short entry,
  ATR stop, and next-bar/month-end time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one
  position per magic.
- [x] Non-duplicate: December month-of-year short is not the existing October
  or November fade, long month-premium family, WTI event/roll/weekday/season,
  WTI trend/reversal, XNG, ratio-basket, or RSI commodity sleeve.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, parameter guard, spread cap.
- trade_entry: December broker-calendar short entry.
- trade_management: first post-entry D1 bar, month-end, and max-hold
  stale-position exits.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-29 | initial structural WTI December calendar-fade card | G0 | APPROVED |
| v1-q02 | 2026-06-29 | EA compiled, build check passed, Q02 enqueued | Q02 | PENDING |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | this card |
| Q02 Backtest Queue | 2026-06-29 | PENDING | `docs/ops/evidence/2026-06-29_qm5_12777_wti_dec_fade_q02_enqueue.md` |
