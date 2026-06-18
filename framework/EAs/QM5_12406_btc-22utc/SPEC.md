# QM5_12406_btc-22utc - Strategy Spec

**EA ID:** QM5_12406
**Slug:** btc-22utc
**Source:** b7832a20-938e-5f24-b9d7-e0b2ab63b623 (see approved card citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA ports the approved BTC intraday seasonality rule to the card's DWX CFD universe. On each completed execution bar, it converts broker time to UTC and opens one long position when the UTC clock reaches 22:00 on a weekday. It places an emergency stop at 2.0 times ATR(20) from M15 and uses no take-profit. The position is closed by strategy time stop at 00:00 UTC, or earlier only through the framework kill-switch, Friday close, or the emergency stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_entry_hour_utc | 22 | 0-23 | UTC hour for the long entry. |
| strategy_exit_hour_utc | 0 | 0-23 | UTC hour for the mandatory time exit. |
| strategy_exit_minute_utc | 0 | 0-59 | UTC minute for the mandatory time exit. |
| strategy_atr_period_m15 | 20 | >0 | M15 ATR period for the emergency stop. |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiple for the emergency stop distance. |
| strategy_max_spread_points | 0 | >=0 | Optional entry spread cap in points; 0 disables the cap and still allows zero modeled DWX spread. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - Liquid high-volatility metal CFD included in the approved R3 DWX port basket.
- XTIUSD.DWX - Liquid high-volatility energy CFD included in the approved R3 DWX port basket.
- NDX.DWX - Liquid Nasdaq 100 index CFD included in the approved R3 DWX port basket.
- WS30.DWX - Liquid Dow 30 index CFD included in the approved R3 DWX port basket.
- EURUSD.DWX - Liquid major FX pair included in the approved R3 DWX port basket.

**Explicitly NOT for:**
- BTCUSD.DWX - The card allows this only if an approved MT5 test feed is later confirmed; this build does not depend on crypto routing.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - Not valid for DWX P2 registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 for smoke baseline; M1, M5, and M15 setfiles are generated because the card lists all three execution candidates. |
| Multi-timeframe refs | M15 ATR(20) stop reference |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Typical hold time | Two hours, from 22:00 UTC to 00:00 UTC |
| Expected drawdown profile | Fixed-risk intraday seasonality drawdowns if the BTC clock effect does not transfer to CFD symbols |
| Regime preference | Intraday seasonality / time-of-day, long-only, fixed-hold, price-only |
| Win rate target (qualitative) | Not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b7832a20-938e-5f24-b9d7-e0b2ab63b623
**Source type:** public GitHub / Quantpedia implementation
**Pointer:** Papers With Backtest / Quantpedia implementation, Intraday Seasonality in Bitcoin, `https://github.com/paperswithbacktest/awesome-systematic-trading/blob/main/static/strategies/intraday-seasonality-in-bitcoin.py`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_12406_btc-22utc.md`

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
| v1 | 2026-06-18 | Initial build from card | 6774b1b4-966d-4361-817a-3bd0b6e3c7ed |
