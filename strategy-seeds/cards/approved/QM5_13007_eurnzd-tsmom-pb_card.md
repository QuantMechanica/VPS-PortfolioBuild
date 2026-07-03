---
ea_id: QM5_13007
slug: eurnzd-tsmom-pb
type: strategy
source_id: MOP-TSMOM-2012-EURNZD-2026
source_citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250; applied to EURNZD.DWX as a price-only DWX forex cross."
sources:
  - "strategy-seeds/sources/MOP-TSMOM-2012/source.md"
concepts:
  - time-series-momentum
  - multi-horizon-confirmation
  - trend-following
indicators:
  - lookback-return
target_symbols: [EURNZD.DWX]
single_symbol_only: true
period: D1
expected_trade_frequency: "Weekly D1 rebalance; enters only when 3-month and 6-month return signs agree, approximately 18-40 weekly swing entries/year after flat regimes, spread, news, and Friday-close filters."
expected_trades_per_year_per_symbol: 24
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Moskowitz-Ooi-Pedersen 2012 is a JFE/AQR time-series momentum source with tested lookback horizons across liquid markets."
r2_mechanical: PASS
r2_reasoning: "On the first tradeable D1 bar of each broker-calendar week, compare closed EURNZD.DWX price to 63- and 126-D1-bar closes; hold the agreed direction or flatten on disagreement."
r3_data_available: PASS
r3_reasoning: "EURNZD.DWX is present in dwx_symbol_matrix.csv and has D1 history from 2017 through 2026 on T1-T5."
r4_ml_forbidden: PASS
r4_reasoning: "No ML, no adaptive weights, no external data, no grid, no martingale, one position per magic."
pipeline_phase: G0
last_updated: 2026-07-03
expected_pf: 1.12
expected_dd_pct: 22.0
portfolio_scope: single_symbol
---

# EURNZD Weekly Persistent-Bias Time-Series Momentum

## Source

This card mechanizes the Moskowitz, Ooi, and Pedersen time-series momentum
structure on a currently uncovered Darwinex forex cross. The source documents
that past excess returns over multiple lookback horizons forecast continuation.
This implementation uses only Darwinex `.DWX` D1 price history and broker
calendar state at runtime.

## Concept

EURNZD is an unrepresented FX cross in the current V5 strategy farm. The rule
tests whether short-term and medium-term price direction agree. Agreement
indicates persistent trend bias; disagreement indicates transition or chop and
the EA stays flat.

## Markets And Timeframe

- Symbol: EURNZD.DWX.
- Period: D1.
- Backtest risk mode: RISK_FIXED.
- Single-symbol baseline by design; do not expand to other FX crosses in this EA.

## Entry Rules

- Evaluate on the first tradeable new D1 bar of each broker-calendar week.
- Compute `signal_3m = sign(close[1] - close[1 + 63])`.
- Compute `signal_6m = sign(close[1] - close[1 + 126])`.
- If both signals are positive and no long is open, open or flip to long.
- If both signals are negative and no short is open, open or flip to short.
- If the signals disagree or either lookback is unavailable, close any open
  position and remain flat.

## Exit Rules

- Weekly disagreement exits flatten the position.
- Weekly opposite agreement flips direction.
- Each entry receives a hard ATR(14, D1) * 3.0 protective stop.
- No trailing stop, break-even, pyramiding, partial close, averaging, or grid.
- Framework Friday close remains enabled.

## Filters

- Host chart must be EURNZD.DWX on D1 with magic slot 0.
- Skip entries when current spread is positive and greater than
  `strategy_max_spread_points`.
- Framework kill-switch, news, and Friday-close guards remain active.

## Parameters To Test

- name: strategy_fast_lookback_d1_bars
  default: 63
  sweep_range: [42, 63, 84]
- name: strategy_slow_lookback_d1_bars
  default: 126
  sweep_range: [105, 126, 147]
- name: strategy_atr_period
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_atr_sl_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
- name: strategy_max_spread_points
  default: 80
  sweep_range: [50, 80, 120]

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No live deployment is authorized by this card.

## Strategy Allowability Check

- [x] R1 reputable source: MOP (2012) time-series momentum.
- [x] R2 mechanical: fixed weekly cadence, fixed lookbacks, deterministic flat/long/short state.
- [x] R3 testable: EURNZD.DWX D1 history exists from 2017 through 2026.
- [x] R4 compliant: no ML, no grid, no martingale, no external feed.

## Framework Alignment

- no_trade: fixed symbol/timeframe/input guard plus framework controls.
- trade_entry: weekly dual-horizon return-sign agreement.
- trade_management: no discretionary management beyond framework stop/Friday/kill controls.
- trade_close: weekly disagreement/opposite-signal exit handled on the rebalance bar.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-03 | initial EURNZD diversity sleeve from MOP TSMOM source | G0 | APPROVED |
| v2 | 2026-07-03 | Q01 zero-trade smoke rework: weekly 3m/6m TSMOM cadence for observable low-frequency trade generation | G0 | APPROVED |
