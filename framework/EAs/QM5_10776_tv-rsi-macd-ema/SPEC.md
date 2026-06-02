# QM5_10776_tv-rsi-macd-ema - Strategy Spec

**EA ID:** QM5_10776
**Slug:** `tv-rsi-macd-ema`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView script citation below)
**Author of this spec:** Codex
**Last revised:** 2026-06-01

---

## 1. Strategy Logic

The EA trades a closed-bar confluence signal on the chart timeframe. A long signal requires RSI above 50, a MACD main-line cross above the signal line, the last closed close above the EMA, and tick volume greater than the prior bar or above its 20-bar average. A short signal mirrors those rules below RSI 50, below EMA, and with a bearish MACD cross. Entries use an ATR(14) stop-loss at 1.0x ATR and a take-profit at 1.5x the stop distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 2-100 | RSI period used for the 50-line momentum check. |
| `strategy_rsi_midline` | 50.0 | 1-99 | RSI threshold separating long and short bias. |
| `strategy_macd_fast` | 12 | 1-100 | Fast EMA length for MACD. |
| `strategy_macd_slow` | 26 | 2-200 | Slow EMA length for MACD; must exceed fast length. |
| `strategy_macd_signal` | 9 | 1-100 | MACD signal smoothing length. |
| `strategy_ema_period` | 20 | 2-300 | EMA trend filter period. |
| `strategy_volume_sma_period` | 20 | 2-200 | Tick-volume average window. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for stop distance and spread filter. |
| `strategy_atr_sl_mult` | 1.0 | 0.1-10.0 | ATR multiplier for stop-loss distance. |
| `strategy_take_profit_rr` | 1.5 | 0.1-10.0 | Take-profit as a multiple of stop distance. |
| `strategy_max_spread_atr` | 0.20 | 0.0-1.0 | Blocks entries when spread exceeds this fraction of ATR. |
| `strategy_session_enabled` | true | true/false | Enables the broker-time session gate. |
| `strategy_session_start_h` | 7 | 0-23 | Session start hour in broker time. |
| `strategy_session_end_h` | 20 | 0-23 | Session end hour in broker time. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 FX symbol with RSI, MACD, EMA, tick volume, ATR, and OHLC available.
- `GBPUSD.DWX` - card R3 FX symbol with the same portable indicator set.
- `USDJPY.DWX` - card R3 FX symbol with the same portable indicator set.
- `XAUUSD.DWX` - canonical DWX metal symbol for the card's `XAUUSD` R3 entry.
- `GDAXI.DWX` - matrix-listed DAX equivalent for the card's unavailable `GER40.DWX`.
- `NDX.DWX` - card R3 index symbol with the same portable indicator set.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `XAUUSD` - missing the required `.DWX` custom-symbol suffix; use `XAUUSD.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `160` |
| Typical hold time | Scalping-style holds, typically minutes to a few hours when SL/TP is reached. |
| Expected drawdown profile | High-frequency confluence strategy with spread sensitivity controlled by M5 and the ATR spread filter. |
| Regime preference | Momentum confirmation with EMA trend filter. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy script
**Pointer:** `https://www.tradingview.com/script/DasYJGIz-RSI-Volume-MACD-EMA-Combo/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10776_tv-rsi-macd-ema.md`

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
| v1 | 2026-06-01 | Initial build from card | 6a5b79c3-b63d-4020-b3a8-03553bfcf755 |
