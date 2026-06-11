# QM5_10078_gh-rfv-ma-rsi - Strategy Spec

**EA ID:** QM5_10078
**Slug:** gh-rfv-ma-rsi
**Source:** 3b3ec48a-0755-5187-9331-afb36e174175 (see `strategy-seeds/sources/3b3ec48a-0755-5187-9331-afb36e174175/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades an EMA 12/32 crossover with RSI 5 confirmation on the chart timeframe. A long signal occurs when the fast EMA crosses above the slow EMA on the latest closed bar and RSI is at or below 30. A short signal occurs when the slow EMA crosses above the fast EMA on the latest closed bar and RSI is at or above 70. Each trade uses a 30-point stop, a 60-point take profit, and a broker-time limit close at 17:40.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_ema_period` | 12 | `> 0 and < strategy_slow_ema_period` | Fast EMA period on close. |
| `strategy_slow_ema_period` | 32 | `> strategy_fast_ema_period` | Slow EMA period on close. |
| `strategy_rsi_period` | 5 | `> 0` | RSI period on close. |
| `strategy_rsi_oversold` | 30.0 | `0-100` | Long-entry RSI threshold. |
| `strategy_rsi_overbought` | 70.0 | `0-100` | Short-entry RSI threshold. |
| `strategy_sl_points` | 30 | `> 0` | Stop-loss distance in raw MT5 points. |
| `strategy_tp_points` | 60 | `> 0` | Take-profit distance in raw MT5 points. |
| `strategy_limit_close_hour` | 17 | `0-23` | Broker-time hour for the daily timed close. |
| `strategy_limit_close_minute` | 40 | `0-59` | Broker-time minute for the daily timed close. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 target forex major with DWX OHLC data for EMA and RSI.
- `GBPUSD.DWX` - Card R3 target forex major with DWX OHLC data for EMA and RSI.
- `USDJPY.DWX` - Card R3 target forex major with DWX OHLC data for EMA and RSI.
- `XAUUSD.DWX` - Card R3 target metal CFD with DWX OHLC data for EMA and RSI.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - build-time registration is limited to verified DWX symbols.

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
| Trades / year / symbol | `50` |
| Typical hold time | Intraday; closed by TP, SL, or the 17:40 broker-time limit close. |
| Expected drawdown profile | Fixed 30-point stop per entry with framework risk sizing. |
| Regime preference | Trend-following with momentum-pullback confirmation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3b3ec48a-0755-5187-9331-afb36e174175
**Source type:** GitHub source code
**Pointer:** https://github.com/rafaelfvcs/Introduction-to-MetaTrader5-and-MQL5---book/blob/master/MA_CROS_RSI.mq5
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10078_gh-rfv-ma-rsi.md`

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
| v1 | 2026-06-11 | Initial build from card | b4f84dd0-94f3-4d06-bbe8-ed969def92dc |
