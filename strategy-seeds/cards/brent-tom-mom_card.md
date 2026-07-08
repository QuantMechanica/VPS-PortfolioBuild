---
ea_id: QM5_13054
slug: brent-tom-mom
type: strategy
strategy_id: VANHEMERT-MOMTOM-2014_XBR
source_id: VANHEMERT-MOMTOM-2014
source_citation: "Van Hemert, Otto. The MOM-TOM Effect: Detecting the Market Impact of CTA Trading. SSRN, 2014; Moskowitz, Ooi and Pedersen, Time Series Momentum, Journal of Financial Economics, 2012."
source_citations:
  - type: working_paper
    citation: "Van Hemert, Otto. The MOM-TOM Effect: Detecting the Market Impact of CTA Trading. SSRN, 2014."
    location: "https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2515900"
    quality_tier: A-
    role: primary
  - type: journal_article
    citation: "Moskowitz, Tobias J., Yao Hua Ooi and Lasse Heje Pedersen. Time Series Momentum. Journal of Financial Economics, 104(2), 2012."
    location: "https://docs.lhpedersen.com/TimeSeriesMomentum.pdf"
    quality_tier: A
    role: momentum_lineage
  - type: exchange_reference
    citation: "CME Group. Brent Last Day Financial futures product overview."
    location: "https://www.cmegroup.com/markets/energy/crude-oil/brent-last-day-financial.html"
    quality_tier: A
    role: market_context
sources:
  - "[[sources/VANHEMERT-MOMTOM-2014]]"
concepts:
  - "[[concepts/turn-of-month]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/cta-flow-price-pressure]]"
indicators:
  - "[[indicators/momentum-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-anomaly, turn-of-month, time-series-momentum, cta-flow, atr-hard-stop, time-stop, symmetric-long-short, low-frequency, energy]
target_symbols: [XBRUSD.DWX]
primary_target_symbols: [XBRUSD.DWX]
markets: [XBRUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13054_XBR_TOM_MOM_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 Brent turn-of-month momentum package; at most one package per month, approximately 6-12 entries/year after momentum, spread, and framework filters."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-08
expected_pf: 1.08
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, xbr_history_sufficiency, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-08: R1 PASS Van Hemert MOM-TOM source plus Moskowitz/Ooi/Pedersen JFE time-series momentum lineage and CME Brent market context; R2 PASS deterministic D1 turn-of-month calendar window, fixed lookback return sign, ATR hard stop/target, window/time exits; R3 PASS XBRUSD.DWX local route used by recent Brent builds, with Q02 validating current history sufficiency; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate because this is Brent turn-of-month momentum, not WTI TOM, XNG TOM, Brent fixed-month/weekday seasonality, Brent TSMOM, Brent 52-week anchor, Brent/WTI spread, oil-metal ratio, XNG, XAU/XAG, index, or commodity RSI logic."
---

# Brent Turn-Of-Month Momentum

## hypothesis

Van Hemert's MOM-TOM paper tests whether CTA trend-following flow around the
turn of the month creates temporary price pressure in the direction of existing
momentum. Moskowitz, Ooi and Pedersen document time-series momentum across
futures markets, including commodities. This card specializes that structural
idea to Darwinex `XBRUSD.DWX`: during the broker-calendar turn-of-month window,
trade in the direction of a fixed D1 momentum lookback and flatten when the
window ends.

This is intended to add Brent crude exposure to the current XAU/SP500/NDX/XNG
book without creating another index, outright gold, natural gas, metals-ratio,
EIA-event, or monthly oil-seasonality alias.

## Source

- Primary: Van Hemert, Otto. "The MOM-TOM Effect: Detecting the Market Impact
  of CTA Trading." SSRN, 2014. URL:
  https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2515900.
- Momentum lineage: Moskowitz, Tobias J., Yao Hua Ooi and Lasse Heje Pedersen.
  "Time Series Momentum." Journal of Financial Economics, 104(2), 2012. URL:
  https://docs.lhpedersen.com/TimeSeriesMomentum.pdf.
- Market context: CME Group, Brent Last Day Financial futures product overview.
  URL: https://www.cmegroup.com/markets/energy/crude-oil/brent-last-day-financial.html.

## Concept

The EA uses only Darwinex `XBRUSD.DWX` D1 OHLC, broker-calendar dates, spread,
ATR, and V5 framework state. It does not read CTA holdings, futures curves,
EIA/WPSR/Cushing/OPEC/refinery/hurricane data, volume, open interest, CSV,
external APIs, analyst forecasts, or ML output.

This is deliberately different from:

- `QM5_12983_wti-tom-mom`: same source family, but WTI; this card targets Brent.
- `QM5_13009_xng-tom-mom`: same source family, but natural gas; this card
  targets Brent crude.
- Brent March/April/May/July/August/September long premia and
  January/November/December fades: this card trades a monthly turn window
  conditioned on recent momentum, not a fixed calendar month.
- `QM5_12849_brent-tsmom12m` and `QM5_12859_brent-52w-anchor`: those are broad
  trend/anchor sleeves, not narrow turn-of-month timing.
- Brent weekday, Brent/WTI, XBR/XNG, Brent/CAD, oil-metal, XAU/XAG, XNG, index,
  and `QM5_12567_cum-rsi2-commodity` sleeves: no weekday-only trigger, ratio
  basket, RSI, oscillator pullback, external feed, or ML.

## rules

- Host chart: `XBRUSD.DWX` D1.
- Direction: symmetric long/short.
- Entry window: `strategy_tom_pre_days` calendar days at month end or
  `strategy_tom_post_days` calendar days at the start of the next month.
- First-days-of-month bars belong to the previous month-end cycle, so the EA
  can open at most one package per turn-of-month cycle.
- Momentum signal:
  `return_pct = 100 * (close[1] / close[1 + strategy_momentum_lookback_days] - 1)`.
- Enter long when `return_pct >= strategy_min_momentum_pct`.
- Enter short when `return_pct <= -strategy_min_momentum_pct`.
- Exit when the turn-of-month window ends, max-hold expires, Friday close
  fires, or the ATR stop/target is hit.

## risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XBRUSD.DWX` D1
setfile. Live risk is intentionally not configured here; any future live
allocation must come from the portfolio process. The EA does not touch
`T_Live`, AutoTrading, deploy manifests, portfolio admission, or the portfolio
gate.

## Markets And Timeframe

- Symbol: `XBRUSD.DWX`.
- Period: `D1`.
- Expected frequency: at most one entry per broker-calendar turn-of-month
  cycle, about 6-12 entries/year before Q02 validation.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 D1 OHLC, spread, ATR, broker calendar, and V5
  framework state only.

## 4. Entry Rules

- Evaluate only on a new `XBRUSD.DWX` D1 bar.
- The active broker date must be inside the turn-of-month window:
  `strategy_tom_pre_days` calendar days at the end of the current month or
  `strategy_tom_post_days` calendar days at the start of the next month.
- Compute completed-D1 momentum using `strategy_momentum_lookback_days`.
- Entry Long: `return_pct >= strategy_min_momentum_pct`.
- Entry Short: `return_pct <= -strategy_min_momentum_pct`.
- No entry if an open `XBRUSD.DWX` position already exists for this EA magic.
- No entry if `XBRUSD.DWX` spread exceeds `strategy_max_spread_points`.

## 5. Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Profit target: fixed TP at ATR(`strategy_atr_period`) *
  `strategy_atr_tp_mult`.
- Close when the broker date is no longer in the turn-of-month window.
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## 6. Filters (No-Trade Module)

- Only trade `XBRUSD.DWX` on D1.
- Magic slot offset must be 0.
- Skip entries when D1 history, ATR, spread, entry price, or stop/target prices
  are unavailable.
- Framework news, kill-switch, magic, risk, and Friday-close guards remain
  active.

## 7. Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_tom_pre_days
  default: 2
  sweep_range: [1, 2, 3]
- name: strategy_tom_post_days
  default: 3
  sweep_range: [1, 2, 3]
- name: strategy_momentum_lookback_days
  default: 63
  sweep_range: [42, 63, 126]
- name: strategy_min_momentum_pct
  default: 4.0
  sweep_range: [2.5, 4.0, 6.0]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0]
