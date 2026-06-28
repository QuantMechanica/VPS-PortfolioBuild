# QM5_12757 Abraham WTI Breakout Pullback

## Identity

- EA ID: `12757`
- Slug: `abraham-xti-pb`
- Source ID: `ABRAHAM-TREND-BIBLE-2012`
- Symbol: `XTIUSD.DWX`
- Timeframe: `D1`
- Risk mode: `RISK_FIXED`

## Strategy

The EA implements the Abraham retracement-entry variant: first confirm a
20-day channel breakout with MACD(12,26,9) on the correct side of zero, then
wait for a later completed D1 bar to pull back to the old breakout boundary
and close back on the breakout side.

## Entry

- Long setup: closed D1 close > previous 20-day high and MACD main > 0.
- Short setup: closed D1 close < previous 20-day low and MACD main < 0.
- Long entry: later closed D1 low touches the stored high-boundary and the bar
  closes at or above that boundary.
- Short entry: later closed D1 high touches the stored low-boundary and the bar
  closes at or below that boundary.
- Setups expire after `strategy_setup_max_days`.
- One open position per magic/symbol.

## Risk And Exit

- Initial SL: 10-day structural low for longs, 10-day structural high for
  shorts.
- ATR trail: activate after at least 1 ATR favorable movement, then trail with
  ATR(39) x 3.0.
- Stale-position guard: close after `strategy_max_hold_days`.
- No fixed TP, no grid, no martingale, no pyramiding.

## Framework Guards

- Symbol/timeframe guard: `XTIUSD.DWX` on `D1` only.
- Magic slot: slot 0 only.
- News, Friday close, kill-switch, risk model, and equity stream are delegated
  to the V5 framework.
- Runtime data is MT5 OHLC plus pooled framework MACD/ATR readers only.
