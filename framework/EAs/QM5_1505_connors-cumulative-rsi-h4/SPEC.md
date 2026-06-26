# QM5_1505 Connors Cumulative RSI H4

**EA ID:** QM5_1505
**Slug:** connors-cumulative-rsi-h4
**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Build Task:** cc7c5913-3e5-48f8-95f0-a1b18b8343ae

## 1. Strategy Logic

This EA implements a low-frequency Connors-style cumulative RSI pullback model on H4 bars. It sums three closed-bar RSI(2) values. Long entries require cumulative RSI below 30, the closed H4 bar above SMA(200), the closed D1 bar above SMA(50), and the D1 SMA(50) rising versus five D1 bars earlier. Short entries mirror those conditions with cumulative RSI above 270 and both trend filters bearish. Entries are blocked when H4 ATR(14) is not greater than 60% of its 200-sample average ATR. Initial stop distance is 2.0 ATR. TP1 closes 60% of the position at 1.5 ATR. The remaining runner exits when the closed H4 bar crosses back through SMA(5), or after 20 H4 bars.

## 2. Parameters

| Input | Default | Purpose |
| --- | ---: | --- |
| `strategy_rsi_period` | 2 | RSI period used in the cumulative pullback sum. |
| `strategy_cum_rsi_bars` | 3 | Number of closed H4 RSI values summed. |
| `strategy_cum_rsi_long_max` | 30.0 | Maximum cumulative RSI for long pullback entries. |
| `strategy_cum_rsi_short_min` | 270.0 | Minimum cumulative RSI for short pullback entries. |
| `strategy_trend_sma_period` | 200 | H4 SMA trend filter. |
| `strategy_exit_sma_period` | 5 | H4 SMA runner exit trigger. |
| `strategy_d1_sma_period` | 50 | D1 trend confirmation SMA. |
| `strategy_d1_slope_bars` | 5 | D1 SMA lookback used for slope confirmation. |
| `strategy_atr_period` | 14 | ATR period for volatility, stop, and TP sizing. |
| `strategy_atr_baseline_bars` | 200 | ATR samples used for volatility floor baseline. |
| `strategy_atr_floor_mult` | 0.60 | Requires current ATR above this fraction of average ATR. |
| `strategy_atr_sl_mult` | 2.0 | Initial stop distance in ATR. |
| `strategy_atr_tp_mult` | 1.5 | TP1 distance in ATR. |
| `strategy_tp1_close_fraction` | 0.60 | Fraction of the position closed at TP1. |
| `strategy_cooldown_bars` | 16 | Minimum H4 bars between entries on the same symbol. |
| `strategy_time_stop_bars` | 20 | Maximum H4 bars held before time exit. |

## 3. Symbol Universe

Primary Q02 universe is `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX`, `SP500.DWX`, `XAUUSD.DWX`, and `XTIUSD.DWX`. The strategy is intended for liquid FX majors, major equity indices, gold, and crude oil where H4 trend continuation and short pullback mean reversion can both appear. It is not intended for single-stock, thin, or non-DWX symbols without separate validation.

## 4. Timeframe

The trading timeframe is H4. The EA also reads D1 SMA and D1 close values for the higher-timeframe trend and slope filter.

## 5. Expected Behaviour

Expected trade frequency is low to moderate, roughly tens to low hundreds of trades per symbol-year depending on volatility and trend persistence. Holds should usually last from one to twenty H4 bars. The edge should do best in persistent trends with temporary exhaustion pullbacks and should degrade in flat, low-volatility ranges. Risk is fixed through the V5 `RISK_FIXED` setfile mode.

## 6. Source Citation

Built from approved strategy card `QM5_1505_connors-cumulative-rsi-h4`, copied into `docs/strategy_card.md`. The card cites Connors-style cumulative RSI pullback research adapted to a structural multi-asset H4 V5 implementation.

## 7. Risk Model

The EA uses the QuantMechanica V5 fixed-risk path in backtests, with `RISK_FIXED=1000` and `RISK_PERCENT=0` in generated setfiles. Each entry has a broker-side ATR stop. Position sizing, portfolio weight handling, magic resolution, news gating, Friday close, kill switch, and trade logging are delegated to the V5 framework. Revision 2026-06-26: initial mechanical build from approved card for Q02 enqueue.
