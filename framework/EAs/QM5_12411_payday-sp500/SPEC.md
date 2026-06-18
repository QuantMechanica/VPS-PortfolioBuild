# QM5_12411_payday-sp500 - Strategy Spec

**EA ID:** QM5_12411
**Slug:** payday-sp500
**Source:** b7832a20-938e-5f24-b9d7-e0b2ab63b623
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA trades a fixed monthly payday calendar effect on index CFDs. It computes the 15th calendar day of each month, moves it back to Friday when the 15th falls on a weekend, and enters long one minute before the configured broker close time on that adjusted date. The position is protected with a 1.0 x ATR(20, D1) emergency stop and is closed one trading day later at the configured broker close time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_payday_day | 15 | 1-28 | Calendar day used as the monthly payday anchor before weekend adjustment. |
| strategy_entry_hour_broker | 22 | 0-23 | Broker-time hour for the close-minute long entry. |
| strategy_entry_minute_broker | 59 | 0-59 | Broker-time minute for the close-minute long entry. |
| strategy_exit_hour_broker | 22 | 0-23 | Broker-time hour for the next-trading-day close exit. |
| strategy_exit_minute_broker | 59 | 0-59 | Broker-time minute for the next-trading-day close exit. |
| strategy_atr_period_d1 | 20 | 2-252 | D1 ATR period for the emergency stop. |
| strategy_atr_stop_mult | 1.0 | 0.1-10.0 | ATR multiplier for the emergency stop. |
| strategy_max_spread_points | 0 | 0-10000 | Optional entry spread cap in points; zero disables the cap for DWX zero-spread tests. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - Direct S&P 500 custom-symbol port named in the card.
- NDX.DWX - US large-cap index proxy named in the card's R3 universe.
- WS30.DWX - US large-cap index proxy named in the card's R3 universe.

**Explicitly NOT for:**
- SPX500.DWX - Not present in the DWX symbol matrix.
- SPY.DWX - Not present in the DWX symbol matrix.
- ES.DWX - Not present in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | PERIOD_D1 ATR(20) stop |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | One trading day |
| Expected drawdown profile | Sparse monthly exposure with event-sensitive index drawdowns. |
| Regime preference | Calendar seasonality |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b7832a20-938e-5f24-b9d7-e0b2ab63b623
**Source type:** public implementation
**Pointer:** artifacts/cards_approved/QM5_12411_payday-sp500.md
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12411_payday-sp500.md`

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
| v1 | 2026-06-18 | Initial build from card | aef2cc41-c746-418b-b96f-9f1c5feb4f9e |
