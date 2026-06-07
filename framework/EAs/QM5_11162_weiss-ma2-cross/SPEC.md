# QM5_11162_weiss-ma2-cross - Strategy Spec

**EA ID:** QM5_11162
**Slug:** weiss-ma2-cross
**Source:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates the last completed D1 bar. It opens long when SMA(9) crosses above SMA(26), opens short when SMA(9) crosses below SMA(26), and closes any opposite position before the new direction is eligible to enter. The source system has no profit target; each entry receives a protective catastrophic stop at the greater of 3 x ATR(20) or the broker minimum stop distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_fast_sma_period | 9 | 1 to slow period - 1 | Fast simple moving average period for the crossover signal. |
| strategy_slow_sma_period | 26 | fast period + 1 or higher | Slow simple moving average period for the crossover signal. |
| strategy_atr_period | 20 | 1 or higher | D1 ATR period used for the protective catastrophic stop. |
| strategy_atr_stop_mult | 3.0 | greater than 0 | ATR multiple used for the protective catastrophic stop. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid major FX symbol with D1 OHLC history.
- USDJPY.DWX - card-listed liquid major FX symbol with D1 OHLC history.
- XAUUSD.DWX - card-listed gold symbol suitable for a trend-following D1 crossover.
- XTIUSD.DWX - card-listed crude oil symbol suitable for a trend-following D1 crossover.
- SP500.DWX - card-listed S&P 500 custom symbol; valid for backtest registration with live routing caveat.

**Explicitly NOT for:**
- SPX500.DWX - unavailable non-canonical S&P 500 symbol; SP500.DWX is the valid matrix symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 10 |
| Typical hold time | days to weeks |
| Expected drawdown profile | Trend-following drawdowns during sideways or choppy regimes. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Source type:** book
**Pointer:** Richard L. Weissman, Mechanical Trading Systems, Chapter 3, pp. 50-52, https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11162_weiss-ma2-cross.md`

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
| v1 | 2026-06-07 | Initial build from card | d201586b-37cc-4d7d-8b5c-f0bfdbd58abf |
