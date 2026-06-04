# QM5_10480_mql5-tri-ind - Strategy Spec

**EA ID:** QM5_10480
**Slug:** `mql5-tri-ind`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-04

---

## 1. Strategy Logic

The EA evaluates the configured work timeframe, default M15, from the framework new-bar entry gate. It opens long when the current open is above the prior open, MACD main is above signal, Stochastic %K is above %D without exceeding 80, and RSI(14) is above 50. It opens short on the mirrored conditions: current open below prior open, MACD main below signal, Stochastic %K below %D without falling below 20, and RSI(14) below 50. Exits occur through a 1.5 x ATR(14) stop, a 2R take profit, an opposite confirmed signal, or after 16 M15 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_work_tf` | `PERIOD_M15` | MT5 timeframe enum | Work timeframe for open, MACD, Stochastic, RSI, ATR, and time-stop checks. |
| `strategy_macd_fast` | `12` | `1+` and below slow | MACD fast EMA period. |
| `strategy_macd_slow` | `26` | above fast | MACD slow EMA period. |
| `strategy_macd_signal` | `9` | `1+` | MACD signal period. |
| `strategy_stoch_k` | `5` | `1+` | Stochastic %K period. |
| `strategy_stoch_d` | `3` | `1+` | Stochastic %D period. |
| `strategy_stoch_slowing` | `3` | `1+` | Stochastic slowing period. |
| `strategy_stoch_long_max` | `80.0` | `0-100` | Long entries require %K at or below this ceiling. |
| `strategy_stoch_short_min` | `20.0` | `0-100` | Short entries require %K at or above this floor. |
| `strategy_rsi_period` | `14` | `1+` | RSI period. |
| `strategy_rsi_midline` | `50.0` | `0-100` | RSI long/short split level. |
| `strategy_atr_period` | `14` | `1+` | ATR period for stop placement. |
| `strategy_atr_sl_mult` | `1.5` | `>0` | ATR multiple used for stop loss distance. |
| `strategy_tp_rr` | `2.0` | `>0` | Take-profit reward-to-risk multiple. |
| `strategy_time_stop_bars` | `16` | `0+` | Maximum hold time measured in work-timeframe bars; 0 disables. |
| `strategy_max_spread_points` | `80` | `0+` | Maximum current spread in points; 0 disables the strategy spread guard. |

---

## 3. Symbol Universe

**Designed for:**
- `AUDCAD.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `AUDCHF.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `AUDJPY.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `AUDNZD.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `AUDUSD.DWX` - verified DWX forex major with OHLC and standard indicator coverage.
- `CADCHF.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `CADJPY.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `CHFJPY.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `EURAUD.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `EURCAD.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `EURCHF.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `EURGBP.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `EURJPY.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `EURNZD.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `EURUSD.DWX` - verified DWX forex major with OHLC and standard indicator coverage.
- `GBPAUD.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `GBPCAD.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `GBPCHF.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `GBPJPY.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `GBPNZD.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `GBPUSD.DWX` - verified DWX forex major with OHLC and standard indicator coverage.
- `GDAXI.DWX` - verified DWX DAX index CFD with OHLC and standard indicator coverage.
- `NDX.DWX` - verified DWX Nasdaq 100 index CFD with OHLC and standard indicator coverage.
- `NZDCAD.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `NZDCHF.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `NZDJPY.DWX` - verified DWX forex cross with OHLC and standard indicator coverage.
- `NZDUSD.DWX` - verified DWX forex major with OHLC and standard indicator coverage.
- `SP500.DWX` - verified custom S&P 500 symbol for backtests with OHLC and standard indicator coverage.
- `UK100.DWX` - verified DWX FTSE 100 index CFD with OHLC and standard indicator coverage.
- `USDCAD.DWX` - verified DWX forex major with OHLC and standard indicator coverage.
- `USDCHF.DWX` - verified DWX forex major with OHLC and standard indicator coverage.
- `USDJPY.DWX` - verified DWX forex major with OHLC and standard indicator coverage.
- `WS30.DWX` - verified DWX Dow 30 index CFD with OHLC and standard indicator coverage.
- `XAGUSD.DWX` - verified DWX silver CFD with OHLC and standard indicator coverage.
- `XAUUSD.DWX` - verified DWX gold CFD with OHLC and standard indicator coverage.
- `XNGUSD.DWX` - verified DWX natural gas CFD with OHLC and standard indicator coverage.
- `XTIUSD.DWX` - verified DWX oil CFD with OHLC and standard indicator coverage.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no verified DWX data target exists.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | `up to 16 M15 bars, about 4 hours` |
| Expected drawdown profile | moderate intraday drawdown controlled by ATR stop and one-position-per-magic behavior |
| Regime preference | momentum confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/22550`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10480_mql5-tri-ind.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-04 | Initial build from card | c876e89c-8cc6-4b59-aeb4-1033f763de8e |
