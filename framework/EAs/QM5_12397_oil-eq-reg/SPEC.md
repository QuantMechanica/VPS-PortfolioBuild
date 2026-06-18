# QM5_12397_oil-eq-reg - Strategy Spec

**EA ID:** QM5_12397
**Slug:** oil-eq-reg
**Source:** b7832a20-938e-5f24-b9d7-e0b2ab63b623
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades a long-or-flat equity index timing rule. On the first D1 trading bar of each calendar month, it approximates monthly returns with 21 D1 bars, regresses target equity-index monthly returns on the prior-month return of `XTIUSD.DWX`, and forecasts the next equity month from the most recent oil return. It opens or keeps a long equity-index position when the forecast is greater than the fixed monthly cash hurdle, and it closes the position when the forecast is less than or equal to the hurdle or the regression cannot be estimated. Entries use a 3.0 x ATR(20, D1) emergency stop; open trades are also force-closed if drawdown exceeds 4R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_oil_symbol | XTIUSD.DWX | DWX symbol string | Oil proxy used as the cross-asset predictor. |
| strategy_month_bars | 21 | 10-63 | D1 bars used as the monthly proxy because MN1 is unavailable in DWX tester. |
| strategy_regression_months | 24 | 24-60 | Rolling OLS warmup observations. |
| strategy_cash_hurdle_pct | 0.0 | 0.0-0.25 | Monthly forecast hurdle in percent. |
| strategy_atr_period | 20 | 5-100 | D1 ATR period for the emergency stop. |
| strategy_atr_stop_mult | 3.0 | 2.0-4.0 | ATR multiple for the initial stop. |
| strategy_emergency_r_mult | 4.0 | 1.0-6.0 | Open-trade drawdown multiple that triggers emergency close. |
| strategy_spread_lookback_d1 | 60 | 20-120 | D1 bars used for the median spread entry guard. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 custom symbol explicitly approved for backtest use in the card's target universe.
- NDX.DWX - Nasdaq 100 DWX index target from the card's portable equity universe.
- WS30.DWX - Dow 30 DWX index target from the card's portable equity universe.

**Explicitly NOT for:**
- XTIUSD.DWX - Used only as the oil predictor; this EA does not trade the oil leg.
- SPX500.DWX, SPY.DWX, ES.DWX - Not canonical DWX symbols for the approved S&P 500 port.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | XTIUSD.DWX D1 predictor history; target-symbol D1 history |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Monthly rebalance; positions may hold for multiple months while forecast remains above hurdle |
| Expected drawdown profile | Low-frequency index timing with gap and missed-rally risk |
| Regime preference | Cross-asset equity-index timing |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b7832a20-938e-5f24-b9d7-e0b2ab63b623
**Source type:** public implementation / strategy catalog
**Pointer:** https://github.com/paperswithbacktest/awesome-systematic-trading/blob/main/static/strategies/crude-oil-predicts-equity-returns.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12397_oil-eq-reg.md`

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
| v1 | 2026-06-18 | Initial build from card | ad5ef2da-8a68-40d2-a68e-5fbda4c86654 |
