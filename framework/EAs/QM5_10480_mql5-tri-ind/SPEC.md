# QM5_10480_mql5-tri-ind - Strategy Spec

**EA ID:** QM5_10480
**Slug:** `mql5-tri-ind`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates a M15 work timeframe only when a new chart bar forms. It opens long when the current open is above the prior open, MACD main is above signal, Stochastic %K is above %D without exceeding 80, and RSI(14) is above 50. It opens short on the mirrored conditions: current open below prior open, MACD main below signal, Stochastic %K below %D without falling below 20, and RSI(14) below 50. Exits occur through a 1.5 x ATR(14) stop, a 2R take profit, an opposite confirmed signal, or after 16 M15 bars.

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

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with standard OHLC and indicator coverage.
- `GBPUSD.DWX` - liquid FX major with standard OHLC and indicator coverage.
- `USDJPY.DWX` - liquid FX major with standard OHLC and indicator coverage.
- `USDCHF.DWX` - liquid FX major with standard OHLC and indicator coverage.
- `USDCAD.DWX` - liquid FX major with standard OHLC and indicator coverage.
- `AUDUSD.DWX` - liquid FX major with standard OHLC and indicator coverage.
- `NZDUSD.DWX` - liquid FX major with standard OHLC and indicator coverage.
- `XAUUSD.DWX` - liquid gold CFD with standard OHLC and indicator coverage.
- `XTIUSD.DWX` - liquid oil CFD with standard OHLC and indicator coverage.
- `SP500.DWX` - S&P 500 custom symbol, valid for backtest coverage.
- `NDX.DWX` - liquid Nasdaq 100 index CFD.
- `WS30.DWX` - liquid Dow 30 index CFD.
- `GDAXI.DWX` - liquid DAX index CFD.
- `UK100.DWX` - liquid FTSE 100 index CFD.

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
| v1 | 2026-05-28 | Initial build from card | 08a9e9c1-7546-4d49-9293-88291dc8cbee |
