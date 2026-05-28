# QM5_10357 et-downgap-close

## Strategy logic

Long-only daily gap reversion. On a new D1 bar, the EA checks the last three closed D1 bars. It enters long when two consecutive strict down gaps exist:

- bar 2 high is below bar 3 low
- bar 1 high is below bar 2 low

The entry is a market buy on the next session open. The EA uses a protective ATR stop and exits the entry-day position at the configured broker close proxy.

## Parameters

| Input | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | `>0` | D1 ATR period for protective stop. |
| `strategy_atr_sl_mult` | 1.0 | `>0` | ATR multiple below entry for long stop. |
| `strategy_spread_lookback` | 20 | 3-64 effective | D1 spread samples used for median spread filter. |
| `strategy_max_spread_mult` | 2.5 | `>0` | Skip entry when current spread exceeds this multiple of median spread. |
| `strategy_close_hour_broker` | 23 | 0-23 intended | Broker-time hour for same-day close proxy. |
| `strategy_close_minute_broker` | 55 | 0-59 intended | Broker-time minute for same-day close proxy. |

## Symbol universe

Designed for the R3 basket from the approved card: `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, and `EURUSD.DWX`. The card names `GER40.DWX`; the registered DWX matrix has `GDAXI.DWX` for DAX exposure, so that is the build-time port.

## Timeframe

Base timeframe is `D1`. The signal and ATR stop both read D1 data.

## Expected behaviour

The card expects about 18 trades per year per symbol. Hold time is intraday: from next session open to same broker day close proxy. The strategy is short-horizon mean reversion after repeated bearish gaps and is vulnerable to downside continuation after adverse news.

## Source citation

Elite Trader thread, "Easylanguage question", posts by `intradaybill`, with implementation comments by `syswizard` and `Pro_Trader720`, 2008-03-06/2008-03-07.

## Risk model

Backtest risk uses `RISK_FIXED = 1000` and `RISK_PERCENT = 0`. Live promotion uses the V5 live convention via setfile or manifest: percent risk, normally 0.5%, after full pipeline approval.
