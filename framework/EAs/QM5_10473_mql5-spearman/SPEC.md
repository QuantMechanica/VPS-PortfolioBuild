# QM5_10473_mql5-spearman - Strategy Spec

**EA ID:** QM5_10473
**Slug:** `mql5-spearman`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA calculates a Spearman rank correlation histogram from the last closed bars by comparing the rank of closing prices with their time order. It enters long when the histogram crosses upward through zero on a closed H4 bar and enters short when it crosses downward through zero. Long positions close when the histogram crosses downward through zero, and short positions close when it crosses upward through zero. Each entry uses a protective stop at 1.5 x ATR(14) and a target at 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_spearman_period` | 14 | 3-64 | Closed-bar lookback used for the Spearman rank correlation value. |
| `strategy_atr_period` | 14 | 1-200 | ATR period used for the protective stop. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | Multiplier applied to ATR for the initial stop distance. |
| `strategy_tp_r_multiple` | 2.0 | 0.1-10.0 | Take-profit distance in multiples of initial stop risk. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURJPY.DWX` - source baseline was EURJPY H4 and the symbol is present in the DWX matrix.
- `EURUSD.DWX` - liquid DWX FX major suitable for the portable rank-correlation oscillator.
- `GBPUSD.DWX` - liquid DWX FX major suitable for the portable rank-correlation oscillator.
- `USDJPY.DWX` - liquid DWX FX major suitable for the portable rank-correlation oscillator.
- `AUDUSD.DWX` - liquid DWX FX major suitable for the portable rank-correlation oscillator.

**Explicitly NOT for:**
- Equity index and commodity `.DWX` symbols - the card targets FX majors and crosses, not index or commodity regimes.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | `hours to days` |
| Expected drawdown profile | `oscillator reversal losses bounded by ATR stop` |
| Regime preference | `oscillator-reversal / rank-correlation zero-cross` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/23279`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10473_mql5-spearman.md`

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
| v1 | 2026-05-28 | Initial build from card | 29145c27-30a1-4186-80f2-14d3977ef0f8 |
