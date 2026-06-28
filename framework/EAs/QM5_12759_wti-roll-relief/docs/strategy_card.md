---
ea_id: QM5_12759
slug: wti-roll-relief
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
strategy_type_flags: [calendar-flow, roll-window, structural, long-only, atr-hard-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Post-roll WTI relief sleeve; estimate 4-8 trades/year after pressure and reclaim confirmation."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-29
g0_approval_reasoning: "R1 PASS official CFTC research paper on crude-oil ETF rolls; R2 PASS fixed post-roll trading-day window with same-month pressure proof, D1 reclaim, SMA gate, ATR stop, and time/window exits; R3 PASS XTIUSD.DWX; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.08
expected_dd_pct: 18.0
---

# WTI ETF Roll-Relief Rebound

## Source

- Source: [[sources/CFTC-ETF-ROLL-WTI-2014]]
- Primary citation: Mou, Y., "Predatory or Sunshine Trading? Evidence from
  Crude Oil ETF Rolls", CFTC Office of the Chief Economist, URL
  https://www.cftc.gov/sites/default/files/idc/groups/public/@economicanalysis/documents/file/oce_predatorysunshine0314.pdf.

## Concept

The CFTC research source studies predictable crude-oil ETF roll activity and
its futures-market effects. This card does not attempt to reconstruct ETF
holdings, futures curves, CFTC feeds, COT data, or roll calendars at runtime.
It expresses the structural flow idea as a low-frequency `XTIUSD.DWX` D1
relief sleeve: after early-month roll pressure is visible in the current
month, buy only if the market reclaims above a slow D1 mean during the
post-roll window.

The default implementation is long-only. It requires same-month pressure
evidence during broker D1 trading days 5-9, then enters during trading days
10-14 only after a positive D1 reclaim above SMA(`strategy_trend_period`).

## Hypothesis

Predictable crude-oil ETF roll activity can create temporary early-month
pressure in front-month WTI exposure. Once that pressure window passes, a D1
long sleeve that requires observed pressure plus a price reclaim may capture a
structural relief effect that is different from index, metal, XNG, WTI
calendar, WPSR, OPEC, refinery, hurricane, SPR, and CME-expiry sleeves.

## Rules

- Trade only `XTIUSD.DWX` on D1.
- Evaluate only on a new D1 bar.
- Count broker D1 trading days in the current calendar month.
- Pressure proof window is trading day
  `strategy_pressure_start_trading_day` through
  `strategy_pressure_end_trading_day`, default 5 through 9.
- Relief entry window is trading day `strategy_relief_start_trading_day`
  through `strategy_relief_end_trading_day`, default 10 through 14.
- Same-month pressure proof requires at least one completed D1 bar inside the
  pressure window with close-to-close return at or below
  `-strategy_min_pressure_return_pct` and close below
  SMA(`strategy_trend_period`).
- Enter long only once per calendar month.
- Long entry requires the prior completed D1 return to be at or above
  `strategy_min_reclaim_return_pct` and the prior close to be above
  SMA(`strategy_trend_period`).
- Set a fixed ATR hard stop from prior completed D1 bars.
- Exit when the relief window ends, the position crosses into a new month, the
  prior close falls below SMA(`strategy_trend_period`), or
  `strategy_max_hold_days` is reached.

## Risk

Backtests use `RISK_FIXED=1000` with `RISK_PERCENT=0`. The strategy is
long-only, one-position-only, with no grid, martingale, pyramiding, partial
close, external runtime data, or adaptive sizing.

This is deliberately different from:

- `QM5_12736_wti-roll-fade`: pressure-window short during trading days 5-9;
  this card trades post-window relief long during trading days 10-14 after
  observed pressure and reclaim.
- `QM5_12743_wti-postroll-fade`: CME futures-expiry post-roll fade; this card
  uses the CFTC crude ETF roll-pressure source and a same-month pressure proof.
- `QM5_12576_eia-wti-season`: broad EIA monthly seasonality, not ETF
  roll-pressure relief.
- `QM5_12579`, `QM5_12590`, `QM5_12592`, and `QM5_12752`: WPSR continuation,
  fade, pre-event, and inside-day breakout logic, not ETF roll relief.
- `QM5_12591`, `QM5_12593`, `QM5_12598`, `QM5_12754`, and `QM5_12755`:
  hurricane, refinery, OPEC, hurricane fade, and SPR policy-zone sleeves, not
  ETF roll relief.
- `QM5_12596`, `QM5_12597`, `QM5_12599`, `QM5_12610`, `QM5_12701`,
  `QM5_12726`, `QM5_12727`, `QM5_12729`, `QM5_12730`, `QM5_12734`, and
  `QM5_12753`: weekday or month-of-year WTI calendar effects, not a
  pressure-then-relief trading-day sequence.
- `QM5_12600_cme-wti-exp-brk`: CME expiry-window breakout, not ETF
  pressure-relief.
- `QM5_12603`, `QM5_12616`, `QM5_12708`, `QM5_12711`, and `QM5_12757`:
  commodity trend/pullback sleeves, not a fixed post-roll relief window.
- `QM5_12722_wti-cad-brk`, `QM5_12733_xti-xng-xmom`, and XAU/XAG basket
  sleeves: different information set and portfolio exposure.
- `QM5_12567_cum-rsi2-commodity`: oscillator pullback commodity sleeve; this
  card uses no oscillator.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: approximately 4-8 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no futures curve,
  ETF position feed, CFTC feed, COT data, CSV, API, analyst forecast, or model.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker D1 bar must be within the configured post-roll relief window.
- Same-month pressure proof must exist inside the configured pressure window.
- Prior completed D1 close-to-close return must be greater than or equal to
  `strategy_min_reclaim_return_pct`.
- Prior completed D1 close must be above SMA(`strategy_trend_period`).
- Entry direction is long only: BUY `XTIUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.
- No more than one entry per broker calendar month.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close when the current trading day-of-month is beyond
  `strategy_relief_end_trading_day`.
- Close when the broker calendar month changes after entry.
- Close a long when the prior D1 close falls below SMA(`strategy_trend_period`).
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Only magic slot 0 is valid.
- Relief window must begin after pressure window.
- Skip entries when ATR/SMA/OHLC are unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Long-only.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## 8. Parameters To Test

- name: strategy_pressure_start_trading_day
  default: 5
  sweep_range: [4, 5, 6]
- name: strategy_pressure_end_trading_day
  default: 9
  sweep_range: [8, 9, 10]
- name: strategy_relief_start_trading_day
  default: 10
  sweep_range: [9, 10, 11]
- name: strategy_relief_end_trading_day
  default: 14
  sweep_range: [13, 14, 15]
- name: strategy_min_pressure_return_pct
  default: 0.10
  sweep_range: [0.05, 0.10, 0.20]
- name: strategy_min_reclaim_return_pct
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

- expected_pf: 1.08
- expected_dd_pct: 18
- expected_trade_frequency: approximately 4-8 trades/year on D1.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: official CFTC research paper.
- [x] R2 mechanical: fixed pressure and relief windows, D1 pressure proof, SMA
  reclaim gate, ATR stop, time exit, and window exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no external runtime data, no adaptive PnL fitting, no grid,
  no martingale, one position per magic.
- [x] Non-duplicate: not existing WTI pressure short, CME postroll fade,
  weekday/month, WPSR, refinery, hurricane, OPEC, SPR, CAD/oil, XTI/XNG,
  XAU/XAG, or XNG pullback logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap.
- trade_entry: post-roll relief long after same-month pressure proof and D1
  reclaim above SMA.
- trade_management: relief-window end, month change, SMA failure, and max-hold
  exits.
- trade_close: hard ATR stop plus deterministic time/window exits.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-29 | initial structural WTI ETF post-roll relief build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-29 | APPROVED | this card |
