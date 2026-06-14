# QM5_10885_risk-carry-vol - Strategy Spec

**EA ID:** QM5_10885
**Slug:** risk-carry-vol
**Source:** 8ef51a3a-ad3e-53af-90b6-e0fb4c8f5b38 (see `strategy-seeds/sources/8ef51a3a-ad3e-53af-90b6-e0fb4c8f5b38/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

On the first tradable D1 bar of a calendar month, the EA ranks the seven approved DWX FX pairs by positive broker swap carry divided by realised 63-day annualised log-return volatility. It selects the top five positive carry-to-volatility directions and opens the current chart symbol only when that symbol-direction is in the selected set. Existing positions are closed at the monthly rebalance when the symbol is no longer selected or the selected direction changes. Any open position is also closed when current realised volatility exceeds 2.5 times the symbol's rolling 252-day median realised volatility.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_vol_lookback` | 63 | 42-126 | D1 log-return lookback used for realised volatility and carry score denominator. |
| `strategy_median_lookback` | 252 | 126-504 | Number of rolling volatility observations used for the volatility median and shock filter. |
| `strategy_basket_size` | 5 | 3-7 | Number of positive carry-to-vol directions selected at monthly rebalance. |
| `strategy_vol_shock_mult` | 2.5 | 2.0-3.0 | Immediate exit threshold as a multiple of the 252-day median realised volatility. |
| `strategy_atr_period` | 20 | 10-40 | ATR period for the initial stop. |
| `strategy_atr_stop_mult` | 2.25 | 1.75-2.75 | ATR multiplier for the initial stop. |
| `strategy_high_vol_risk_factor` | 0.5 | 0.25-1.0 | Risk weight applied when realised volatility is above its median. |
| `strategy_rebalance_window_days` | 7 | 1-7 | Calendar-day window used to identify the first available D1 monthly rebalance bar. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair in the card's approved DWX carry basket.
- `GBPUSD.DWX` - major FX pair in the card's approved DWX carry basket.
- `USDJPY.DWX` - major FX pair in the card's approved DWX carry basket.
- `AUDUSD.DWX` - major FX pair in the card's approved DWX carry basket.
- `USDCAD.DWX` - major FX pair in the card's approved DWX carry basket.
- `USDCHF.DWX` - major FX pair in the card's approved DWX carry basket.
- `NZDUSD.DWX` - major FX pair in the card's approved DWX carry basket.

**Explicitly NOT for:**
- Non-FX symbols - this card requires broker swap carry by FX pair direction.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `10` |
| Typical hold time | Monthly carry-to-risk rebalance; positions usually hold until next monthly rebalance unless volatility shock exits first. |
| Expected drawdown profile | Lower-volatility carry can still crash during correlated FX deleveraging; risk is reduced when volatility is above median. |
| Regime preference | FX carry with volatility filter. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8ef51a3a-ad3e-53af-90b6-e0fb4c8f5b38
**Source type:** article
**Pointer:** https://www.risk.net/foreign-exchange/1504798/jp-morgan-designs-emerging-market-forex-carry-index
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10885_risk-carry-vol.md`

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
| v1 | 2026-06-14 | Initial build from card | 06c7d5c5-a0e7-4938-8f60-666090ce0249 |
