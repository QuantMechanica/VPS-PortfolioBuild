# QM5_11646_robo-rsi8-pending-d1 - Strategy Spec

**EA ID:** QM5_11646

**Slug:** robo-rsi8-pending-d1

**Source ID:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d

**Last revised:** 2026-08-07

## 1. Strategy Logic

On the first executable tick of each D1 bar, the EA reads RSI(8) from the
completed bar at shift 1. The approved card permits either a live bar-0 read or
a confirmed bar-1 read; this build chooses bar 1 for deterministic backtests.

- When RSI(8) is above 70, place one buy stop exactly 20 pips above the current
  D1 open.
- When RSI(8) is below 30, place one sell stop exactly 20 pips below the current
  D1 open.
- The pending breakout fill is the entry event. If price already passed the
  specified stop before the first executable tick, skip the order instead of
  converting it into a market entry.
- An unfilled pending order expires at the current D1 bar close. The next D1
  bar also removes any stale order before evaluating a new setup.
- A filled position has a hard stop at 2 times completed-bar ATR(14) and a hard
  target at 4 times ATR(14), both measured from the pending fill price.

There is at most one position and one pending order per symbol-specific magic.
There is no discretionary close, trailing stop, break-even, partial close,
grid, martingale, adaptive parameter, or machine-learning component.

## 2. Parameters

| Parameter | Default | Authorized Q01 value | Meaning |
|---|---:|---:|---|
| strategy_rsi_period | 8 | 8 | completed-bar RSI period |
| strategy_rsi_buy_level | 70.0 | 70.0 | buy-stop setup threshold; strict greater-than |
| strategy_rsi_sell_level | 30.0 | 30.0 | sell-stop setup threshold; strict less-than |
| strategy_breakout_offset_pips | 20 | 20 | distance from current D1 open, scaled by the framework pip helper |
| strategy_atr_period | 14 | 14 | completed-bar ATR period for stop and target |
| strategy_sl_atr_mult | 2.0 | 2.0 | hard-stop ATR multiple from fill |
| strategy_tp_atr_mult | 4.0 | 4.0 | hard-target ATR multiple from fill |

The card defines fixed factory values and no approved P3 search range, so this
build fails closed if any strategy value is changed.

## 3. Symbol Universe

The approved portable FX basket and deterministic magic slots are:

| Symbol | Slot | Magic |
|---|---:|---:|
| EURUSD.DWX | 0 | 116460000 |
| GBPUSD.DWX | 1 | 116460001 |
| AUDUSD.DWX | 2 | 116460002 |
| USDJPY.DWX | 3 | 116460003 |
| USDCAD.DWX | 4 | 116460004 |

The framework pip conversion preserves the card's 20-pip distance for both
five-decimal non-JPY pairs and three-decimal JPY quoting. The EA fails closed
for every symbol outside this table and for any mismatched symbol slot.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe references | none |
| Signal data | completed D1 bar, shift 1 |
| Pending reference | current D1 open, shift 0 |
| Bar gating | `QM_IsNewBar()` |

The configuration guard rejects every timeframe other than D1.

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades per year per symbol | approximately 25, per approved-card prior |
| Pending lifetime | less than one D1 bar |
| Position hold time | hours to several days, until fixed SL or TP |
| Regime preference | directional momentum and volatility expansion |
| Win-rate profile | may be below 50 percent because the target is 2R |

These values are hypotheses for Q02 measurement, not certified performance.
The D1 cadence is intentionally low frequency and each symbol is evaluated as
an independent sleeve candidate.

## 6. Source Citation

RoboForex Educational Team, *Forex Strategy Collection* (approximately 2015),
strategy "RSI Pending", page 115. Local source pointer:
`362359657-Robo-forex-strategy.pdf`.

The durable source ID is `ed246754-1f4d-5bed-8dd3-3b5cbf1b420d`. The approved
card records R1, R2, R3, and R4 as PASS: institutional publisher attribution,
deterministic rules, available D1 DWX data, and no ML or martingale.

## 7. Risk Model

Backtest setfiles use `RISK_PERCENT=0`, `RISK_FIXED=1000`, and
`PORTFOLIO_WEIGHT=1`. The framework sizes every filled pending order from its
hard 2 times ATR stop, so the dollar risk budget does not depend on the pair's
quote precision. The 4 times ATR target is fixed at order creation and the EA
never widens or mutates either protective level.

The source card names 0.5 percent as its live convention, but this build creates
no live setfile and grants no live authorization. No T_Live action, AutoTrading
action, deploy manifest, portfolio-gate edit, or T_Live manifest edit is part of
this unit.

## Build History

| Version | Date | Event |
|---|---|---|
| 5.1 | 2026-08-07 | Rebuilt the approved D1 RSI-pending strategy under the current V5 framework contract |
