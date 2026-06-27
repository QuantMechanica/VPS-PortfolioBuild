---
ea_id: QM5_12594
slug: yang-wti-reversal
type: strategy
source_id: 05abad87-420d-5a51-8a9b-3c35ad795385
source_citation: "Yang, Goncu, and Pantelous, Momentum and Reversal in Commodity Futures, SSRN. URL https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253"
sources:
  - "[[sources/YANG-COMM-REVERSAL-2017]]"
concepts:
  - "[[concepts/commodity-reversal]]"
  - "[[concepts/medium-term-mean-reversion]]"
indicators:
  - "[[indicators/rate-of-change]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Weekly D1 XTIUSD.DWX medium-term reversal gate after 63-day return extremes; estimate 8-14 trades/year."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS academic commodity futures momentum/reversal paper; R2 PASS deterministic weekly D1 return/SMA/ATR reversal rule; R3 PASS XTIUSD.DWX in DWX symbol matrix; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.12
expected_dd_pct: 18.0
---

# Yang WTI Medium-Term Reversal

## Source

- Source: [[sources/YANG-COMM-REVERSAL-2017]]
- Primary citation: Yang, Goncu, and Pantelous, "Momentum and Reversal in Commodity Futures", SSRN, URL https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253.

## Concept

Commodity futures research documents fixed-horizon momentum and reversal
families. This card isolates the reversal side on WTI: after a large multi-month
oil move, wait for a short D1 reversal confirmation and trade back toward a
slow mean. The rule is deliberately low-frequency and evaluated only once per
week.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: this uses no RSI and does not trade short-horizon pullbacks.
- `QM5_12563_donchian-turtle-trend-commodity`: this fades multi-month extremes instead of buying breakouts.
- `QM5_12576`, `QM5_12579`, `QM5_12590`, `QM5_12591`, `QM5_12592`, and `QM5_12593`: this is not an EIA calendar, WPSR, hurricane, refinery, or gasoline-season sleeve.
- `QM5_12577_cme-xauxag-ratio` and `QM5_12578_eia-oilgas-ratio`: this is not a two-leg basket ratio.

## Market Universe

- Target symbol: `XTIUSD.DWX`.
- No cross-symbol inputs.
- `single_symbol_only: true` because the paper family is mechanized here as an oil-only sleeve for portfolio diversification away from index and metal exposure.

## Timeframe

- Period: D1.
- Evaluate entries only on the first D1 bar of the trading week.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no futures curve, inventory feed, CFTC data, CSV, API, analyst forecast, or external data call.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current D1 bar must be Monday in broker time.
- Compute prior closed D1 close, close `strategy_lookback_days` bars earlier, close `strategy_confirm_days` bars earlier, SMA(`strategy_mean_period`), and ATR(`strategy_atr_period`).
- Long setup:
  - 63-day return is less than or equal to `-strategy_min_abs_return_pct`.
  - Prior close is below SMA(`strategy_mean_period`) by at least `strategy_min_stretch_atr * ATR`.
  - Prior close is above the close `strategy_confirm_days` bars earlier.
- Short setup:
  - 63-day return is greater than or equal to `strategy_min_abs_return_pct`.
  - Prior close is above SMA(`strategy_mean_period`) by at least `strategy_min_stretch_atr * ATR`.
  - Prior close is below the close `strategy_confirm_days` bars earlier.
- No entry if an open XTIUSD.DWX position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit long when the prior D1 close reaches or exceeds SMA(`strategy_mean_period`).
- Exit short when the prior D1 close reaches or falls below SMA(`strategy_mean_period`).
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Risk

- Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Live risk, if ever approved later, is allocated only by the portfolio process.
- No `T_Live`, deploy manifest, AutoTrading, or portfolio-gate file is part of this card.

## Filters

- Only trade `XTIUSD.DWX` on D1.
- Skip entries when ATR, SMA, or return history is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_lookback_days
  default: 63
  sweep_range: [42, 63, 84, 126]
- name: strategy_confirm_days
  default: 5
  sweep_range: [3, 5, 8]
- name: strategy_mean_period
  default: 63
  sweep_range: [42, 63, 84, 126]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_min_abs_return_pct
  default: 6.0
  sweep_range: [4.0, 6.0, 8.0, 10.0]
- name: strategy_min_stretch_atr
  default: 0.75
  sweep_range: [0.50, 0.75, 1.00, 1.25]
- name: strategy_atr_sl_mult
  default: 3.5
  sweep_range: [2.5, 3.5, 4.5]
- name: strategy_max_hold_days
  default: 15
  sweep_range: [10, 15, 21]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Author Claims

No performance claim is taken from the source. The source is used only for
structural lineage around commodity momentum/reversal families. The edge claim
is tested by the QM Q02+ pipeline on Darwinex XTIUSD.DWX bars.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 18
- expected_trade_frequency: approximately 8-14 trades/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: academic commodity futures momentum/reversal paper.
- [x] R2 mechanical: fixed weekly gate, D1 return extreme, SMA/ATR stretch, reversal confirmation, ATR stop, mean exit, and max-hold exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] No duplicate of existing energy sleeves: not EIA calendar/event/refinery/gasoline logic and not RSI/Turtle trend logic.

## Framework Alignment

- no_trade: D1 and XTIUSD.DWX guard, parameter guard, spread cap.
- trade_entry: weekly medium-term return extreme plus D1 reversal confirmation.
- trade_management: mean reversion and max-hold exits only.
- trade_close: hard ATR stop plus deterministic close rules.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural WTI commodity-reversal build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
