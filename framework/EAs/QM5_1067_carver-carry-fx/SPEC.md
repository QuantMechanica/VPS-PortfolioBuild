# QM5_1067_carver-carry-fx - Strategy Spec

**EA ID:** QM5_1067
**Slug:** carver-carry-fx
**Source:** 2a380bee-1ec4-50d1-a348-b10fac642c7a
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades FX carry on D1 bars. It reads broker swap values, converts the positive long or short carry into an annualised return, normalises it by EWMA daily close-change volatility, multiplies by a fixed forecast scalar of 30, and caps the result at +/-20. It opens long when the long-carry forecast is above the entry threshold, opens short when the short-carry forecast is below the negative threshold, and closes when the held side's forecast decays through zero or the opposite side reaches its entry threshold.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_entry_forecast | 2.0 | > 0 | Forecast threshold required to open a new position. |
| strategy_vol_span_days | 25 | >= 2 | EWMA span for daily close-change volatility. |
| strategy_atr_period | 20 | >= 1 | D1 ATR period for the emergency stop. |
| strategy_atr_stop_mult | 2.5 | > 0 | ATR multiple for the emergency stop. |
| strategy_forecast_scalar | 30.0 | > 0 | Scalar applied to carry divided by annualised volatility. |
| strategy_forecast_cap | 20.0 | > 0 | Absolute cap applied to the signed forecast. |
| strategy_spread_median_days | 20 | >= 1 | D1 spread lookback for the median-spread entry cap. |
| strategy_swap_days_per_year | 256.0 | > 0 | Annualisation factor for swap and volatility. |

---

## 3. Symbol Universe

**Designed for:**
- AUDJPY.DWX - liquid FX pair with meaningful AUD/JPY carry exposure.
- NZDJPY.DWX - liquid FX pair with meaningful NZD/JPY carry exposure.
- AUDUSD.DWX - liquid FX pair with AUD/USD rate differential exposure.
- NZDUSD.DWX - liquid FX pair with NZD/USD rate differential exposure.
- USDJPY.DWX - liquid FX pair with USD/JPY rate differential exposure.
- GBPJPY.DWX - liquid FX pair with GBP/JPY rate differential exposure.
- EURUSD.DWX - liquid FX pair with EUR/USD rate differential exposure.
- USDCAD.DWX - liquid FX pair with USD/CAD rate differential exposure.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the card is a broker-swap FX carry rule, not an index, metal, energy, or crypto rule.

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
| Trades / year / symbol | 2 |
| Typical hold time | Multi-day to multi-week carry holds |
| Expected drawdown profile | Slow factor with emergency ATR stop and low turnover |
| Regime preference | FX carry / positive rate differential |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 2a380bee-1ec4-50d1-a348-b10fac642c7a
**Source type:** blog and linked source code
**Pointer:** https://qoppac.blogspot.com/2015/09/python-code-for-two-trading-rules-in.html
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1067_carver-carry-fx.md`

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
| v1 | 2026-06-14 | Initial build from card | 1d91729a-96ea-4175-abf0-284731ba90f3 |
