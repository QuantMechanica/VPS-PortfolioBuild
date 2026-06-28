---
ea_id: QM5_12733
slug: xti-xng-xmom
type: strategy
source_id: SRC05_S10_XTI_XNG_XMOM_2026
source_citation: "Chan, Ernest P. Algorithmic Trading: Winning Strategies and Their Rationale. Wiley, 2013, Chapter 6; supplement Daniel and Moskowitz, Momentum Crashes, 2011."
sources:
  - "[[sources/SRC05]]"
concepts:
  - "[[concepts/cross-sectional-momentum]]"
  - "[[concepts/commodity-trend-premium]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [cross-sectional-momentum, atr-hard-stop, signal-reversal-exit, time-stop, symmetric-long-short]
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
logical_symbol: QM5_12733_XTI_XNG_XMOM_D1
period: D1
expected_trade_frequency: "Monthly two-leg XTI/XNG relative momentum package; estimate 6-12 packages/year when the return spread clears the neutral band."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-06-28
g0_approval_reasoning: "R1 PASS approved SRC05_S10 Chan/Daniel-Moskowitz cross-sectional commodity momentum lineage; R2 PASS deterministic monthly return-rank entry and time exit; R3 PASS XTIUSD.DWX and XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.10
expected_dd_pct: 20.0
---

# XTI/XNG Energy Cross-Sectional Momentum

## Source

- Primary source: `strategy-seeds/cards/chan-at-xs-mom-fut_card.md` / SRC05_S10.
- Primary citation: Ernest P. Chan, Algorithmic Trading: Winning Strategies and Their Rationale, Wiley, 2013, Chapter 6.
- Supplement: Daniel and Moskowitz, Momentum Crashes, 2011.

## Concept

Cross-sectional momentum ranks assets by trailing return and buys the winner
while shorting the loser. This implementation narrows the approved commodity
futures source card to the two Darwinex-native energy symbols available here:
WTI (`XTIUSD.DWX`) and natural gas (`XNGUSD.DWX`). The result is a market-neutral
energy relative-strength sleeve intended to diversify away from the index/gold
book and from the existing single-symbol XNG RSI sleeve.

## Markets And Timeframe

- Basket leg symbols: XTIUSD.DWX and XNGUSD.DWX.
- Logical symbol: QM5_12733_XTI_XNG_XMOM_D1.
- Host chart: XTIUSD.DWX D1.
- Expected trade frequency: approximately 6-12 packages/year.
- Backtest risk mode: RISK_FIXED.
- Runtime data: Darwinex MT5 D1 OHLC and broker calendar only.

## Entry Rules

- Evaluate only on a new D1 bar.
- Entry is allowed only on the first D1 bar of a new broker-calendar month.
- Compute prior closed D1 log return for XTIUSD.DWX and XNGUSD.DWX over `strategy_lookback_d1`.
- Compute `return_diff = xti_return - xng_return`.
- If `return_diff` is greater than `strategy_min_return_diff_pct / 100`, buy XTIUSD.DWX and sell XNGUSD.DWX.
- If `return_diff` is less than `-strategy_min_return_diff_pct / 100`, sell XTIUSD.DWX and buy XNGUSD.DWX.
- No entry if either leg spread exceeds its configured cap.
- No entry if an open pair already exists for this EA magic set.

## Exit Rules

- Stop loss: per-leg ATR(`strategy_atr_period_d1`) * `strategy_atr_sl_mult`.
- Exit both legs on the next monthly rebalance.
- Exit both legs after `strategy_max_hold_days` calendar days.
- Exit both legs if a broken package is detected.
- Friday close remains enabled by the V5 framework.

## Filters

- Only trade from the XTIUSD.DWX D1 host chart.
- Skip entries when either leg lacks D1 history for the configured lookback.
- Skip entries when ATR is unavailable.
- Framework news, kill-switch, magic, and Friday-close guards remain active.

## Trade Management Rules

- Symmetric long/short.
- No pyramiding.
- No gridding.
- No martingale.
- No partial close.
- One two-leg package at a time.

## Parameters To Test

- name: strategy_lookback_d1
  default: 126
  sweep_range: [63, 126, 189, 252]
- name: strategy_min_return_diff_pct
  default: 2.0
  sweep_range: [0.0, 1.0, 2.0, 5.0]
- name: strategy_atr_period_d1
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.5, 3.0, 4.0]
- name: strategy_max_hold_days
  default: 35
  sweep_range: [25, 35, 45]

## Author Claims

The source lineage is used for the structural rule family: rank by trailing
return, buy the strongest future, and short the weakest future. No source
performance number is imported into QM; Q02+ tests this Darwinex-native energy
pair realization on XTIUSD.DWX and XNGUSD.DWX.

## Initial Risk Profile

- expected_pf: 1.10
- expected_dd_pct: 20
- expected_trade_frequency: approximately 6-12 packages/year.
- risk_class: medium-high.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: approved SRC05_S10 Chan/Daniel-Moskowitz commodity momentum lineage.
- [x] R2 mechanical: fixed monthly return ranking, paired long/short entry, ATR hard stops, deterministic time exit.
- [x] R3 testable: XTIUSD.DWX and XNGUSD.DWX exist in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale.
- [x] Non-duplicate: not XTI/XNG z-score ratio reversion, not XTI/XNG channel breakout, not WTI seasonality/news, not single-symbol time-series momentum, and not the XNG RSI sleeve.

## Framework Alignment

- no_trade: host chart guard, D1 guard, parameter guard, spread caps.
- trade_entry: monthly XTI/XNG prior-return rank; long stronger energy leg, short weaker leg.
- trade_management: package integrity only.
- trade_close: monthly rebalance exit, max-hold exit, Friday close, per-leg ATR stops.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|
| v1 | 2026-06-28 | initial structural XTI/XNG energy relative momentum build | G0 | APPROVED |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-06-28 | APPROVED | this card |
