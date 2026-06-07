# QM5_11071_spike-reversal - Strategy Spec

**EA ID:** QM5_11071
**Slug:** `spike-reversal`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (see approved card source citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed D1 bars. A short signal occurs when the completed bar makes a new high above the prior three highs by at least 0.3 percent and closes in the lower half of its range. A long signal occurs when the completed bar makes a new low below the prior three lows by at least 0.3 percent and closes in the upper half of its range. Positions use an ATR(20) x 3 catastrophic stop, close after 11 D1 bars, reset the hold timer on a same-direction signal, and close for reversal when an opposite signal appears.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_hold_bars` | 11 | 1+ | Number of D1 bars to hold before timed exit unless reset by a same-direction signal. |
| `strategy_bars_number` | 3 | 1+ | Count of prior D1 bars used for the spike extreme comparison. |
| `strategy_percentage_diff` | 0.003 | > 0 | Minimum displacement from the prior high or low extreme. |
| `strategy_close_fraction` | 0.5 | 0-1 | Required close location within the completed bar range. |
| `strategy_atr_period` | 20 | 1+ | ATR period for the catastrophic hard stop. |
| `strategy_atr_sl_mult` | 3.0 | > 0 | ATR multiplier for the catastrophic hard stop. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `USDCAD.DWX` - source example and directly testable DWX FX major.
- `EURUSD.DWX` - liquid DWX FX major in the approved R3 basket.
- `GBPUSD.DWX` - liquid DWX FX major in the approved R3 basket.
- `USDJPY.DWX` - liquid DWX FX major in the approved R3 basket.

**Explicitly NOT for:**
- `SP500.DWX` - the approved card names a FX basket, not an index basket.
- `XAUUSD.DWX` - the approved card names FX majors, not metals.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Typical hold time | About 11 D1 bars unless reset by same-direction spike or reversed earlier. |
| Expected drawdown profile | Bounded by RISK_FIXED sizing and ATR(20) x 3 catastrophic stop. |
| Regime preference | Mean-reversion after spike rejection bars. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `GitHub / MQL5 source`
**Pointer:** `https://github.com/EarnForex/Spike-Trader` and source article `https://www.earnforex.com/metatrader-expert-advisors/Spike-Trader/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11071_spike-reversal.md`

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
| v1 | 2026-06-07 | Initial build from card | 7a204d95-9c6d-4053-81a4-4d6af803b1b1 |
