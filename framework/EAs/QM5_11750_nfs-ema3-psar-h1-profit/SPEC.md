# QM5_11750_nfs-ema3-psar-h1-profit - Strategy Spec

**EA ID:** QM5_11750
**Slug:** nfs-ema3-psar-h1-profit
**Source:** 781e6542-cf6d-5b05-b351-2c769d7fb926 (see `strategy-seeds/sources/781e6542-cf6d-5b05-b351-2c769d7fb926/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades H1 trend continuation when price crosses through all three EMA levels at once. A long setup requires the previous closed bar to be at or below EMA(10), the latest closed bar to close above EMA(10), EMA(25), and EMA(50), and Parabolic SAR to be below price. A short setup is the mirrored rule with price closing below all three EMAs and Parabolic SAR above price. Exits occur when a long closes back below EMA(10), or a short closes back above EMA(10); every entry also carries a 2 x ATR(14) stop and 3 x ATR(14) take-profit safety cap.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | M1-MN1 | Timeframe used for EMA, PSAR, ATR, entry, and exit checks. |
| `strategy_ema_fast` | `10` | `>= 1` | Fast EMA used for initial cross and strategy exit. |
| `strategy_ema_mid` | `25` | `>= 1` | Middle EMA that price must clear for entry. |
| `strategy_ema_slow` | `50` | `>= 1` | Slow EMA that price must clear for entry. |
| `strategy_psar_step` | `0.02` | `> 0` | Parabolic SAR step parameter. |
| `strategy_psar_maximum` | `0.20` | `> 0` | Parabolic SAR maximum parameter. |
| `strategy_atr_period` | `14` | `>= 1` | ATR period for stop and take-profit distances. |
| `strategy_atr_sl_mult` | `2.0` | `> 0` | Initial stop distance as ATR multiple. |
| `strategy_atr_tp_mult` | `3.0` | `> 0` | Hard take-profit cap as ATR multiple. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - DWX FX major from the card's target basket.
- `GBPUSD.DWX` - DWX FX major from the card's target basket.
- `USDCHF.DWX` - DWX FX major and the source's primary example pair.
- `USDJPY.DWX` - DWX FX major from the card's target basket.

**Explicitly NOT for:**
- `SP500.DWX` - index exposure is outside the card's FX-major universe.
- `XAUUSD.DWX` - metals exposure is outside the card's FX-major universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | H1 trend hold, usually hours to a few days |
| Expected drawdown profile | Trend-following losses should cluster during choppy EMA recross periods |
| Regime preference | Trend-following / volatility-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 781e6542-cf6d-5b05-b351-2c769d7fb926
**Source type:** book / compilation PDF
**Pointer:** Local Source PDF `452915895-9-Forex-Systems-pdf.pdf`, pages 6-7.
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11750_nfs-ema3-psar-h1-profit.md`

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
| v1 | 2026-06-11 | Initial build from card | 65aa5d44-90ae-4efb-b683-e67d514d2fe2 |
