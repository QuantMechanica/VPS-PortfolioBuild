# QM5_11554_carter-t-m5-wma10-sma20-stoch-rsi28-macd - Strategy Spec

**EA ID:** QM5_11554
**Slug:** `carter-t-m5-wma10-sma20-stoch-rsi28-macd`
**Source:** `42530cb3-0265-534a-89cc-150f80733ff5` (see `sources/carter-thomas-20-forex-strategies-5min`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades M5 EURUSD five-indicator confluence from Thomas Carter System #14. A long entry is opened when WMA(10) is above SMA(20), Stochastic(10,6,6) %K is above %D, RSI(28) is above 50, and MACD(24,52,18) main is above zero on the last closed M5 bar. A short entry uses the exact opposite conditions. The stop is the 10-bar structure extreme capped at 20 pips, and the take-profit is set at the same distance for 1:1 reward-to-risk.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_M5` | M5 expected | Timeframe for all signal indicators. |
| `strategy_wma_period` | `10` | >=1 | Weighted moving average trend period. |
| `strategy_sma_period` | `20` | >=1 | Simple moving average trend period. |
| `strategy_stoch_k_period` | `10` | >=1 | Stochastic K period. |
| `strategy_stoch_d_period` | `6` | >=1 | Stochastic D period. |
| `strategy_stoch_slowing` | `6` | >=1 | Stochastic slowing period. |
| `strategy_rsi_period` | `28` | >=1 | RSI momentum period. |
| `strategy_rsi_midline` | `50.0` | 0-100 | RSI long/short threshold. |
| `strategy_macd_fast` | `24` | >=1 | MACD fast EMA period. |
| `strategy_macd_slow` | `52` | > fast | MACD slow EMA period. |
| `strategy_macd_signal` | `18` | >=1 | MACD signal period. |
| `strategy_sl_lookback_bars` | `10` | >=1 | Structure lookback for the SL extreme. |
| `strategy_max_sl_pips` | `20` | >=1 | Maximum stop distance in pips. |
| `strategy_rr` | `1.0` | >0 | Take-profit multiple of stop distance. |
| `strategy_max_spread_pips` | `5.0` | >0 | Maximum allowed spread before entry. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - the card explicitly names EURUSD.DWX as the instrument for this M5 forex strategy.

**Explicitly NOT for:**
- `SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX` - the card is forex-specific and does not define an index basket.
- `XAUUSD.DWX`, `XAGUSD.DWX`, `XTIUSD.DWX` - the card does not define commodity-market behavior or point-value assumptions.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `200` |
| Typical hold time | Intraday, exact hold time not specified by the card. |
| Expected drawdown profile | Small fixed-risk losses bounded by 20-pip maximum initial stop. |
| Regime preference | M5 trend and momentum confluence. |
| Win rate target (qualitative) | Medium, supported by 1:1 reward-to-risk and multi-indicator confirmation. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `42530cb3-0265-534a-89cc-150f80733ff5`
**Source type:** `book`
**Pointer:** `Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", System #14, self-published 2014`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11554_carter-t-m5-wma10-sma20-stoch-rsi28-macd.md`

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
| v1 | 2026-06-11 | Initial build from card | c91bcc8c-326b-476a-8eb2-72b658dff040 |
