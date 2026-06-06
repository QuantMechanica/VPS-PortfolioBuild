# QM5_10955_ftmo-mr-div - Strategy Spec

**EA ID:** QM5_10955
**Slug:** `ftmo-mr-div`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see FTMO source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades H1 Bollinger Band mean reversion after a confirmed divergence. A long can open after the prior closed bar was below the lower Bollinger Band with RSI below 35, MACD histogram made a bullish divergence against price swing lows over the last 20 bars, and the newest closed bar closes back above the lower band. A short mirrors the rule at the upper band with RSI above 65 and bearish MACD divergence. The initial target is the Bollinger middle line, the stop is placed beyond the most recent swing with a 0.15 ATR buffer, and any remaining position is closed after 36 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 20 | >= 2 | Bollinger Band SMA period. |
| `strategy_bb_deviation` | 2.0 | > 0 | Bollinger Band standard deviation multiplier. |
| `strategy_rsi_period` | 14 | >= 2 | RSI period for overbought and oversold confirmation. |
| `strategy_rsi_oversold` | 35.0 | 0-100 | Maximum RSI value for a long setup. |
| `strategy_rsi_overbought` | 65.0 | 0-100 | Minimum RSI value for a short setup. |
| `strategy_macd_fast` | 12 | > 0 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | > fast | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | > 0 | MACD signal period. |
| `strategy_atr_period` | 14 | > 0 | ATR period for volatility filter and stop buffer. |
| `strategy_atr_median_bars` | 100 | >= 3 | Lookback used to compute the ATR median filter. |
| `strategy_divergence_lookback` | 20 | >= 8 | Closed bars scanned for price/MACD divergence. |
| `strategy_swing_side_bars` | 2 | >= 1 | Bars on each side required to confirm a swing high or low. |
| `strategy_sl_atr_buffer_mult` | 0.15 | > 0 | ATR buffer added beyond the swing stop. |
| `strategy_trend_ema_period` | 200 | >= 2 | EMA period for the countertrend skip filter. |
| `strategy_trend_atr_skip_mult` | 1.5 | > 0 | ATR distance beyond EMA that blocks countertrend entries. |
| `strategy_time_exit_bars` | 36 | > 0 | Maximum H1 bars to hold before strategy close. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with DWX H1 OHLC and indicator data.
- `GBPUSD.DWX` - card-listed major FX pair with DWX H1 OHLC and indicator data.
- `XAUUSD.DWX` - card-listed gold symbol with DWX H1 OHLC and indicator data.
- `NDX.DWX` - card-listed liquid index symbol with DWX H1 OHLC and indicator data.

**Explicitly NOT for:**
- Non-DWX symbols - research and backtest artifacts must keep the `.DWX` suffix.
- Non-H1 charts - the card specifies completed H1-bar evaluation.

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
| Trades / year / symbol | `28` |
| Typical hold time | Up to `36` H1 bars. |
| Expected drawdown profile | Selective mean-reversion entries with stop beyond recent swing plus ATR buffer. |
| Regime preference | Mean-reversion with divergence confirmation and sufficient ATR. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** blog
**Pointer:** `https://ftmo.com/en/blog/mean-reversion-divergence-setup-strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10955_ftmo-mr-div.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | 3deed941-4346-4183-aa3a-684ad078edc2 |
