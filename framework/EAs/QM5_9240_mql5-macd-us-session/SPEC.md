# QM5_9240_mql5-macd-us-session - Strategy Spec

**EA ID:** QM5_9240
**Slug:** `mql5-macd-us-session`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades closed-bar H1 MACD histogram crosses during the US index session. A long entry requires the MACD(12,26,9) histogram to cross from negative to positive, price to be above EMA(200), and the regime to be trend or normal by ADX and ATR-percentile checks. A short entry uses the inverse MACD cross with price below EMA(200). Exits occur through the initial ATR stop, ATR take profit, an opposite MACD histogram cross, the 48-H1-bar time stop, or the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | H1 intended | Timeframe used for MACD, EMA, ADX, and ATR reads. |
| `strategy_macd_fast` | `12` | `1+` | MACD fast EMA period. |
| `strategy_macd_slow` | `26` | `> fast` | MACD slow EMA period. |
| `strategy_macd_signal` | `9` | `1+` | MACD signal period. |
| `strategy_ema_period` | `200` | `1+` | Trend filter EMA period. |
| `strategy_adx_period` | `14` | `1+` | ADX regime period. |
| `strategy_adx_trend_min` | `25.0` | `0+` | ADX level that classifies the regime as trend. |
| `strategy_atr_period` | `14` | `1+` | ATR period for regime, stop, and target. |
| `strategy_atr_percentile_lookback` | `100` | `2+` | Closed ATR samples used for the rolling percentile classifier. |
| `strategy_atr_normal_min_pct` | `20.0` | `0-100` | Lower bound for normal ATR percentile. |
| `strategy_atr_normal_max_pct` | `80.0` | `0-100` | Upper bound for normal ATR percentile. |
| `strategy_atr_sl_mult` | `2.5` | `>0` | Initial stop distance in ATR multiples. |
| `strategy_atr_tp_mult` | `3.0` | `>0` | Initial take-profit distance in ATR multiples. |
| `strategy_session_start_hour` | `14` | `0-23` | First broker-time hour allowed for the closed signal bar. |
| `strategy_session_end_hour` | `20` | `0-23` | Last broker-time hour allowed for the closed signal bar. |
| `strategy_max_hold_bars` | `48` | `1+` | Maximum H1 bars to hold before time exit. |
| `strategy_max_spread_points` | `0.0` | `0+` | Optional spread cap in points; zero disables the cap and allows DWX zero spread. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 proxy for the source article's US_TECH100 index exposure.
- `SP500.DWX` - S&P 500 custom symbol for broad US large-cap index validation; backtest-only per DWX policy.
- `WS30.DWX` - Dow 30 live-tradable US index proxy for the portable large-cap basket.

**Explicitly NOT for:**
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - not canonical DWX symbols in the matrix.
- Forex, metals, and energy symbols - the card is specific to US index session momentum.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework OnTick entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | Intraday to two trading days; capped at 48 H1 bars |
| Expected drawdown profile | Source note reports about -9.7R max drawdown on US_TECH100 H1 |
| Regime preference | Momentum during trend or normal-volatility regimes |
| Win rate target (qualitative) | Medium; source note reports 50.3% win rate |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** MQL5 article
**Pointer:** Marcelo Alejandro Borasi, "Three MACD Filters on US_TECH100: Five Years of Broker Data", 2026-05-08, https://www.mql5.com/en/articles/22290
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9240_mql5-macd-us-session.md`

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
| v1 | 2026-06-20 | Initial build from card | 9d60513b-0713-4ab2-8d9b-ef9e5cbec5e4 |
