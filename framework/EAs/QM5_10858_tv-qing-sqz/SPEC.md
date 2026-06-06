# QM5_10858_tv-qing-sqz - Strategy Spec

**EA ID:** QM5_10858
**Slug:** `tv-qing-sqz`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see approved card artifact)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades long-only EMA squeeze breakouts on the current chart timeframe. A setup requires EMA(6), EMA(12), and EMA(20) to have been tightly compressed on the prior closed bar, then the latest closed bar must close above EMA(6), EMA(12), EMA(20), and EMA(200). The entry also requires MACD to be bullish and tick volume to exceed its moving average by the configured multiplier. Exits are handled by ATR stop and target at entry, plus discretionary close when the latest closed bar closes below EMA(20), MACD crosses bearish, or the position has been open for 24 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_6_period` | 6 | 1-200 | Fast squeeze EMA period. |
| `strategy_ema_12_period` | 12 | 1-200 | Middle squeeze EMA period. |
| `strategy_ema_20_period` | 20 | 1-200 | Slow squeeze EMA and close-exit period. |
| `strategy_ema_50_period` | 50 | 1-300 | Supplemental EMA required by the card and checked for data readiness. |
| `strategy_ema_100_period` | 100 | 1-400 | Supplemental EMA required by the card and checked for data readiness. |
| `strategy_ema_200_period` | 200 | 1-500 | Long trend EMA period for current and optional higher timeframe filters. |
| `strategy_squeeze_tight_pct` | 0.50 | 0.25-0.75 | Maximum EMA(6/12/20) spread percentage for squeeze detection. |
| `strategy_macd_fast` | 12 | 1-50 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | 2-100 | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 1-50 | MACD signal period. |
| `strategy_volume_sma_period` | 20 | 1-100 | Lookback for tick-volume SMA confirmation. |
| `strategy_volume_multiplier` | 1.5 | 1.2-2.0 | Required tick-volume spike multiple. |
| `strategy_htf_filter_enabled` | false | true or false | Enables optional higher timeframe close above EMA(200). |
| `strategy_htf_filter_tf` | PERIOD_H4 | H4 or D1 | Higher timeframe used when the optional filter is enabled. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for entry stop and target. |
| `strategy_atr_sl_mult` | 1.5 | 1.0-2.0 | ATR multiplier for initial stop loss. |
| `strategy_atr_tp_mult` | 3.0 | 2.0-4.0 | ATR multiplier for initial take profit. |
| `strategy_max_spread_stop_pct` | 15.0 | 1-50 | Blocks entries when spread exceeds this percentage of stop distance. |
| `strategy_time_exit_bars` | 24 | 1-200 | Maximum holding period in bars before discretionary close. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed FX major with DWX tick volume and OHLC available.
- `GBPUSD.DWX` - Card-listed FX major with DWX tick volume and OHLC available.
- `XAUUSD.DWX` - Card-listed liquid metal CFD with DWX tick volume and OHLC available.
- `NDX.DWX` - Card-listed US index CFD with DWX tick volume and OHLC available.
- `GDAXI.DWX` - Matrix-backed DAX symbol used for the card's `GER40.DWX` exposure, because `GER40.DWX` is not present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in the DWX symbol matrix.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - Not canonical DWX S&P 500 symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 and H4 |
| Multi-timeframe refs | Optional H4 or D1 close above EMA(200), disabled by default |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 55 |
| Typical hold time | Up to 24 bars unless ATR stop, ATR target, EMA20 close, or MACD close exits first |
| Expected drawdown profile | Moderate breakout drawdown from delayed entries and failed squeeze expansions |
| Regime preference | Volatility-expansion breakout in trend-confirmed markets |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source script
**Pointer:** TradingView script `Qing (EMA + MACD + Squeeze)`, author handle `Z8830`, Apr 16, https://www.tradingview.com/script/PxAUrVvp-Qing-EMA-MACD-Squeeze/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10858_tv-qing-sqz.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | e37d0a5f-59b3-48db-8869-fabf92fe84ba |