- name: strategy_atr_tp_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 6
  sweep_range: [3, 6, 8]
- name: strategy_max_spread_points
  default: 1200
  sweep_range: [800, 1200, 1800]

## Author Claims

The sources establish structural lineage for time-series momentum and a
turn-of-month CTA-flow timing hypothesis. This card imports no source
performance claim. Q02 and later phases must validate or reject the mechanical
`XBRUSD.DWX` realization on Darwinex bars.

## Initial Risk Profile

- expected_pf: 1.08.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 6-12 entries/year.
- risk_class: medium-high because crude-oil gaps and the small monthly sample
  require Q02 proof.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: Van Hemert MOM-TOM source, Moskowitz/Ooi/Pedersen
  JFE time-series momentum, and CME Brent market context.
- [x] R2 mechanical: fixed turn-of-month window, fixed return lookback,
  symmetric momentum direction, ATR hard stop/target, and deterministic
  window/time exits.
- [x] R3 testable: `XBRUSD.DWX` has active local routes through recent Brent
  builds; Q02 validates current history sufficiency.
- [x] R4 compliant: no ML, adaptive PnL fitting, grid, martingale, external
  runtime feed, or more than one position per magic.
- [x] Non-duplicate: not XAU/XAG, not XNG, not WTI TOM, not Brent month/
  weekday/trend/anchor/spread/basket/carry/reversal/ORB/RSI logic.

## Framework Alignment

- no_trade: XBR/D1 host guard, magic-slot guard, parameter guard, spread cap,
  turn-of-month calendar guard, and valid data checks.
- trade_entry: turn-of-month fixed-lookback D1 momentum direction.
- trade_management: turn-window exit and max-hold stale-position exit.
- trade_close: hard ATR stop/target plus deterministic strategy exits and
  framework Friday close.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-07-08 | initial Brent turn-of-month momentum card/build | Q02 | QUEUED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-08 | APPROVED | this card |
| Q01 Build Validation | 2026-07-08 | PASS | `artifacts/qm5_13054_build_result.json`; `C:/QM/repo/framework/build/compile/20260708_070926/QM5_13054_brent-tom-mom.compile.log`; `D:/QM/reports/framework/21/build_check_20260708_070943.json` |
| Q02 Baseline Screening | 2026-07-08 | QUEUED | `artifacts/qm5_13054_q02_enqueue_20260708.json`; work item `a803f980-7675-46ca-8498-b22d43ed69b4` |
