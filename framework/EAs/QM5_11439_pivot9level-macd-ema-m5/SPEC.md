# QM5_11439_pivot9level-macd-ema-m5 - Strategy Spec

**EA ID:** QM5_11439
**Slug:** pivot9level-macd-ema-m5
**Source:** fb2ae527-c7ef-5765-a09d-9eb8157e55a0 (see `sources/daytradeforex-9-systems`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA computes the classic nine daily pivot levels from the prior completed D1 bar: S2, M1, S1, M2, P, M3, R1, M4, and R2. On each M5 closed bar it buys when the close is within the configured pip distance below a support pivot, M5 MACD histogram crosses above zero, and H1 MACD histogram is positive. It sells when the close is within the configured pip distance above a resistance pivot, M5 MACD histogram crosses below zero, and H1 MACD histogram is negative. Initial stop is the configured pip buffer beyond the triggering pivot with a 30-pip cap, take profit is the next pivot level in the trade direction, and discretionary exit occurs when close crosses EMA9 against the open position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_macd_fast | 12 | 1-100 | Fast EMA period for M5 and H1 MACD. |
| strategy_macd_slow | 26 | 2-200 | Slow EMA period for M5 and H1 MACD. |
| strategy_macd_signal | 9 | 1-100 | Signal EMA period for M5 and H1 MACD. |
| strategy_prox_pips | 5 | 1-50 | Pivot proximity threshold and stop buffer in pips. |
| strategy_sl_cap_pips | 30 | 1-200 | Maximum stop distance from entry in pips for P2. |
| strategy_ema_trail_period | 9 | 1-100 | EMA period used for the closed-bar trail exit. |
| strategy_tp_rr_fallback | 2.0 | 0.1-10.0 | RR fallback when the next pivot target is not valid. |
| strategy_spread_cap_pips | 15 | 0-100 | Maximum allowed spread in pips; zero .DWX spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed DWX major FX instrument with M5 and H1 history.
- GBPUSD.DWX - Card-listed DWX major FX instrument with M5 and H1 history.
- USDJPY.DWX - Card-listed DWX major FX instrument with M5 and H1 history.
- AUDUSD.DWX - Card-listed DWX major FX instrument with M5 and H1 history.
- USDCAD.DWX - Card-listed DWX major FX instrument with M5 and H1 history.

**Explicitly NOT for:**
- Non-FX index or commodity symbols - The card specifies FX majors and pip-based pivot proximity.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | Prior D1 OHLC for pivots; H1 MACD histogram for trend alignment |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday; minutes to hours |
| Expected drawdown profile | Moderate, bounded by fixed pivot stop and framework risk sizing |
| Regime preference | Pivot reaction with short-term momentum confirmation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fb2ae527-c7ef-5765-a09d-9eb8157e55a0
**Source type:** commercial website / local PDF archive
**Pointer:** DayTradeForex.com, "9 Profitable Trading Systems" System #9; all R1-R4 PASS per `artifacts/cards_approved/QM5_11439_pivot9level-macd-ema-m5.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11439_pivot9level-macd-ema-m5.md`

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
| v1 | 2026-06-25 | Initial build from card | c951fb9f-b1f7-44b5-b775-e9103d4a56c6 |
