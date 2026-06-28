---
ea_id: QM5_12736
slug: wti-roll-fade
type: strategy
source_id: CFTC-ETF-ROLL-WTI-2014
source_citation: "Mou, Y. Predatory or Sunshine Trading? Evidence from Crude Oil ETF Rolls. CFTC Office of the Chief Economist. URL https://www.cftc.gov/sites/default/files/idc/groups/public/@economicanalysis/documents/file/oce_predatorysunshine0314.pdf"
sources:
  - "[[sources/CFTC-ETF-ROLL-WTI-2014]]"
concepts:
  - "[[concepts/commodity-etf-roll-pressure]]"
  - "[[concepts/wti-structural-flow-window]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
strategy_type_flags: [calendar-flow, roll-window, structural, short-only, atr-hard-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Early-month WTI ETF roll-pressure sleeve; estimate 6-10 trades/year after confirmation and framework filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS official CFTC research paper on crude-oil ETF rolls; R2 PASS fixed trading-day window with D1 price confirmation, SMA gate, ATR stop, and time/window exits; R3 PASS XTIUSD.DWX; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 18.0
---

# WTI ETF Roll-Pressure Fade

## Source

- Source: [[sources/CFTC-ETF-ROLL-WTI-2014]]
- Primary citation: Mou, Y., "Predatory or Sunshine Trading? Evidence from
  Crude Oil ETF Rolls", CFTC Office of the Chief Economist, URL
  https://www.cftc.gov/sites/default/files/idc/groups/public/@economicanalysis/documents/file/oce_predatorysunshine0314.pdf.

## Concept

The CFTC research source studies predictable crude-oil ETF roll activity and
its futures-market effects. This card does not attempt to reconstruct ETF
holdings or the futures curve. It expresses the structural flow idea as a
low-frequency `XTIUSD.DWX` D1 sleeve: during the early-month roll-pressure
window, participate only when the market itself confirms downside pressure.

The default implementation is short-only. It requires the prior completed D1
bar to close down by at least the minimum return threshold and below an SMA,
then exits quickly by roll-window end, trend recovery, or max hold.

## Hypothesis

Predictable crude-oil ETF roll flows can create recurring early-month pressure
in front-month WTI exposure. A D1 short sleeve that trades only inside that
structural window and only after price confirmation should add energy exposure
that is different from index, metal, XNG, and existing WTI month/event sleeves.

## Rules

- Trade only `XTIUSD.DWX` on D1.
- Evaluate only on a new D1 bar.
- Count broker D1 trading days in the current calendar month.
- Entry window is trading day `strategy_roll_start_trading_day` through
  `strategy_roll_end_trading_day`, default 5 through 9.
- Enter short only once per calendar month.
- Short entry requires the prior closed D1 return to be at or below
  `-strategy_min_down_return_pct` and the prior close to be below
  SMA(`strategy_trend_period`).
- Set a fixed ATR hard stop from prior completed D1 bars.
- Exit when the roll window ends, the position crosses into a new month,
  the prior close recovers above SMA(`strategy_trend_period`), or
  `strategy_max_hold_days` is reached.

## Risk

Backtests use `RISK_FIXED=1000` with `RISK_PERCENT=0`. The strategy is
short-only, one-position-only, with no grid, martingale, pyramiding, partial
close, or adaptive sizing.

This is deliberately different from:

- `QM5_12577_cme-xauxag-ratio`: gold/silver ratio reversion basket, not WTI.
- `QM5_12724_cme-xauxag-brk`: gold/silver breakout basket, not WTI.
- `QM5_12576_eia-wti-season`: broad EIA monthly seasonality with SMA/ROC
  confirmation, not early-month ETF roll pressure.
- `QM5_12579`, `QM5_12590`, and `QM5_12592`: WPSR continuation/fade/pre-event
  logic, not ETF roll-window flow.
- `QM5_12591`, `QM5_12593`, and `QM5_12598`: hurricane, refinery, and OPEC
  event regimes, not ETF roll pressure.
- `QM5_12596`, `QM5_12597`, `QM5_12599`, `QM5_12610`, `QM5_12701`,
  `QM5_12726`, `QM5_12727`, `QM5_12729`, `QM5_12730`, and `QM5_12734`:
  weekday or month-of-year WTI calendar effects, not a trading-day roll window.
- `QM5_12600_cme-wti-exp-brk`: CME expiry-window breakout, not early-month ETF
  roll-pressure confirmation.
- `QM5_12603`, `QM5_12616`, `QM5_12708`, and `QM5_12711`: medium-term
  commodity time-series momentum, not a short fixed roll window.
- `QM5_12722_wti-cad-brk`: CAD/oil cross-market breakout, not roll flow.
- `QM5_12733_xti-xng-xmom`: XTI/XNG relative momentum basket, not
  single-symbol WTI roll pressure.
- `QM5_12567_cum-rsi2-commodity`: XNG RSI pullback commodity sleeve, no RSI or
  oscillator logic here.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: approximately 6-10 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no futures curve,
  ETF position feed, CFTC feed, COT data, CSV, API, analyst forecast, or ML
  model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker D1 bar must be within the configured early-month trading-day
  roll window.
- Prior completed D1 close-to-close return must be less than or equal to
  `-strategy_min_down_return_pct`.
- Prior completed D1 close must be below SMA(`strategy_trend_period`).
- Entry direction is short only: SELL `XTIUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.
- No more than one entry per broker calendar month.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close when the current trading day-of-month is beyond
  `strategy_roll_end_trading_day`.
- Close when the broker calendar month changes after entry.
- Close a short when the prior D1 close recovers above SMA(`strategy_trend_period`).
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Skip entries when ATR/SMA/OHLC are unavailable.
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

- name: strategy_roll_start_trading_day
  default: 5
  sweep_range: [4, 5, 6]
- name: strategy_roll_end_trading_day
  default: 9
  sweep_range: [8, 9, 10]
- name: strategy_min_down_return_pct
  default: 0.10
  sweep_range: [0.05, 0.10, 0.20]
- name: strategy_trend_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.50
  sweep_range: [2.0, 2.5, 3.0]
- name: strategy_max_hold_days
  default: 5
  sweep_range: [3, 5, 7]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The CFTC source is used only as structural lineage for predictable crude-oil
ETF roll activity. No source performance number is imported into QM. The Q02+
pipeline tests this deterministic rule on Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 18
- expected_trade_frequency: approximately 6-10 trades/year on D1.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official CFTC research paper.
- [x] R2 mechanical: fixed trading-day window, D1 return confirmation, SMA
  gate, ATR stop, time exit, and window exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  one position per magic.
- [x] Non-duplicate: not existing WTI weekday/month, WPSR, refinery, hurricane,
  OPEC, expiry-breakout, CAD/oil, XTI/XNG, XAU/XAG, or XNG RSI pullback logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: early-month roll-pressure short after D1 downside confirmation.
- trade_management: roll-window end, month change, SMA recovery, and max-hold
  exits.
- trade_close: hard ATR stop plus deterministic time/window exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-28 | initial structural WTI ETF roll-pressure build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
