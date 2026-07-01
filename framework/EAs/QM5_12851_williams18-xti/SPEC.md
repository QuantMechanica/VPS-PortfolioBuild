# QM5_12851_williams18-xti - Strategy Spec

**EA ID:** QM5_12851  
**Slug:** `williams18-xti`  
**Source:** `SRC03` / `SRC03_S12_XTI_20260701`  
**Symbol:** `XTIUSD.DWX`  
**Timeframe:** D1

## 1. Strategy Logic

Single-symbol WTI continuation EA based on Williams' 18-bar two-bar moving
average entry. On each new D1 bar, the EA checks the prior two completed bars.
If both lows are above their respective 18-day close SMA values and neither bar
is an inside day, the EA places a buy stop through the two-bar high. If both
highs are below their respective 18-day close SMA values and neither bar is an
inside day, the EA places a sell stop through the two-bar low.

This is not the Williams prior-range volatility breakout (`QM5_12842`), because
entry is based on two closed bars relative to an 18-day SMA rather than an
open-plus-prior-range breakout. It is not XTI/XNG ratio, XNG RSI, WTI/Brent
spread, calendar seasonality, inventory, roll, or metal/index exposure.

## 2. Parameters

- `strategy_ma_period=18`
- `strategy_atr_period=20`
- `strategy_atr_sl_mult=2.5`
- `strategy_take_rr=2.0`
- `strategy_entry_buffer_points=2`
- `strategy_order_expiry_bars=3`
- `strategy_max_hold_days=10`
- `strategy_max_spread_points=1000`

## 3. Symbol Universe

- Host and traded symbol: `XTIUSD.DWX`.
- Magic slot 0: `128510000`.
- No basket legs, synthetic symbols, external CSV/API data, futures curve,
  volume, open interest, inventory feed, or live-only symbol dependency.

## 4. Timeframe

- D1 only.
- The EA blocks non-D1 charts and non-`XTIUSD.DWX` symbols.
- Signal reads use the last two completed D1 bars, with SMA and ATR read
  through pooled framework indicator helpers.

## 5. Expected Behaviour

- Expected frequency before Q02: approximately 8-18 packages per year.
- Entry orders are pending stop orders through the two-bar extreme.
- Pending orders expire after `strategy_order_expiry_bars` D1 bars.
- Open positions close after `strategy_max_hold_days`.
- Framework Friday close remains enabled.
- No grid, martingale, pyramiding, partial close, external feed, or ML.

## 6. Source Citation

Williams, Larry R. (1999). *Long-Term Secrets to Short-Term Trading*. Wiley
Trading. Local SRC03 source packet, slot S12, `raw/probe_pp15-30.txt`, PDF p.17,
18-Bar Two-Bar MA Entry.

## 7. Risk Model

- Q02 backtest risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- `PORTFOLIO_WEIGHT=1`.
- Hard stop: `strategy_atr_sl_mult * ATR(strategy_atr_period)`.
- Optional take-profit: fixed R multiple from entry to stop when
  `strategy_take_rr > 0`.
- The build does not configure `T_Live`, AutoTrading, deploy manifests,
  portfolio admission, or the portfolio gate.
