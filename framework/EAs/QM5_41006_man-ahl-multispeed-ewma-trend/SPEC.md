# QM5_41006_man-ahl-multispeed-ewma-trend — Strategy Spec

**EA ID:** QM5_41006
**Slug:** man-ahl-multispeed-ewma-trend
**Source:** man-ahl-multispeed-ewma-trend-official-source
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

Institutional trend following engine evaluating a composite continuous trend forecast signal across six EWMA crossover horizons (2/8, 4/16, 8/32, 16/64, 32/128, 64/256 days) normalized by D1 realized volatility (ATR 60). On closed D1 bars, the EA enters Long when the composite score crosses above +0.35, and enters Short when the composite score crosses below -0.35. Entries carry an initial stop loss of 2.5x ATR(14). Positions are closed when the composite forecast signal crosses back across zero or opposite threshold.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `InpForecastThreshold` | 0.35 | 0.20-0.50 | Minimum composite trend forecast score threshold for trade entry |
| `InpVolWindow` | 60 | 30-90 | Realized volatility normalizer lookback window in D1 bars |
| `InpAtrSlPeriod` | 14 | 10-30 | ATR period for stop loss sizing |
| `InpAtrSlMult` | 2.5 | 1.5-4.0 | ATR multiplier for stop loss placement |
| `InpSpreadAtrMult` | 1.8 | 1.0-3.0 | Maximum allowable spread as multiple of D1 ATR(14) |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — Tech-heavy index with strong multi-horizon momentum and persistent trends.
- `SP500.DWX` — Core broad equity benchmark capturing institutional macroeconomic trends.
- `XTIUSD.DWX` — High-volatility energy commodity exhibiting multi-speed trend extensions.
- `XAUUSD.DWX` — Precious metals macro trend asset with sustained momentum regimes.

**Explicitly NOT for:**
- `EURCHF.DWX` — Pegged/intervened low-volatility currency pair lacking multi-horizon trend dynamics.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Typical hold time | days |
| Expected drawdown profile | Moderate equity drawdown (<6.8%) with high Sharpe multi-horizon trend payoff |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** man-ahl-multispeed-ewma-trend-official-source
**Source type:** paper
**Pointer:** Harvey, C. R., Liew, R., & Rattray, N. (2018). Man AHL Trend Following Compendium.
**R1–R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_41006_man-ahl-multispeed-ewma-trend.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | Initial build from card | Task b42bac52-ccda-4a73-b49b-faab46b48c88 |
