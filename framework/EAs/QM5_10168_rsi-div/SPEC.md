# QM5_10168 RSI Divergence Reversal

## Strategy Logic

The EA evaluates once per completed D1 bar. It computes RSI(14) and confirms swing pivots with five bars on each side. A long signal requires the most recent two confirmed swing lows to show lower price lows and higher RSI lows, with the newest pivot RSI below the 50 centerline. A short signal requires higher price highs and lower RSI highs, with the newest pivot RSI above the 50 centerline.

Entries are market orders on the next framework entry pass after the confirmed pivot. The entry comment stores the pivot RSI value used at entry. Long exits occur when RSI crosses up through the centerline or, while still below the centerline, falls below the stored entry RSI. Short exits occur when RSI crosses down through the centerline or, while still above the centerline, rises above the stored entry RSI.

Initial stops are structure plus volatility: long stop below the confirming swing low minus 1.0 ATR(14), short stop above the confirming swing high plus 1.0 ATR(14). There is no trailing stop, partial close, or profit target in the card.

## Parameters

| Input | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 14 | 10, 14, 21 test set | RSI lookback period. |
| `strategy_pivot_order` | 5 | 3, 5, 8 test set | Bars required on each side of a confirmed pivot. |
| `strategy_pivot_count_k` | 2 | 2, 3 test set | Consecutive pivots required for divergence. |
| `strategy_centerline` | 50.0 | 45, 50, 55 test set | RSI centerline threshold. |
| `strategy_atr_period` | 14 | fixed by card | ATR period for stop buffer. |
| `strategy_atr_stop_mult` | 1.0 | 0.5, 1.0, 1.5 test set | ATR multiple beyond the confirming pivot. |
| `strategy_warmup_bars` | 60 | >= 1 | Minimum D1 bars before signals are allowed. |
| `strategy_pivot_scan_bars` | 60 | bounded | Maximum D1 bars scanned for recent confirmed pivots. |

## Symbol Universe

Registered symbols are `SP500.DWX`, `NDX.DWX`, and `WS30.DWX`, matching the card's R3 US large-cap DWX basket. `SP500.DWX` is backtest-only and is not broker-routable for T6 live promotion.

## Timeframe

Base timeframe is D1. No secondary timeframe is used.

## Expected Behaviour

The card expects about 15 trades per year per symbol. The strategy is a sparse reversal and mean-reversion model. Pivot confirmation avoids lookahead but enters late, so long flat periods and losing stretches are expected.

## Source Citation

Source ID: `d3c009d7-a8d6-5251-b572-4777b207c2b9`. Source: Raposa, "Test and Trade RSI Divergence in Python", 2021-07-26.

## Risk Model

Backtests use `RISK_FIXED = 1000.0` and `RISK_PERCENT = 0.0`. Live deployment uses the V5 manifest convention of `RISK_PERCENT = 0.5` with `RISK_FIXED = 0.0`.
