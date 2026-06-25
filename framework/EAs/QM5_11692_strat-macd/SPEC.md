# QM5_11692_strat-macd - Strategy Spec

**EA ID:** QM5_11692
**Slug:** `strat-macd`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA computes the MACD histogram on completed H1 bars using MACD(12,26,9). It opens long when the histogram is above zero and opens short when the histogram is below zero. It closes an open long when the histogram crosses down through zero, closes an open short when the histogram crosses up through zero, and flattens when the histogram is exactly zero. The original source has no protective stop, so the V5 implementation adds only an ATR catastrophic stop and no fixed take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 12 | 2-100 | Fast EMA period used by the MACD histogram. |
| `strategy_macd_slow` | 26 | 3-200 | Slow EMA period used by the MACD histogram. |
| `strategy_macd_signal` | 9 | 2-100 | Signal EMA period used by the MACD histogram. |
| `strategy_atr_period` | 14 | 2-200 | ATR period used for the catastrophic stop. |
| `strategy_sl_atr_mult` | 2.0 | 0.5-10.0 | ATR multiplier for the catastrophic stop distance. |
| `strategy_spread_pct_of_stop` | 15.0 | 0-100 | Blocks only genuinely wide modeled spreads above this percent of stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - the card names EURUSD and the close-derived MACD rule is directly portable to this liquid FX pair.
- `XAUUSD.DWX` - the card names XAUUSD and the rule uses only completed close prices available in the DWX matrix.
- `GDAXI.DWX` - matrix-available DAX CFD used as the canonical replacement for the card's `GER40.DWX` reference.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX` for DAX exposure.

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
| Trades / year / symbol | `100` |
| Typical hold time | hours to days, until the MACD histogram crosses zero |
| Expected drawdown profile | trend-following whipsaw risk during flat regimes, bounded by the ATR catastrophic stop |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** `GitHub source file`
**Pointer:** `https://github.com/diogomatoschaves/stratestic/blob/main/stratestic/strategies/moving_average/macd.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11692_strat-macd.md`

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
| v1 | 2026-06-25 | Initial build from card | 99baefd9-5287-4803-897f-e50319ed8960 |
