---
card_schema_version: 2
ea_id: QM5_20153
slug: wti-thu-trend
type: strategy
strategy_id: QUAY-MOP-WTI-THUTREND-2026_S01
variant_id: QUAY-MOP-WTI-THUTREND-2026_S01
source_id: QUAY-MOP-WTI-THUTREND-2026
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20153_wti-thu-trend_card.md
execution_contract_status: DRAFT
created: 2026-07-25
created_by: Research+Development
strategy_mechanic: thursday-wti-long-only-when-completed-252d-return-is-positive
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
symbol: XTIUSD.DWX
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
q02_status: ENQUEUED
modules_used: [no_trade, trade_entry, trade_management, trade_close]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission: R1 PASS governed peer-reviewed composite packet; R2 PASS genuine Thursday boundary, positive completed 252-D1 return, one BUY, ATR stop, next-D1 exit, and persistent weekly attempt; R3 PASS registered XTIUSD.DWX D1; R4 PASS deterministic native MT5 data only, no ML/grid/martingale. Deterministic dedup CLEAN and manual semantic neighbor review complete."
---

# QM5_20153 WTI Thursday Positive-Trend Long

## Hypothesis

WTI's source-documented positive Thursday return may be more coherent when its
own completed 252-D1 return is also positive. This direct crude-oil calendar
and slow-state interaction differs from the certified index/metal/XNG book.
Diversification remains a later evidence gate, not a card claim.

## Rules

1. Run only on exact `XTIUSD.DWX`, D1, EA 20153, magic slot 0.
2. Evaluate only the first executable tick within five minutes of a Thursday
   D1 bar whose immediately prior completed D1 bar is Wednesday. Do not shift
   holiday-shortened weeks.
3. Persist the Monday-anchored broker-week key as consumed before fallible
   history, signal, spread, quote, news, stop, or order gates. Never retry.
4. Compute `ln(Close[1] / Close[253])`; BUY only when strictly positive.
5. Require completed `ATR(20)`, spread <=1500 points, and attach a frozen
   `3.0 * ATR(20)` hard stop below the executable entry. No take-profit.
6. Close at the first new D1 bar that is not Thursday, immediately on a
   wrong-side position, or after two calendar days. Friday close at broker
   hour 21 remains a fail-safe.
7. One position per magic; no pending order, scale-in, grid, martingale,
   trailing stop, partial close, external data, adaptive fit, or ML.

## Source-Defined Rules

Quayyum et al. supply the positive WTI Thursday direction. Moskowitz et al.
supply the completed 12-month own-return sign. Neither source defines the CFD
attachment, stop, spread, retry, or exit controls.

## QM Interpretations

The exact Thursday-after-Wednesday boundary, five-minute grace, 252 D1 bars,
ATR(20) x 3 stop, 1,500-point spread ceiling, next-D1 exit, and persistent
weekly attempt are frozen pre-result QM execution choices.

## Parameters To Test

| parameter | default | authorized values |
|---|---:|---|
| `strategy_momentum_lookback_d1` | 252 | [252] |
| `strategy_min_abs_return_pct` | 0.0 | [0.0] |
| `strategy_session_offset_min` | 61.6 | [61.6] | XTIUSD.DWX tick-measured maximum |
| `strategy_entry_grace_minutes` | 10 | [10] | tight window around the session-tick anchor |
| `strategy_min_stub_ticks` | 20 | [20] | reject thin weekend/holiday D1 stubs |
| `strategy_min_attach_ticks` | 20 | [20] | minimum ticks within 5 minutes of the qualifying tick |
| `strategy_atr_period` | 20 | [20] |
| `strategy_atr_sl_mult` | 3.0 | [3.0] |
| `strategy_max_hold_days` | 2 | [2] |
| `strategy_max_spread_points` | 1500 | [1500] |

## Risk And Falsification

Backtest only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`. Retire below five completed packages/year; fail any
wrong-day, non-positive-trend, repeated-week, missing-stop, late-exit, risk-mode,
PF, or DD gate. No correlation waiver or post-result baseline mutation.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked inputs, news OFF, Friday close, and
  identity guards.
- trade_entry: genuine Thursday-after-Wednesday, positive completed 252-D1
  return, consumed-week state, spread/quote/ATR validation, one BUY.
- trade_management: first non-Thursday, wrong-side, and two-day stale closes.
- trade_close: V5 close path, hard stop, Friday fail-safe, kill switch.

## Framework Execution Overrides

News temporal mode OFF, compliance NONE, legacy mode OFF; Friday close enabled
at broker hour 21; framework risk sizing, hard stop, and kill switch remain
authoritative.

## Exit Precedence

1. Framework kill switch and server-side hard stop.
2. First non-Thursday D1 boundary or wrong-side cleanup.
3. Two-calendar-day stale close.
4. Friday-close fail-safe.

## Runtime Data Dependencies

Exact `XTIUSD.DWX` D1 OHLC, ATR, quotes, spread, symbol metadata, broker
calendar, positions, deals, and terminal global state only.

## Falsification And Requalification

Any change to weekday, prior-day boundary, direction, momentum horizon/sign,
entry grace, stop, hold, spread, retry state, symbol, timeframe, or risk mode
requires a new binary and full pipeline requalification.

## Safety Boundary

This approval covers the card, deterministic allocation, compile, one
RISK_FIXED backtest setfile, and paced Q02 enqueue. It authorizes no manual
backtest, live setfile, T_Live or AutoTrading action, deploy/T_Live manifest,
portfolio-gate change, portfolio admission, or correlation claim.

## OWNER-approved session-tick entry-clock amendment (2026-08-16)

This amendment supersedes every earlier raw-D1-label/five-minute entry-clock
description in this card. No formation, signal, direction, exit, sizing,
risk, consumed-attempt, or original advance/never-shift mechanic changes.

- Anchor the qualifying window at
  `D1_bar_open + strategy_session_offset_min`, not the raw D1 label.
- `strategy_session_offset_min = 61.6` minutes: conservative tick-measured maximum for `XTIUSD.DWX`.
- `strategy_entry_grace_minutes = 10`, measured tightly around that anchor.
- `strategy_min_stub_ticks = 20`; a thin weekend/holiday D1 stub consumes
  the card's original attempt/date/window flat.
- `strategy_min_attach_ticks = 20` within five minutes after the qualifying
  tick; failure consumes the original attempt/date/window flat.
- Preserve this card's existing advance-versus-never-shift semantics exactly.
