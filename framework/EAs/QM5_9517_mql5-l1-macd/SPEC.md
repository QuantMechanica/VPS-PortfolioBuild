# QM5_9517_mql5-l1-macd — Strategy Spec

**EA ID:** QM5_9517
**Slug:** `mql5-l1-macd`
**Source:** `a120af9a-fb72-526c-bb80-d1d098a617b5` (see `strategy-seeds/sources/a120af9a-fb72-526c-bb80-d1d098a617b5/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA enters long when the MACD main line (12/26 EMA) crosses above the signal line (9-period EMA) on a closed H1 bar, and enters short on the opposite crossover. One position per magic is allowed at a time. Exits use the standard opposite-crossover rule, but with an L1 total-variation exit filter: a bearish crossover closes a long only if the L1 TV-denoised trend slope is negative, confirming an actual reversal rather than a noise-driven signal; the symmetric rule applies for shorts. The L1 filter uses a 30-bar rolling window with lambda = 0.2 × lambda_max (lambda_max = maximum absolute first difference of closes over the window). An ATR(14) × 2.0 catastrophic stop is set at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 12 | 5-50 | MACD fast EMA period |
| `strategy_macd_slow` | 26 | 10-100 | MACD slow EMA period |
| `strategy_macd_sig_period` | 9 | 3-30 | MACD signal EMA period |
| `strategy_atr_period` | 14 | 7-50 | ATR period for catastrophic stop |
| `strategy_atr_sl_mult` | 2.0 | 1.0-5.0 | ATR multiplier for stop distance |
| `strategy_l1_window` | 30 | 10-59 | Bars in L1 TV rolling window |
| `strategy_l1_lambda_coef` | 0.2 | 0.05-0.5 | lambda = coef × lambda_max |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair with consistent H1 MACD trending characteristics
- `GBPUSD.DWX` — major FX pair, correlated volatility profile to EURUSD
- `USDJPY.DWX` — yen pair; risk-on/off regime relevant to MACD trend signals
- `XAUUSD.DWX` — gold; strong H1 trending during macro events, MACD well-suited

**Explicitly NOT for:**
- Indices (NDX, WS30) — not in card target universe; equity hours add session gaps

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
| Trades / year / symbol | ~65 |
| Typical hold time | hours to several days |
| Expected drawdown profile | moderate; L1 filter reduces whipsaw exits, ATR stop caps catastrophic loss |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `a120af9a-fb72-526c-bb80-d1d098a617b5`
**Source type:** article
**Pointer:** MetaQuotes, "Applying L1 Trend Filtering in MetaTrader 5", MQL5 Articles, 2026-04-20, https://www.mql5.com/en/articles/21142
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9517_mql5-l1-macd.md`

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
| v1 | 2026-06-11 | Initial build from card | f0961a99-7d90-4d36-8985-7e64a9afbe1b |
