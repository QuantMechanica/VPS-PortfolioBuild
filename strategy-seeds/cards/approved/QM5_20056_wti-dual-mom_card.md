---
ea_id: QM5_20056
slug: wti-dual-mom
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_S04
source_id: MOP-TSMOM-2012
source_citation: "Moskowitz, Ooi, and Pedersen (2012), Time Series Momentum, Journal of Financial Economics 104(2), 228-250. DOI: 10.1016/j.jfineco.2011.11.003."
target_symbols: [XTIUSD.DWX]
logical_symbol: QM5_20056_WTI_DUAL_MOM_D1
period: D1
expected_trade_frequency: "Monthly WTI rebalance when 3-month and 12-month return signs agree; approximately 6-12 trades/year."
expected_trades_per_year_per_symbol: 9
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
expected_pf: 1.10
expected_dd_pct: 20.0
strategy_type_flags: [time-series-momentum, dual-horizon-confirmation, atr-hard-stop, time-stop, low-frequency]
g0_approval_reasoning: "OWNER commodity-sleeve mission authorizes build: reputable peer-reviewed TSMOM source; deterministic 3m/12m sign agreement; registered XTI D1 data; no ML, grid, martingale, banned indicators, or external runtime feed."
---

# WTI Dual-Horizon Time-Series Momentum

## Hypothesis

WTI trends driven by supply investment, hedging, and inventory regimes can
persist, but a single horizon is noisy. Trade only when prior 63-D1 and
252-D1 log-return signs agree, adding structural crude exposure distinct from
the XAU/SP500/NDX/XNG book.

## Markets And Timeframe

`XTIUSD.DWX`, D1, evaluated on the first tradable D1 bar of each broker month.

## Entry Rules

- Long when both completed-bar 63-D1 and 252-D1 log returns are positive.
- Short when both are negative.
- No trade when signs disagree or either absolute return is below the fixed threshold.
- One position per magic; spread cap 1000 points.

## rules

Use completed D1 closes only. Evaluate once per broker month, require both
fixed-horizon signs to agree, and never pyramid or re-enter within that month.

## Exit Rules

Close at the next monthly rebalance or after 31 calendar days. Every entry has
a 20-D1 ATR hard stop at 3.5 ATR. Framework Friday close remains enabled.

## Parameters To Test

- `strategy_fast_lookback_d1`: default 63; range [42, 63, 84]
- `strategy_slow_lookback_d1`: default 252; range [189, 252]
- `strategy_min_abs_return_pct`: default 0; range [0, 2, 5]
- `strategy_atr_period`: default 20; range [14, 20, 30]
- `strategy_atr_sl_mult`: default 3.5; range [3.0, 3.5, 4.0]
- `strategy_max_hold_days`: default 31; range [28, 31]

## Risk

Backtest uses `RISK_FIXED=1000`, `RISK_PERCENT=0`. No live setfile, portfolio
gate, deployment manifest, or AutoTrading action is authorized.

## Strategy Allowability Check

- R1: peer-reviewed JFE primary source.
- R2: fixed monthly schedule and fixed return-sign rules.
- R3: registered Darwinex custom-symbol history.
- R4: MT5-native prices/ATR only; no ML or banned indicators.
- Non-duplicate: unlike `QM5_20055`, both 3m and 12m signs must agree; unlike
  12m-only WTI trend cards, the fast horizon can veto stale long-term trends.

## Framework Alignment

- no_trade: symbol/timeframe, parameter, spread, and position guards.
- trade_entry: monthly dual-horizon sign agreement.
- trade_management: monthly and stale-position close.
- trade_close: ATR hard stop and deterministic time exits.
