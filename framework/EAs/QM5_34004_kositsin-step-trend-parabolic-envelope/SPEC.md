# QM5_34004_kositsin-step-trend-parabolic-envelope — Strategy Spec

**EA ID:** QM5_34004
**Slug:** kositsin-step-trend-parabolic-envelope
**Source:** kositsin-step-trend-parabolic-envelope-official-source
**Author of this spec:** Gemini
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

The strategy implements Nikolay Kositsin's Step-Trend Parabolic Envelope system on H1 closed bars.

Discrete step quantization prevents whipsaws in flat markets by keeping the trend line completely horizontal until price moves by at least one full ATR-derived step size (0.80 × ATR(14)). Long entry triggers when the closed bar price is above Step-MA, Step-MA has stepped up relative to the previous bar, and Parabolic SAR is below the bar low. Short entry triggers when the closed bar price is below Step-MA, Step-MA has stepped down relative to the previous bar, and Parabolic SAR is above the bar high. Initial stop loss is placed at Step_MA ± 0.5 × Step_Size and take profit at 2.0× SL distance (1:2.0 R:R).

---

## 2. Parameters

Table of strategy-specific parameters declared in the EA:

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 10-30 | ATR volatility lookback period |
| `strategy_step_mult` | 0.80 | 0.50-1.50 | ATR multiplier for discrete step size |
| `strategy_sar_step` | 0.02 | 0.01-0.05 | Parabolic SAR acceleration step |
| `strategy_sar_max` | 0.20 | 0.10-0.50 | Parabolic SAR maximum acceleration |
| `strategy_tp_rr_mult` | 2.0 | 1.0-4.0 | Take profit risk-to-reward multiplier |
| `strategy_spread_atr_period` | 14 | 7-28 | Spread filter ATR period |
| `strategy_spread_atr_mult` | 1.8 | 1.0-3.0 | Spread filter threshold in ATR multiples |
| `strategy_step_lookback` | 50 | 20-100 | Lookback bars for Step-MA path reconstruction |

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for:

**Designed for:**
- `EURUSD.DWX` — Primary liquid FX major with clear trending structures
- `XAUUSD.DWX` — Gold commodity with persistent directional impulses
- `GBPJPY.DWX` — High-beta currency pair with pronounced trend moves

**Explicitly NOT for:**
- `AUDCAD.DWX` — Low-volatility rangebound pair with choppy trends

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H1)` |

---

## 5. Expected Behaviour

How this EA should behave in production:

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | 1-3 days |
| Expected drawdown profile | <15% total drawdown |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** kositsin-step-trend-parabolic-envelope-official-source
**Source type:** paper
**Pointer:** Kositsin, N. (2015). Open-Source Production Trading Systems. MQL5 CodeBase Library.
**R1–R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_34004_kositsin-step-trend-parabolic-envelope.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | Initial build from card | e48c6a6c-1935-4945-9e47-e420f9fb15df |
