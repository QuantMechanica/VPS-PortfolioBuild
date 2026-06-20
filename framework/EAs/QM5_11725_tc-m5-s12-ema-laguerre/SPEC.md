# QM5_11725_tc-m5-s12-ema-laguerre - Strategy Spec

**EA ID:** QM5_11725
**Slug:** tc-m5-s12-ema-laguerre
**Source:** 40a4454c-64ff-5015-8538-9f7b32abc0e9 (see `sources/tc-20-forex-strategies-m5-367145560`)
**Author of this spec:** Codex
**Last revised:** 2026-06-21

---

## 1. Strategy Logic

This EA trades the M5 Carter Strategy #12 momentum setup. A long entry is allowed when the last closed bar is above EMA(16), EMA(16) is above EMA(48), and the custom Ehlers Laguerre RSI crosses up through 0.8 on that closed bar. A short entry is allowed when the last closed bar is below EMA(16), EMA(16) is below EMA(48), and Laguerre RSI crosses down through 0.2. Exits are handled only by the fixed 30-pip stop loss, fixed 25-pip take profit, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_fast_period | 16 | 2-200 | Fast EMA in the trend stack. |
| strategy_ema_slow_period | 48 | 3-400 | Slow EMA in the trend stack. |
| strategy_lag_gamma | 0.7 | 0.01-0.99 | Ehlers Laguerre filter damping factor. |
| strategy_lag_up_level | 0.8 | 0.0-1.0 | Long trigger threshold crossed upward by Laguerre RSI. |
| strategy_lag_dn_level | 0.2 | 0.0-1.0 | Short trigger threshold crossed downward by Laguerre RSI. |
| strategy_lag_warmup_bars | 200 | 50-1000 | Closed-bar seed window for deterministic Laguerre recursion. |
| strategy_sl_pips | 30 | 1-500 | Fixed stop-loss distance in pips. |
| strategy_tp_pips | 25 | 1-500 | Fixed take-profit distance in pips. |
| strategy_spread_pct_of_stop | 15.0 | 0.0-100.0 | Blocks only genuinely wide spread above this percent of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed M5 major FX target with DWX data.
- GBPUSD.DWX - card-listed M5 major FX target with DWX data.
- USDJPY.DWX - card-listed M5 major FX target with DWX data.
- AUDUSD.DWX - card-listed M5 major FX target with DWX data.

**Explicitly NOT for:**
- Non-FX index, metal, and energy symbols - the card R3 basket is FX-only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | intraday M5 holds; fixed SL/TP close |
| Expected drawdown profile | frequent small fixed-risk losses during non-trending chop |
| Regime preference | trend / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 40a4454c-64ff-5015-8538-9f7b32abc0e9
**Source type:** book
**Pointer:** Thomas Carter, `20 Forex Trading Strategies (5 Minute Time Frame)`, Strategy #12; see `artifacts/cards_approved/QM5_11725_tc-m5-s12-ema-laguerre.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11725_tc-m5-s12-ema-laguerre.md`

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
| v1 | 2026-06-20 | Initial build from card | cf528a5f-0d69-44be-8524-4b60d60bcb9b |
