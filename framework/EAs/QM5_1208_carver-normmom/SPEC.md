# QM5_1208_carver-normmom - Strategy Spec

**EA ID:** QM5_1208
**Slug:** carver-normmom
**Source:** 2a380bee-1ec4-50d1-a348-b10fac642c7a
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

On each closed D1 bar, the EA converts daily close-to-close returns into a cumulative series of volatility-normalized returns. It applies an EWMAC filter to that normalized series, scales and caps the forecast, enters long above +2 forecast units, and enters short below -2 forecast units. A long exits when the forecast falls below zero, and a short exits when the forecast rises above zero.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_period | 16 | 2-64 | Fast EMA period for the normalized-price EWMAC filter. |
| strategy_slow_period | 64 | 8-256 | Slow EMA period, normally four times the fast period. |
| strategy_vol_lookback | 25 | 2-100 | Lookback used for return volatility and normalized-price-change volatility. |
| strategy_norm_return_cap | 6.0 | 1.0-20.0 | Cap applied to each normalized daily return before accumulation. |
| strategy_entry_forecast | 2.0 | 0.5-20.0 | Absolute forecast threshold required for new entries. |
| strategy_forecast_cap | 20.0 | 2.0-50.0 | Maximum absolute value of the final forecast. |
| strategy_atr_period | 20 | 2-100 | D1 ATR period used for the emergency stop. |
| strategy_stop_atr_mult | 2.5 | 0.5-10.0 | ATR multiple for the emergency stop. |
| strategy_spread_filter | true | true/false | Enables the card spread cap. |
| strategy_spread_days | 20 | 2-100 | D1 spread sample length for the median spread cap. |
| strategy_spread_mult | 2.0 | 0.5-10.0 | Maximum current spread as a multiple of median spread. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - FX major with continuous D1 history suitable for normalized return momentum.
- GBPUSD.DWX - FX major with continuous D1 history suitable for normalized return momentum.
- USDJPY.DWX - FX major with continuous D1 history suitable for normalized return momentum.
- GDAXI.DWX - Matrix-verified DAX proxy for the card's GER40.DWX index exposure.
- NDX.DWX - Liquid US index exposure listed in the card universe.
- WS30.DWX - Liquid US index exposure listed in the card universe.
- XAUUSD.DWX - Metal exposure listed in the card universe.

**Explicitly NOT for:**
- GER40.DWX - Card-stated symbol is not present in `dwx_symbol_matrix.csv`; ported to GDAXI.DWX.
- SP500.DWX - Valid custom symbol, but not required by this card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_D1) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | days |
| Expected drawdown profile | Trend-following drawdowns during range-bound or choppy regimes. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 2a380bee-1ec4-50d1-a348-b10fac642c7a
**Source type:** blog
**Pointer:** https://qoppac.blogspot.com/2017/06/some-more-trading-rules.html and https://qoppac.blogspot.com/2021/12/my-trading-system.html
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1208_carver-normmom.md`

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
| v1 | 2026-06-23 | Initial build from card | bb4f158a-39ae-4b0c-87b3-bc731bcc66c5 |
