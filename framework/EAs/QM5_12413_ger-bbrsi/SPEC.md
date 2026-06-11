# QM5_12413_ger-bbrsi - Strategy Spec

**EA ID:** QM5_12413
**Slug:** ger-bbrsi
**Source:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades completed M5 Bollinger Band re-entry signals confirmed by RSI. A long opens when RSI and close were below the lower band two bars ago, then RSI and close re-enter above the lower band on the last closed bar while still below RSI 50 and the middle band. A short is the symmetric upper-band re-entry from above RSI 70. The stop is placed beyond the breached band by a coefficient of the band half-width, TP is 1R, and profitable positions can close on a completed-bar cross through the middle band.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_bb_len | 500 | 250-750 | Bollinger Bands period. |
| strategy_bb_dev | 2.0 | 1.5-2.5 | Bollinger Bands standard-deviation multiplier. |
| strategy_rsi_len | 7 | 5-10 | RSI period used for re-entry confirmation. |
| strategy_rsi_lower | 30.0 | fixed by card | Lower RSI threshold for long re-entry. |
| strategy_rsi_middle | 50.0 | fixed by card | Middle RSI threshold used to keep entries before full mean reversion. |
| strategy_rsi_upper | 70.0 | fixed by card | Upper RSI threshold for short re-entry. |
| strategy_sl_coef | 0.9 | 0.5-1.2 | Multiplier applied to band half-width beyond the entry band for SL. |
| strategy_tp_coef | 1.0 | fixed by card | TP multiplier of absolute entry-to-stop distance. |
| strategy_close_midband_enabled | true | true/false | Enables profitable middle-band cross close from the source close rule. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - Card cites XAUUSD M5 source usage and DWX metal data is available.
- EURUSD.DWX - Card R3 includes this liquid FX CFD for P2 portability.
- GBPUSD.DWX - Card R3 includes this liquid FX CFD for P2 portability.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - build-time registration is limited to verified DWX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday; minutes to hours until 1R TP, SL, Friday close, or profitable middle-band cross. |
| Expected drawdown profile | Mean-reversion losses cluster during strong one-way band expansions. |
| Regime preference | Mean-reversion after Bollinger Band overshoot. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233
**Source type:** code
**Pointer:** https://github.com/geraked/metatrader5/blob/master/Experts/BBRSI.mq5
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12413_ger-bbrsi.md`

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
| v1 | 2026-06-11 | Initial build from card | 28cf36b2-cd25-43e8-8357-09ec2e08f96e |
