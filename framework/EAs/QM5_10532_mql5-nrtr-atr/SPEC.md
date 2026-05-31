# QM5_10532_mql5-nrtr-atr - Strategy Spec

**EA ID:** QM5_10532
**Slug:** mql5-nrtr-atr
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see MQL5 CodeBase citation)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

This EA trades the NRTR_ATR_STOP colored-star trend signal on closed H1 bars. A bullish NRTR ATR reversal star opens a long position when no same-symbol magic position is active; a bearish reversal star opens a short position under the same one-position rule. Open positions close on the opposite NRTR ATR star when enabled, at the broker SL/TP, at the framework Friday close, or after the configured H1 bar time stop. The hard stop is 1.5 ATR(14) by default and the take profit is 2.0R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_nrtr_atr_period | 20 | >= 2 | ATR period used by the NRTR_ATR_STOP signal calculation. |
| strategy_nrtr_atr_coef | 2.0 | > 0 | ATR multiplier used to form the NRTR reversal stop line. |
| strategy_atr_period | 14 | >= 1 | ATR period used for hard stop placement. |
| strategy_atr_sl_mult | 1.5 | > 0 | Stop-loss distance in ATR multiples. |
| strategy_tp_rr | 2.0 | > 0 | Take-profit distance as an R multiple of stop risk. |
| strategy_time_stop_bars | 20 | >= 0 | Maximum H1 bars to hold; 0 disables the time stop. |
| strategy_nrtr_warmup_bars | 160 | >= strategy_nrtr_atr_period + 5 | Closed-bar history used to seed the NRTR state. |
| strategy_exit_on_opposite | true | true/false | Whether an opposite NRTR star closes an open position. |
| strategy_max_spread_points | 0 | >= 0 | Optional spread block; 0 disables the strategy spread override. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid FX major suitable for H1 ATR trend-stop signals.
- GBPUSD.DWX - card-listed liquid FX major suitable for H1 ATR trend-stop signals.
- USDJPY.DWX - card-listed liquid FX major suitable for H1 ATR trend-stop signals.
- XAUUSD.DWX - card-listed liquid metal with enough H1 volatility for ATR trend-stop signals.

**Explicitly NOT for:**
- Non-DWX symbols - V5 backtests use the verified DWX symbol matrix only.
- Symbols outside the card R3 basket - not registered for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Up to 20 H1 bars, unless opposite signal or SL/TP exits first |
| Expected drawdown profile | ATR-normalized trend-following losses bounded by fixed 1.5 ATR stop |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/18448
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10532_mql5-nrtr-atr.md`

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
| v1 | 2026-05-29 | Initial build from card | 08bbf0ff-fb04-4e59-93c2-f605f62bfb1d |
