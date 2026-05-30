# QM5_10304 narang-revert

## Strategy logic

This EA implements the approved Narang Price Reversion Band Fade card. On each completed H4 bar it computes Bollinger Bands(20, 2.0), RSI(14), ATR(14), EMA(200), and ADX(14). It enters long when the close is below the lower Bollinger band, RSI is <= 30, ADX is <= 28, and the close is within 1.5 ATR of the EMA(200). It enters short on the symmetric upper-band condition with RSI >= 70. It holds at most one open position per magic number.

Long positions exit when the completed H4 close reaches or exceeds the Bollinger middle band, or after 12 H4 bars. Short positions exit when the completed H4 close reaches or falls below the Bollinger middle band, or after 12 H4 bars. Broker stop loss is placed at 1.8 ATR from entry. The EA does not average down, grid, trail, scale, or use adaptive parameters.

## Parameters

| Input | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | H4 expected | Signal timeframe. |
| `strategy_bb_period` | 20 | > 1 | Bollinger lookback. |
| `strategy_bb_deviation` | 2.0 | > 0 | Bollinger deviation multiplier. |
| `strategy_rsi_period` | 14 | > 1 | RSI lookback. |
| `strategy_rsi_long_level` | 30.0 | 0-100 | Long oversold threshold. |
| `strategy_rsi_short_level` | 70.0 | 0-100 | Short overbought threshold. |
| `strategy_atr_period` | 14 | > 0 | ATR lookback for stop and EMA distance. |
| `strategy_atr_stop_mult` | 1.8 | > 0 | Initial ATR stop multiplier. |
| `strategy_ema_period` | 200 | > 1 | Mean anchor EMA. |
| `strategy_ema_atr_band` | 1.5 | > 0 | Maximum close-to-EMA distance in ATR units. |
| `strategy_adx_period` | 14 | > 0 | ADX trend-filter lookback. |
| `strategy_adx_max` | 28.0 | > 0 | Skip entries above this ADX. |
| `strategy_max_hold_bars` | 12 | > 0 | Maximum H4 bars in trade. |
| `strategy_warmup_bars` | 230 | > EMA period | Minimum available bars before trading. |
| `strategy_max_spread_points` | 0 | >= 0 | Optional spread block; 0 leaves framework defaults. |

## Symbol universe

The approved card says the best initial universe is range-prone FX majors/crosses and selected indices. Build registration uses all available DWX forex symbols plus SP500.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX, and UK100.DWX. Commodities and energy symbols are not registered for this EA because the card did not name them in its preferred initial universe.

## Timeframe

Base timeframe is H4. Entries, middle-band exits, ATR stops, EMA distance, RSI, Bollinger, and ADX are all read from H4 by default.

## Expected behaviour

The card estimates about 35 trades per year per symbol. The strategy is a mean-reversion profile: it seeks stretched prices in non-strong-trend regimes and exits on reversion to the Bollinger middle band or after a 12-bar time stop. Tail risk is persistent trend continuation, mitigated by the ADX filter and ATR stop.

## Source citation

Source ID: `0f051e46-12b2-51f3-aad5-d6d8bd3e9b35`. Approved source: Rishi K. Narang, *Inside the Black Box*, Chapter 3 section 3.2, O'Reilly preview.

## Risk model

Backtests use fixed risk through `RISK_FIXED = 1000.0` and `RISK_PERCENT = 0.0`. Live promotion uses the V5 live convention of percent risk, set by deploy manifest and live setfile, with `RISK_PERCENT = 0.5` and fixed risk disabled.
