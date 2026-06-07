# QM5_11070_persistent-anti - Strategy Spec

**EA ID:** QM5_11070
**Slug:** `persistent-anti`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed W1 bars. It compares close-to-close direction over a 10-bar lookback and counts whether each direction matched or opposed the prior direction. If persistence exceeds `Ratio * N`, the default reverse mode trades opposite the previous completed bar direction; if antipersistence exceeds the same threshold, it trades with the previous completed bar direction. Existing positions are closed when the selected weekly direction flips or when neither threshold is met.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_bars` | 10 | 1+ | Number of W1 direction comparisons used for persistence counts. |
| `strategy_ratio` | 0.66 | > 0 | Threshold multiplier; signal requires count greater than ratio times lookback. |
| `strategy_reverse` | true | true/false | When true, fade persistence and follow antipersistence as specified by the card. |
| `strategy_atr_period` | 20 | 1+ | ATR period for the catastrophic hard stop. |
| `strategy_atr_sl_mult` | 3.0 | > 0 | ATR multiplier for the catastrophic hard stop. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source example and directly testable DWX FX major.
- `GBPUSD.DWX` - liquid DWX FX major suitable for the same weekly persistence rule.
- `USDJPY.DWX` - liquid DWX FX major suitable for the same weekly persistence rule.
- `USDCAD.DWX` - liquid DWX FX major suitable for the same weekly persistence rule.

**Explicitly NOT for:**
- `SP500.DWX` - the approved card names a FX basket, not an index basket.
- `XAUUSD.DWX` - the approved card names FX majors, not metals.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `W1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 24 |
| Typical hold time | Weekly regime holds until flip or stand-down, usually days to weeks. |
| Expected drawdown profile | Bounded by RISK_FIXED sizing and ATR(20) x 3 catastrophic stop. |
| Regime preference | Persistence and anti-persistence mean reversion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `GitHub / MQL5 source`
**Pointer:** `https://github.com/EarnForex/PersistentAnti` and source article `https://www.earnforex.com/metatrader-expert-advisors/PersistentAnti/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11070_persistent-anti.md`

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
| v1 | 2026-06-07 | Initial build from card | ed9d135b-fcc4-4ddc-9d60-8d9ee73c89e7 |
