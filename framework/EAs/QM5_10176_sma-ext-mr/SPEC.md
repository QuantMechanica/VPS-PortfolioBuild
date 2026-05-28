# QM5_10176 SMA Extension Mean Reversion

## Strategy Logic

The EA evaluates completed D1 bars only. It computes a 20-period simple moving average of D1 closes and measures the extension as `close[1] - SMA20[1]`.

If the extension is negative, the last completed close is below its recent average and the EA enters long. If the extension is positive, the last completed close is above its recent average and the EA enters short. A long exits when the completed close crosses back above the SMA. A short exits when the completed close crosses back below the SMA. If the exit also implies an opposite entry, the EA closes first and skips the immediate same-bar re-entry, so reversal happens no earlier than the following bar.

## Parameters

| Input | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sma_period` | 20 | 10, 20, 30, 50 in P3 | SMA lookback for extension and re-cross exit |
| `strategy_atr_period` | 14 | fixed baseline | ATR period for emergency stop |
| `strategy_atr_sl_mult` | 2.0 | 1.5, 2.0, 2.5, 3.0 in P3 | ATR multiple for emergency stop distance |
| `strategy_entry_atr_thresh` | 0.0 | 0.0, 0.25, 0.50 in P3 | Minimum absolute extension as ATR multiple |
| `strategy_warmup_bars` | 30 | >= 30 | Minimum D1 bars before trading |

## Symbol Universe

The card states the logic is portable to DWX FX, metals, oil, and index CFDs. The build registers the full current DWX matrix: AUDCAD.DWX, AUDCHF.DWX, AUDJPY.DWX, AUDNZD.DWX, AUDUSD.DWX, CADCHF.DWX, CADJPY.DWX, CHFJPY.DWX, EURAUD.DWX, EURCAD.DWX, EURCHF.DWX, EURGBP.DWX, EURJPY.DWX, EURNZD.DWX, EURUSD.DWX, GBPAUD.DWX, GBPCAD.DWX, GBPCHF.DWX, GBPJPY.DWX, GBPNZD.DWX, GBPUSD.DWX, GDAXI.DWX, NDX.DWX, NZDCAD.DWX, NZDCHF.DWX, NZDJPY.DWX, NZDUSD.DWX, SP500.DWX, UK100.DWX, USDCAD.DWX, USDCHF.DWX, USDJPY.DWX, WS30.DWX, XAGUSD.DWX, XAUUSD.DWX, XNGUSD.DWX, XTIUSD.DWX.

SP500.DWX is backtest-only and not broker-routable for T6 live promotion.

## Timeframe

Primary timeframe: D1. No secondary timeframe is used.

## Expected Behaviour

Expected frequency is approximately 45 trades per year per symbol from the approved card. The system is a daily mean-reversion sleeve and is expected to hold positions until price reverts to the SMA or the ATR emergency stop is hit. It should perform best in oscillating or mean-reverting regimes and can suffer during persistent trends.

## Source Citation

Approved source: Raposa / Raposa Technologies, "How to Build Your First Mean Reversion Trading Strategy in Python", 2021-03-01. Card source ID: `d3c009d7-a8d6-5251-b572-4777b207c2b9`.

## Risk Model

Backtests use `RISK_FIXED = 1000.0` and `RISK_PERCENT = 0.0`. Live setfiles must use percent risk via the deployment manifest, with `RISK_PERCENT = 0.5` and `RISK_FIXED = 0.0` after the required pipeline gates.
