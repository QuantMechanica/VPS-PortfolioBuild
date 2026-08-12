---
card_schema_version: 2
ea_id: QM5_20163
slug: xng-thu-trend
type: strategy
strategy_id: BOROWSKI-MOP-XNG-THUTREND-2026_S01
variant_id: BOROWSKI-MOP-XNG-THUTREND-2026_S01
source_id: BOROWSKI-MOP-XNG-THUTREND-2026
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20163_xng-thu-trend_card.md
execution_contract_status: DRAFT
created: 2026-07-26
created_by: Codex
strategy_mechanic: thursday-xng-short-only-when-completed-252d-return-is-negative
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
symbol: XNGUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 12-30 Thursday packages/year; Q02 must prove >=5/year."
expected_trades_per_year_per_symbol: 20
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_STARTED
modules_used: [no_trade, trade_entry, trade_management, trade_close]
review_focus: "Falsify a direct XNG Thursday/negative-trend return stream distinct from the certified RSI2 commodity pullback; no decorrelation claim before Q09."
g0_approval_reasoning: "OWNER commodity/energy sleeve mission: R1 PASS governed academic weekday and futures-momentum sources; R2 PASS locked Thursday XNG short gated by negative completed 252-D1 return, ATR stop, next-bar exit and consumed week; R3 PASS registered XNGUSD.DWX D1; R4 PASS native deterministic arithmetic onl"
last_updated: 2026-07-25
---

# QM5_20163 XNG Thursday Negative-Trend Short

## Hypothesis

The source-documented negative XNG Thursday effect may be more coherent when
XNG's completed 252-D1 return is also negative. This calendar/trend
interaction adds a direct energy return driver, not another index/metal
signal. Diversification remains a downstream evidence question.

## Rules

1. Run only on `XNGUSD.DWX`, D1, EA 20163, magic slot 0.
2. On the first executable tick within five minutes of a Thursday D1 bar
   whose immediately prior completed D1 bar is Wednesday, consume the
   Monday-anchored broker-week attempt before any fallible gate.
3. Compute `ln(Close[1] / Close[253])`; SELL only when strictly negative.
4. Require completed `ATR(20)`, spread <=2500 points, and attach a frozen
   `3.0 * ATR(20)` hard stop above entry. No take-profit.
5. Close on the first new D1 bar that is not Thursday, a wrong-side position,
   or after two calendar days. Friday close at broker hour 21 is a fail-safe.
6. One position per magic; no retry, pending order, grid, martingale,
   scale-in, partial close, trailing stop, external data, adaptive fit, or ML.

## Source-Defined Rules

Meek and Hoelscher supply the negative Thursday XNG direction. Moskowitz,
Ooi, and Pedersen supply the completed 12-month own-return sign. Neither
source defines their conjunction or QM execution controls.

## QM Interpretations

The exact Thursday-after-Wednesday boundary, five-minute grace, 252 D1 bars,
ATR(20) x3 stop, 2500-point spread cap, next-D1 exit, and persistent consumed
week are frozen pre-result choices.

## Parameters To Test

| parameter | default | authorized values |
|---|---:|---|
| `strategy_momentum_lookback_d1` | 252 | [252] |
| `strategy_min_abs_return_pct` | 0.0 | [0.0] |
| `strategy_entry_grace_minutes` | 5 | [5] |
| `strategy_atr_period` | 20 | [20] |
| `strategy_atr_sl_mult` | 3.0 | [3.0] |
| `strategy_max_hold_days` | 2 | [2] |
| `strategy_max_spread_points` | 2500 | [2500] |

## Risk And Falsification

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`. Retire below five trades/year or on any wrong-day,
non-negative-trend, retry, stop, timing, risk, PF, or DD failure. No
correlation waiver or post-result baseline mutation.

## Framework Alignment

- no_trade: exact host/timeframe/identity and locked-input guards.
- trade_entry: genuine Thursday, negative completed 252-D1 return, persistent
  consumed-week state, spread/quote/ATR validation, one SELL.
- trade_management: first non-Thursday, wrong-side, and stale closes.
- trade_close: framework close path, hard stop, Friday fail-safe, kill switch.

## Framework Execution Overrides

News modes OFF; Friday close enabled at broker hour 21; framework fixed-risk
sizing, hard stop, and kill switch remain authoritative.

## Exit Precedence

1. Framework kill switch and server-side hard stop.
2. First non-Thursday boundary or wrong-side cleanup.
3. Two-calendar-day stale close.
4. Friday-close fail-safe.

## Runtime Data Dependencies

Native XNG D1 OHLC, ATR, quotes, spread, symbol metadata, broker calendar,
positions, deals, and terminal global state only.

## Falsification And Requalification

Any change to weekday, direction, trend horizon/sign, entry grace, stop,
hold, spread, retry state, symbol, timeframe, or risk mode requires a new
binary and full requalification.

## Safety Boundary

This card permits build, compile, one fixed-risk backtest set, and paced Q02
enqueue only. It authorizes no manual backtest, live setfile, T_Live action,
manifest change, portfolio-gate change, or portfolio admission.
