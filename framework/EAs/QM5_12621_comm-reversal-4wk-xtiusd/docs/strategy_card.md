---
ea_id: QM5_12620
slug: comm-reversal-4wk-xngusd
type: strategy
source_id: 05abad87-420d-5a51-8a9b-3c35ad795385
source_citation: "Yang, Goncu, and Pantelous. Momentum and Reversal in Commodity Futures. SSRN working paper. URL https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253"
sources:
  - "[[sources/YANG-COMM-REVERSAL-2017]]"
concepts:
  - "[[concepts/short-term-reversal]]"
  - "[[concepts/mean-reversion]]"
  - "[[concepts/natural-gas-overreaction]]"
indicators:
  - "[[indicators/n-day-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [short-term-reversal, mean-reversion, weekly-gate, atr-hard-stop, time-stop, symmetric-long-short]
target_symbols: [XNGUSD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Weekly D1 XNGUSD.DWX 20-bar overreaction reversal gate; estimate 14-24 trades/year after threshold, spread, news, and one-position filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-27
g0_approval_reasoning: "R1 PASS academic commodity futures momentum/reversal source; R2 PASS deterministic weekly D1 return-threshold reversal rule; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 20.0
---

# XNGUSD 4-Week Commodity Reversal

## Source

- Source: [[sources/YANG-COMM-REVERSAL-2017]]
- Primary citation: Yang, Goncu, and Pantelous, "Momentum and Reversal in Commodity Futures", SSRN, URL https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253.

## Concept

Commodity futures reversal research documents that fixed-horizon commodity moves
can overshoot before reverting. This card isolates that short-term reversal
premise on the highest-volatility DWX energy symbol: when natural gas has moved
far over the prior 20 D1 bars, fade the move on a weekly cadence with a fixed
ATR loss cap and a four-week maximum hold.

This is deliberately different from:

- `QM5_12567_cum-rsi2-commodity`: no RSI, no two-day oscillator pullback, and no SMA(200) continuation filter.
- `QM5_12575_eia-xng-season`: not a monthly natural-gas seasonal demand map.
- `QM5_12584_eia-xng-storage`: no weekly EIA storage report aftershock rule.
- `QM5_12586`, `QM5_12587`, `QM5_12588`, and `QM5_12595`: not winter/summer/injection/shoulder-season breakout or fade logic.
- `QM5_12603_wti-tsmom12m` and `QM5_12594_yang-wti-reversal`: different symbol exposure and different XNG volatility threshold.

## Market Universe

- Target symbol: `XNGUSD.DWX`.
- No cross-symbol inputs.
- `single_symbol_only: true` because this card is intended as a natural-gas
  overreaction sleeve, not as a broad commodity-family fanout.

## Timeframe

- Period: D1.
- Evaluate entries only on the first D1 bar of the trading week.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 OHLC only; no storage feed, weather feed, futures
  curve, CFTC data, CSV, API, analyst forecast, or external data call.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current D1 bar must be Monday in broker time.
- Compute the prior closed D1 close and the close `strategy_lookback_days` bars earlier.
- Long setup: 20-bar return is less than or equal to `-strategy_min_abs_return_pct`; BUY `XNGUSD.DWX`.
- Short setup: 20-bar return is greater than or equal to `strategy_min_abs_return_pct`; SELL `XNGUSD.DWX`.
- No entry if an open `XNGUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) * `strategy_atr_sl_mult`.
- Exit after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Risk

- Backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Live risk, if ever approved later, is allocated only by the portfolio process.
- No `T_Live`, deploy manifest, AutoTrading, or portfolio-gate file is part of this card.

## Filters

- Only trade `XNGUSD.DWX` on D1.
- Skip entries when ATR or return history is unavailable.
- Standard framework news, kill-switch, magic, spread, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- No trailing stop in v1.
- One open position per magic/symbol.

## Parameters To Test

- name: strategy_lookback_days
  default: 20
  sweep_range: [15, 20, 30]
- name: strategy_atr_period
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_min_abs_return_pct
  default: 6.0
  sweep_range: [4.0, 6.0, 8.0, 10.0]
- name: strategy_atr_sl_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5, 3.0]
- name: strategy_max_hold_days
  default: 28
  sweep_range: [14, 21, 28]
- name: strategy_max_spread_points
  default: 2500
  sweep_range: [1500, 2500, 3500]

## Author Claims

No performance claim is taken from the source. The source is used only for
structural lineage around commodity momentum/reversal families; the QM Q02+
pipeline tests the mechanical XNGUSD.DWX port.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 20
- expected_trade_frequency: approximately 14-24 trades/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: academic commodity futures momentum/reversal paper.
- [x] R2 mechanical: fixed weekly gate, D1 return threshold, ATR hard stop, and max-hold exit.
- [x] R3 testable: `XNGUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale, one position per magic.
- [x] Non-duplicate: not RSI2 pullback, EIA seasonality, EIA storage aftershock, or XTI reversal logic.

## Framework Alignment

- no_trade: D1 and XNGUSD.DWX guard, parameter guard, spread cap.
- trade_entry: weekly 20-D1-bar return extreme fade.
- trade_management: max-hold stale-position exit.
- trade_close: hard ATR stop plus deterministic time exit.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-06-27 | initial structural XNG commodity-reversal build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-27 | APPROVED | this card |
