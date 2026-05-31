# QM5_10587_mql5-modopt - Strategy Spec

**EA ID:** QM5_10587
**Slug:** mql5-modopt
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA computes the Modified Optimum Elliptic Filter from closed bars using the published recursive median-price formula. It opens long when the latest closed bar confirms the filter has changed from falling to rising, and opens short when the filter changes from rising to falling. If an opposite position is already open for the same symbol and magic, the EA closes it on the same confirmed reversal before opening the new direction. Each entry uses an ATR(14) 2.0 stop and a 1.5R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_filter_calc_bars | 120 | >= 8 | Closed-bar history window used to warm up the recursive filter. |
| strategy_atr_period | 14 | > 0 | ATR period for hard stop placement. |
| strategy_atr_sl_mult | 2.0 | > 0 | ATR multiplier for stop distance. |
| strategy_rr_target | 1.5 | > 0 | Reward-to-risk target derived from the stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- USDJPY.DWX - card primary source test symbol and liquid DWX FX major.
- EURUSD.DWX - liquid DWX FX major in the approved P2 basket.
- GBPJPY.DWX - volatile DWX FX cross in the approved P2 basket.
- XAUUSD.DWX - liquid DWX metal in the approved P2 basket.

**Explicitly NOT for:**
- Non-DWX symbols - this build is registered only for validated DWX research symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | H4 direction-change holds, usually hours to days |
| Expected drawdown profile | ATR-bounded trend-following reversals with fixed 1.5R targets |
| Regime preference | trend / filter direction change |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/12549
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10587_mql5-modopt.md`

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
| v1 | 2026-05-29 | Initial build from card | 62b2b0db-166c-4d01-b160-3d1d6ee29b8a |
