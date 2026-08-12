---
card_schema_version: 2
ea_id: QM5_20170
slug: wti-wed-bear
type: strategy
strategy_id: LI-MOP-WTI-WEDBEAR-2026_S01
variant_id: LI-MOP-WTI-WEDBEAR-2026_S01
source_id: LI-MOP-WTI-WEDBEAR-2026
status: DRAFT
g0_status: APPROVED
execution_contract_status: DRAFT
created: 2026-07-26
created_by: Research+Development
strategy_mechanic: wednesday-wti-long-only-when-completed-252d-return-is-negative
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
symbol: XTIUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 8-25 Wednesday packages/year; Q02 must prove >=5/year."
expected_trades_per_year_per_symbol: 14
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: ENQUEUED
q02_work_item_id: ee4a09fb-df2f-4457-ae47-e74c51391eef
modules_used: [no_trade, trade_entry, trade_management, trade_close]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission: R1 PASS governed peer-reviewed composite packet; R2 PASS genuine Wednesday boundary, negative completed 252-D1 return, one BUY, ATR stop, next-D1 exit, and persistent weekly attempt; R3 PASS registered XTIUSD.DWX D1; R4 PASS deterministic native MT5 data only, no ML/grid/martingale. Semantically distinct from positive-regime Wednesday and negative-regime Thursday variants."
---

# QM5_20170 WTI Wednesday Bear-Regime Bounce

## Hypothesis

WTI's source-supported positive Wednesday return may express as a short-horizon
bounce inside a negative slow regime. This tests a different return state from
`QM5_20154`, which trades Wednesday only when the completed 252-D1 return is
positive, and a different weekday from `QM5_20169`. Diversification remains a
later evidence gate, not a card claim.

## Rules

1. Run only on exact `XTIUSD.DWX`, D1, EA 20170, magic slot 0.
2. Evaluate only the first executable tick within five minutes of a Wednesday
   D1 bar whose immediately prior completed D1 bar is Tuesday.
3. Persist the Monday-anchored broker-week key as consumed before fallible
   history, signal, spread, quote, news, stop, or order gates. Never retry.
4. Compute `ln(Close[1] / Close[253])`; BUY only when strictly negative.
5. Require completed `ATR(20)`, spread <=1500 points, and attach a frozen
   `3.0 * ATR(20)` hard stop below entry. No take-profit.
6. Close at the first new D1 bar that is not Wednesday, immediately on a
   wrong-side position, or after two calendar days.
7. One position per magic; no pending order, scale-in, grid, martingale,
   trailing stop, partial close, external data, adaptive fit, or ML.

## Source-Defined Rules

The governed Li lineage supplies the positive WTI Wednesday direction.
Moskowitz et al. supply the completed 12-month own-return sign as a measurable
slow state. Neither source tests this conjunction or defines the CFD controls.

## Parameters To Test

| parameter | default | authorized values |
|---|---:|---|
| `strategy_momentum_lookback_d1` | 252 | [252] |
| `strategy_min_abs_return_pct` | 0.0 | [0.0] |
| `strategy_entry_grace_minutes` | 5 | [5] |
| `strategy_atr_period` | 20 | [20] |
| `strategy_atr_sl_mult` | 3.0 | [3.0] |
| `strategy_max_hold_days` | 2 | [2] |
| `strategy_max_spread_points` | 1500 | [1500] |

## Risk And Falsification

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Retire below five completed packages/year; fail any
wrong-day, non-negative-regime, repeated-week, missing-stop, late-exit,
risk-mode, PF, or DD gate. No correlation waiver or post-result mutation.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked inputs, news OFF, Friday close, identity guards.
- trade_entry: genuine Wednesday-after-Tuesday, negative completed 252-D1 return, consumed-week state, spread/quote/ATR validation, one BUY.
- trade_management: first non-Wednesday, wrong-side, and two-day stale closes.
- trade_close: V5 close path, hard stop, Friday fail-safe, kill switch.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` D1 OHLC, ATR, quotes, spread, symbol metadata, broker
calendar, positions, deals, and terminal global state only.

## Safety Boundary

Approval covers the card, allocation, compile, one RISK_FIXED backtest setfile,
and paced Q02 enqueue. It authorizes no manual backtest, live setfile, T_Live
or AutoTrading action, manifest change, portfolio-gate change, admission, or
correlation claim.
