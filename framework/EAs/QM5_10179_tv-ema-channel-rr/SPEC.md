# QM5_10179 tv-ema-channel-rr

## Strategy Logic

H1 long/short EMA channel breakout from TradingView `IU EMA Channel Strategy`.
The EA computes EMA(100) on highs and EMA(100) on lows. It buys when the last
closed H1 close crosses above EMA(high) and sells when it crosses below
EMA(low). No pyramiding is allowed; the framework rejects duplicate positions
for the same magic and symbol.

Stops use the previous H1 bar low for longs and previous H1 bar high for
shorts. If the stop distance is less than 0.5 ATR(14), the stop is widened to
0.5 ATR(14). If the previous-bar stop distance exceeds 3.0 ATR(14), the trade
is skipped. Take profit is fixed at 2.0R. Positions still open after 72 H1 bars
are closed by the strategy exit hook.

## Parameters

| Input | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | MT5 timeframe | Signal timeframe. |
| `strategy_ema_period` | `100` | `>1` | EMA period for high/low channel. |
| `strategy_atr_period` | `14` | `>0` | ATR period for stop constraints. |
| `strategy_min_stop_atr` | `0.5` | `>0` | Minimum stop distance as ATR multiple. |
| `strategy_max_stop_atr` | `3.0` | `>0` | Maximum previous-bar stop distance as ATR multiple. |
| `strategy_take_profit_rr` | `2.0` | `>0` | Take-profit reward/risk multiple. |
| `strategy_max_hold_bars` | `72` | `>0` | Time exit in signal-timeframe bars. |
| `strategy_max_spread_frac` | `0.15` | `>=0` | Maximum spread as fraction of planned stop distance. |

## Symbol Universe

Card symbols: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `XAUUSD.DWX`,
`GER40.DWX`. The DWX matrix does not contain `GER40.DWX`; this build registers
`GDAXI.DWX`, the available DAX 40 canonical symbol.

## Timeframe

Primary timeframe is H1. There are no multi-timeframe references.

## Expected Behaviour

The card expects about 90 trades per year per symbol. Behaviour should be
trend-following/momentum breakout around the EMA high/low channel, with a
maximum intended hold of 72 hours plus broker SL/TP exits.

## Source Citation

TradingView script `IU EMA Channel Strategy`, author handle `Shivam_Mandrai`,
published 2024-12-15.

## Risk Model

Backtests use fixed risk via `RISK_FIXED=1000` and `RISK_PERCENT=0`. Live
deployment uses percent risk through live setfiles and signed manifest policy.
