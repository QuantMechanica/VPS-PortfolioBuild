# QM5_10088_mql5-hammer-rsi - Strategy Spec

**EA ID:** QM5_10088
**Slug:** `mql5-hammer-rsi`
**Source:** `a120af9a-fb72-526c-bb80-d1d098a617b5` (see `strategy-seeds/sources/a120af9a-fb72-526c-bb80-d1d098a617b5/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA evaluates completed H1 candles for Hammer and Hanging Man style bars: a small body, long lower shadow, short upper shadow, and a recent directional context. It buys after a Hammer in a downward context when RSI(1) is below 40, and sells after a Hanging Man in an upward context when RSI(1) is above 60. Long positions close when RSI crosses downward through 70 or 30; short positions close when RSI crosses upward through 30 or 70. If an opposite confirmed signal appears while a position is open, the EA closes the position and does not reverse on the same bar.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 1 | 1-100 | RSI period used for confirmation and exits. |
| `strategy_buy_rsi_max` | 40.0 | 0-100 | Maximum RSI value allowed for Hammer long entries. |
| `strategy_sell_rsi_min` | 60.0 | 0-100 | Minimum RSI value allowed for Hanging Man short entries. |
| `strategy_exit_lower_level` | 30.0 | 0-100 | Lower RSI crossing level for discretionary exits. |
| `strategy_exit_upper_level` | 70.0 | 0-100 | Upper RSI crossing level for discretionary exits. |
| `strategy_context_lookback` | 3 | 1-20 | Closed-bar lookback used to define upward or downward context. |
| `strategy_max_body_range_frac` | 0.35 | 0.01-1.0 | Maximum candle body as a fraction of total range. |
| `strategy_lower_shadow_body_min` | 2.0 | 0.1-10.0 | Minimum lower-shadow-to-body ratio. |
| `strategy_upper_shadow_body_max` | 1.0 | 0.0-10.0 | Maximum upper-shadow-to-body ratio. |
| `strategy_atr_period` | 14 | 1-200 | ATR period used for the protective stop. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-20.0 | ATR multiplier for the protective stop. |
| `strategy_min_range_atr_mult` | 0.0 | 0.0-10.0 | Optional minimum candle range as a fraction of ATR; 0 disables it. |
| `strategy_max_spread_points` | 0 | 0-100000 | Optional maximum spread filter in points; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with DWX OHLC and RSI data.
- `GBPUSD.DWX` - card-listed major FX pair with DWX OHLC and RSI data.
- `USDJPY.DWX` - card-listed major FX pair with DWX OHLC and RSI data.
- `XAUUSD.DWX` - card-listed liquid metal CFD with DWX OHLC and RSI data.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline phases require canonical `.DWX` symbols from `dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Indicator exit driven; expected intraday to multi-day holds. |
| Expected drawdown profile | Mean-reversion candlestick entries with fixed ATR protective stops. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `a120af9a-fb72-526c-bb80-d1d098a617b5`
**Source type:** `MQL5 article`
**Pointer:** Artyom Trishkin, "Deconstructing examples of trading strategies in the client terminal", MQL5 Articles, 13 February 2025, https://www.mql5.com/en/articles/15479
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10088_mql5-hammer-rsi.md`

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
| v1 | 2026-06-11 | Initial build from card | 2e919cb7-ffd1-4b9b-b5fe-a233e458ab07 |
