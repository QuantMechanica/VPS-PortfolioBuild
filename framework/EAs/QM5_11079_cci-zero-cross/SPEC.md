# QM5_11079_cci-zero-cross - Strategy Spec

**EA ID:** QM5_11079
**Slug:** `cci-zero-cross`
**Source:** `0693c604-4f96-56ef-be79-15efe9f48b86` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA evaluates completed H1 bars with CCI(14) applied to close. It opens long when the latest closed CCI is above zero and the previous closed CCI was below zero, and opens short on the inverse zero-line cross. It keeps one active position per symbol and magic, exits on the next opposite CCI zero-line signal, and uses an ATR(14) catastrophic stop with an ATR take-profit for bounded P2 testing.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cci_period` | 14 | 2-200 | CCI lookback applied to close for zero-line cross detection. |
| `strategy_atr_period` | 14 | 1-200 | ATR lookback used for catastrophic stop and bounded TP distance. |
| `strategy_atr_sl_mult` | 2.5 | 0.1-20.0 | ATR multiple for the catastrophic stop. |
| `strategy_atr_tp_mult` | 3.5 | 0.0-30.0 | ATR multiple for optional bounded-test take-profit; zero disables TP. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 includes this major FX pair and CCI is OHLC-derived.
- `GBPUSD.DWX` - Card R3 includes this major FX pair and CCI is OHLC-derived.
- `USDJPY.DWX` - Card R3 includes this major FX pair and CCI is OHLC-derived.
- `XAUUSD.DWX` - Card R3 includes gold and CCI is OHLC-derived.

**Explicitly NOT for:**
- `SP500.DWX` - Not in the card's stated P2 basket for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | `hours to days` |
| Expected drawdown profile | Catastrophic ATR stop bounds single-trade losses while opposite signals can exit first. |
| Regime preference | `trend-following oscillator-cross` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0693c604-4f96-56ef-be79-15efe9f48b86`
**Source type:** `GitHub / indicator source`
**Pointer:** `https://github.com/EarnForex/CCI-Arrows`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11079_cci-zero-cross.md`

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
| v1 | 2026-06-07 | Initial build from card | 07980d82-acd3-4241-94bb-e1186e1dc000 |
