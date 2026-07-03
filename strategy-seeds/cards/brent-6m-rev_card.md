---
ea_id: QM5_12980
slug: brent-6m-rev
type: strategy
strategy_id: BIANCHI-COMM-52W-2016_BRENT_6M_REV
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
  - "[[concepts/brent-energy-mean-reversion]]"
indicators:
  - "[[indicators/rolling-return-120]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [medium-horizon-reversal, return-threshold-fade, atr-hard-stop, time-stop, monthly-rebalance, symmetric-long-short, low-frequency]
target_symbols: [XBRUSD.DWX]
primary_target_symbols: [XBRUSD.DWX]
markets: [XBRUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12980_BRENT_6M_REV_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly D1 Brent 6-month overextension fade; estimate 4-9 entries/year after threshold, SMA/ATR stretch, spread, and one-entry-per-month filters."
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
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS peer-reviewed Bianchi-Drew-Fan commodity behavioural source plus Yang-Goncu-Pantelous commodity reversal supplement; R2 PASS deterministic monthly 120-D1 Brent return threshold, SMA/ATR stretch confirmation, ATR stop, zero-cross exit, and max-hold exit; R3 PASS XBRUSD.DWX is already routed by active local Brent builds and Q02 validates current history sufficiency; R4 PASS no ML/grid/martingale/external data. Non-duplicate versus existing commodity sleeves because this is a monthly Brent 6-month overextension fade, not WTI 6-month reversal, Brent 52-week anchor momentum, Brent calendar, WTI/Brent spread, XNG event/seasonal, XAU/XAG, or RSI commodity logic."
---

# Brent 6-Month Overextension Fade

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
This card isolates the intermediate reversal side for Brent: once per broker
month, measure the completed 120-D1-bar return. If Brent has rallied far above
its short mean, sell the overextension; if Brent has collapsed far below its
short mean, buy the overextension. The position is held only until the 120-D1
return crosses back through zero, the max-hold guard fires, Friday close
intervenes, or the ATR hard stop is hit.

This is deliberately different from:

- `QM5_12979_wti-6m-reversal`: same behavioural family, but this trades the
  Brent CFD proxy `XBRUSD.DWX`, not WTI `XTIUSD.DWX`.
- `QM5_12859_brent-52w-anchor` and `QM5_12849_brent-tsmom12m`: those are
  continuation/momentum sleeves; this is a contrarian 120-D1 overextension
  fade.
- `QM5_12841`, `QM5_12853`, `QM5_12854`, `QM5_12855`, `QM5_12856`,
  `QM5_12865`, `QM5_12866`, `QM5_12911`, and `QM5_12976`: no fixed
  weekday/month calendar edge is used.
- `QM5_12843`, `QM5_12848`, and `QM5_12860`: not a WTI/Brent spread or
  relative shock basket.
- `QM5_12567_cum-rsi2-commodity`, XNG event/seasonal sleeves, XAU/XAG ratio
  sleeves, gas-metal relative-value sleeves, and index sleeves: no RSI,
  oscillator pullback, natural-gas report, metal ratio, index signal, external
  feed, ML, grid, or martingale is used.

## Hypothesis

Brent can overshoot over a medium horizon after large directional commodity
moves. A monthly 120-D1 return threshold plus SMA/ATR stretch confirmation
should isolate those overextensions while avoiding short-horizon oscillator
logic and avoiding fixed calendar/event timing.

## Rules

Use a monthly closed-D1 rule on `XBRUSD.DWX`: fade a completed 120-D1 return
above or below the configured threshold only when price is stretched at least
`strategy_stretch_atr_mult` ATR from SMA(`strategy_sma_period`), then exit on
return zero-cross, max hold, Friday close, or ATR hard stop.

## Markets And Timeframe

- Symbol: `XBRUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 4-9 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, SMA, broker calendar, and
  V5 framework state only. No futures chain, CFTC feed, inventory feed, EIA
  feed, CSV, API, analyst forecast, or ML model.

## Entry Rules

- Evaluate only on a new `XBRUSD.DWX` D1 bar.
- The current D1 bar must be the first broker D1 bar of a new month.
- Compute `return_120d = close[1] / close[1 + strategy_lookback_days] - 1`.
- Compute SMA(`strategy_sma_period`) and ATR(`strategy_atr_period`) on completed
  D1 bars.
- Short fade: `return_120d >= strategy_fade_threshold_pct` and completed close
  is at least `strategy_stretch_atr_mult` ATR above the SMA.
- Long fade: `return_120d <= -strategy_fade_threshold_pct` and completed close
  is at least `strategy_stretch_atr_mult` ATR below the SMA.
- No entry if an open `XBRUSD.DWX` position already exists for this EA magic.
- No entry if `XBRUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close a long when `return_120d >= 0`.
- Close a short when `return_120d <= 0`.
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade `XBRUSD.DWX` on D1.
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
  default: 1200
  sweep_range: [800, 1200, 1800]

## Author Claims

The sources establish commodity momentum/reversal lineage only. This card
imports no source performance number. Q02 and later phases must validate or
reject the mechanical Brent realization on Darwinex `XBRUSD.DWX` bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 22.
- expected_trade_frequency: approximately 4-9 entries/year.
- risk_class: medium-high because Brent volatility and low-frequency sample
  size need Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: peer-reviewed Bianchi-Drew-Fan commodity source plus
  Yang-Goncu-Pantelous commodity reversal supplement.
- [x] R2 mechanical: fixed monthly gate, 120-D1 return threshold, SMA/ATR
  stretch confirmation, ATR hard stop, return-zero exit, and max-hold exit.
- [x] R3 testable: `XBRUSD.DWX` has active local Brent routes through prior
  builds; Q02 validates current history sufficiency.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: not WTI 6-month reversal, Brent 52-week anchor, Brent
  12-month momentum, Brent calendar, WTI/Brent spread, XNG, XAU/XAG,
  gas-metal relative value, or commodity RSI.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XBRUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Framework Alignment

- no_trade: D1 and `XBRUSD.DWX` guard, magic-slot guard, parameter guard, spread
  cap, monthly gate, and valid data checks.
- trade_entry: monthly 120-D1 Brent overextension fade with SMA/ATR stretch
  confirmation.
- trade_management: 120-D1 return zero-cross and max-hold exits.
- trade_close: hard ATR stop plus deterministic strategy exits and framework
  Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-03 | initial structural Brent 6-month overextension fade build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-03 | APPROVED | this card |
| Q01 Build Validation | 2026-07-03 | PASS | `artifacts/qm5_12980_build_result.json` |
| Q02 Baseline Screening | 2026-07-03 | QUEUED | work item `08c6889f-3b71-4bd2-b204-7f6ad99330c5` in `D:\QM\strategy_farm\state\farm_state.sqlite` |
