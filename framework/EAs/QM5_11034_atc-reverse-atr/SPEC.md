# QM5_11034_atc-reverse-atr - Strategy Spec

**EA ID:** QM5_11034
**Slug:** atc-reverse-atr
**Source:** 9441393d-5ffc-5b43-87be-bd532110f204 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA opens one market position at a time on the active symbol and magic slot. The first trade uses the configured initial direction; after a position closes, the next eligible closed H1 bar opens the opposite direction. Entries do not use a directional indicator. Exits are handled by an initial ATR hard stop, an ATR trailing stop, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_initial_direction | 1 | -1 or 1 | First trade direction, where 1 is long and -1 is short. |
| strategy_atr_period | 14 | 1+ | ATR period used for hard stop, trailing stop, and optional percentile filter. |
| strategy_atr_trail_mult | 2.0 | 0.1+ | ATR multiple for the trailing stop. |
| strategy_hard_sl_atr | 3.0 | 0.1+ | Initial disaster stop distance in ATR multiples. |
| strategy_cooldown_bars | 0 | 0+ | Closed bars to wait after a position closes before the next reversal entry. |
| strategy_min_atr_percentile | 0 | 0-100 | Optional ATR percentile threshold; 0 disables this filter. |
| strategy_atr_percentile_lookback | 250 | 1+ | Lookback bars for the optional ATR percentile filter. |
| strategy_median_spread_points | 20 | 1+ | Per-symbol median spread estimate in points for the card spread filter. |
| strategy_max_spread_median_mult | 2.0 | 0.1+ | Maximum current spread as a multiple of the median spread input. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card R3 primary FX basket member with DWX data availability.
- EURJPY.DWX - Card R3 primary FX basket member with DWX data availability.
- GBPUSD.DWX - Card R3 primary FX basket member with DWX data availability.
- GBPJPY.DWX - Card R3 primary FX basket member with DWX data availability.

**Explicitly NOT for:**
- Non-FX index or commodity symbols - The approved card defines an FX-only R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Variable, controlled by ATR trailing stop and hard SL. |
| Expected drawdown profile | Sparse reversal system with one active position and fixed-risk hard stop. |
| Regime preference | Reversal / alternating exposure; depends on ATR-trailing persistence. |
| Win rate target (qualitative) | Medium-low; edge depends on trailing winners exceeding stopped reversals. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9441393d-5ffc-5b43-87be-bd532110f204
**Source type:** article / interview
**Pointer:** https://www.mql5.com/en/articles/543 and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11034_atc-reverse-atr.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11034_atc-reverse-atr.md`

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
| v1 | 2026-06-07 | Initial build from card | 69e50253-932c-4682-b23b-fce52c9b5cdd |
