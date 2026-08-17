# QM5_21506_xau-weekly-trend-confirm — Strategy Spec

**EA ID:** QM5_21506
**Slug:** `xau-weekly-trend-confirm`
**Source:** `28681f5d-aa78-584e-9698-750d1402e485`
**Author of this spec:** Gemini
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

This EA implements a dual-horizon momentum strategy on gold (`XAUUSD.DWX`) on the D1 timeframe, based on Zhao, Ding, Yu, and Kang (SSRN 6425598, 2026). It uses an intermediate-term 63-bar Simple Moving Average (SMA) as the primary trend regime filter, overlaid with a short-horizon 5-bar trailing return sign as a timing confirmation trigger.

On the open of each new completed D1 bar:
- **Trend State:** Evaluates `Close[1]` relative to `SMA(63, D1)[1]`. `TREND_UP` if `Close[1] > SMA[1]`, `TREND_DOWN` if `Close[1] < SMA[1]`.
- **Weekly Confirmation:** Computes trailing 5-bar completed return `(Close[1] - Close[6]) / Close[6]`.
- **Long Entry:** Open a long position when `TREND_UP` is active and weekly return is positive, provided no long position is currently open and spread is within limits.
- **Short Entry:** Open a short position when `TREND_DOWN` is active and weekly return is negative, provided no short position is currently open and spread is within limits.
- **Trend-Failure Exit:** Close long positions if the trend state flips to `TREND_DOWN`; close short positions if the trend state flips to `TREND_UP`.
- **Hard Stop Loss:** Fixed hard stop placed at `strategy_atr_sl_mult` × ATR(14, D1) from entry.
- **Time Stop:** Positions are closed after `strategy_max_hold_bars` (default 40) completed D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_trend_period` | 63 | 42-126 | Intermediate SMA trend filter period |
| `strategy_lookback_bars` | 5 | 3-8 | Short-horizon return confirmation lookback bars |
| `strategy_atr_period` | 14 | 10-20 | ATR period for stop loss calculation |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.5 | ATR multiplier for hard stop distance |
| `strategy_max_hold_bars` | 40 | 30-60 | Maximum holding period in completed D1 bars |
| `strategy_max_spread_points` | 300 | 150-500 | Maximum allowed spread in points |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — Intermediate gold trend following with short-horizon weekly return timing confirmation.

**Explicitly NOT for:**
- Non-gold symbols (single-symbol sleeve only in v1).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12-18 |
| Typical hold time | 5-25 days |
| Expected drawdown profile | <= 20% max DD in fixed risk |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `28681f5d-aa78-584e-9698-750d1402e485`
**Source type:** paper
**Pointer:** Shen Zhao, Yiyi Ding, Jianfeng Yu, Wenjin Kang (2026). "Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets." SSRN Working Paper, abstract_id=6425598. https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_21506_xau-weekly-trend-confirm.md`

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
| v1 | 2026-08-17 | Initial build from card | Task febe5550-8cba-4384-bb6f-6514aaace6a2 |
