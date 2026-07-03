---
ea_id: QM5_12979
slug: wti-6m-reversal
type: strategy
strategy_id: BIANCHI-COMM-52W-2016_XTI_6M_REV
source_id: BIANCHI-COMM-52W-2016
source_citation: "Bianchi, R. J., Drew, M. E. and Fan, J. H. Commodities momentum: A behavioural perspective. Journal of Banking and Finance, 2016. DOI https://doi.org/10.1016/j.jbankfin.2016.06.010; Yang, Goncu, and Pantelous. Momentum and Reversal in Commodity Futures. SSRN working paper."
source_citations:
  - type: paper
    citation: "Bianchi, R. J., Drew, M. E. and Fan, J. H. (2016). Commodities momentum: A behavioural perspective. Journal of Banking and Finance."
    location: "https://doi.org/10.1016/j.jbankfin.2016.06.010"
    quality_tier: A
    role: primary
  - type: paper
    citation: "Yang, Goncu, and Pantelous. Momentum and Reversal in Commodity Futures."
    location: "https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/BIANCHI-COMM-52W-2016]]"
  - "[[sources/YANG-COMM-REVERSAL-2017]]"
concepts:
  - "[[concepts/commodity-reversal]]"
  - "[[concepts/medium-horizon-overextension]]"
  - "[[concepts/energy-mean-reversion]]"
indicators:
  - "[[indicators/rolling-return-120]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [medium-horizon-reversal, return-threshold-fade, atr-hard-stop, time-stop, monthly-rebalance, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12979_XTI_6M_REVERSAL_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly D1 WTI 6-month overextension fade; estimate 4-9 entries/year after threshold, SMA/ATR stretch, spread, and one-entry-per-month filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.08
expected_dd_pct: 22.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, low_frequency_sample, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS peer-reviewed Bianchi-Drew-Fan commodity behavioural source plus Yang-Goncu-Pantelous commodity reversal supplement; R2 PASS deterministic monthly 120-D1 WTI return threshold, SMA/ATR stretch confirmation, ATR stop, zero-cross exit, and max-hold exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data. Non-duplicate versus existing WTI sleeves because this is a monthly 6-month overextension fade, not 20-D1 reversal, 63-D1 reversal, 9/12-month momentum, 12-month carry, or calendar/event logic."
---

# WTI 6-Month Overextension Fade

## Source

- Source: [[sources/BIANCHI-COMM-52W-2016]]
- Primary citation: Bianchi, R. J., Drew, M. E. and Fan, J. H.,
  "Commodities momentum: A behavioural perspective", Journal of Banking and
  Finance, 2016, DOI https://doi.org/10.1016/j.jbankfin.2016.06.010.
- Supplement: Yang, Goncu, and Pantelous, "Momentum and Reversal in Commodity
  Futures", SSRN working paper, URL
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253.

## Concept

The commodity literature supports fixed-horizon momentum and reversal effects.
This card isolates the intermediate reversal side for WTI: once per broker
month, measure the completed 120-D1-bar return. If WTI has rallied far above
its short mean, sell the overextension; if WTI has collapsed far below its short
mean, buy the overextension. The position is held only until the 120-D1 return
crosses back through zero, the max-hold guard fires, Friday close intervenes,
or the ATR hard stop is hit.

This is deliberately different from:

- `QM5_12621_comm-reversal-4wk-xtiusd`: that card fades 20-D1 returns with a
  simpler weekly gate; this card uses a 120-D1 return, monthly gate, and SMA/ATR
  stretch confirmation.
- `QM5_12594_yang-wti-reversal`: that card uses a 63-D1 return plus a five-day
  reversal confirmation; this card is a slower 120-D1 overextension fade.
- `QM5_12603_wti-tsmom12m`, `QM5_12616_tsmom-9m-commodity-xtiusd`,
  `QM5_12708_commodity-tsmom-6m`, and `QM5_12913_xti-12m-carry`: those are
  momentum or carry sleeves, not a contrarian 6-month fade.
- WTI event, refinery, Cushing, OPEC, SPR, expiry, roll, weekday, month, Brent
  spread, XTI/XNG, oil/gold, oil/silver, XNG, XAU/XAG, index, and
  `QM5_12567_cum-rsi2-commodity` sleeves: no calendar event, ratio basket, RSI,
  oscillator pullback, external feed, ML, grid, or martingale is used.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 4-9 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, SMA, broker calendar, and
  V5 framework state only. No futures chain, CFTC feed, inventory feed, EIA
  feed, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new `XTIUSD.DWX` D1 bar.
- The current D1 bar must be the first broker D1 bar of a new month.
- Compute `return_120d = close[1] / close[1 + strategy_lookback_days] - 1`.
- Compute SMA(`strategy_sma_period`) and ATR(`strategy_atr_period`) on completed
  D1 bars.
- Short fade: `return_120d >= strategy_fade_threshold_pct` and completed close
  is at least `strategy_stretch_atr_mult` ATR above the SMA.
- Long fade: `return_120d <= -strategy_fade_threshold_pct` and completed close
  is at least `strategy_stretch_atr_mult` ATR below the SMA.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close a long when `return_120d >= 0`.
- Close a short when `return_120d <= 0`.
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Magic slot offset must be 0.
- Skip entries when D1 history, ATR, SMA, close series, or spread metadata is
  unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short overextension fade.
- No pyramiding, gridding, martingale, partial close, or trailing stop.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_lookback_days
  default: 120
  sweep_range: [90, 120, 160]
- name: strategy_sma_period
  default: 20
  sweep_range: [10, 20, 40]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_fade_threshold_pct
  default: 15.0
  sweep_range: [12.0, 15.0, 20.0]
- name: strategy_stretch_atr_mult
  default: 1.25
  sweep_range: [1.0, 1.25, 1.75]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 45
  sweep_range: [30, 45, 60]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

The sources establish commodity momentum/reversal lineage only. This card
imports no source performance number. Q02 and later phases must validate or
reject the mechanical WTI realization on Darwinex `XTIUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 22.
- expected_trade_frequency: approximately 4-9 entries/year.
- risk_class: medium-high because crude volatility and low-frequency sample
  size need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: peer-reviewed Bianchi-Drew-Fan commodity source plus
  Yang-Goncu-Pantelous commodity reversal supplement.
- [x] R2 mechanical: fixed monthly gate, 120-D1 return threshold, SMA/ATR
  stretch confirmation, ATR hard stop, return-zero exit, and max-hold exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: not 20-D1 reversal, 63-D1 reversal, 9/12-month momentum,
  12-month carry, event/calendar/refinery/weather/ratio logic, or commodity RSI.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, spread
  cap, monthly gate, and valid data checks.
- trade_entry: monthly 120-D1 WTI overextension fade with SMA/ATR stretch
  confirmation.
- trade_management: 120-D1 return zero-cross and max-hold exits.
- trade_close: hard ATR stop plus deterministic strategy exits and framework
  Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-03 | initial structural WTI 6-month overextension fade build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-03 | APPROVED | this card |
| Q01 Build Validation | 2026-07-03 | PASS | `artifacts/qm5_12979_build_result.json` |
| Q02 Baseline Screening | 2026-07-03 | QUEUED | work item `9f0fb558-5c27-4b07-867f-f7b99f76acc4` in `D:\QM\strategy_farm\state\farm_state.sqlite` |
