# QM5_12530_chan-xsec-lowvol - Strategy Spec

**EA ID:** QM5_12530
**Slug:** chan-xsec-lowvol
**Source:** cfeee113-154e-549a-9fba-501b7e3160c0 (see `strategy-seeds/sources/cfeee113-154e-549a-9fba-501b7e3160c0/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA evaluates a fixed DWX macro basket once per completed D1 bar. For each symbol it computes a 5-bar percent return, compares it with the basket mean return, and builds a contrarian score `s_i = -(r_i - r_m)`. It trades only symbols that are both in the highest absolute-score group and in the lowest 5-bar close-standard-deviation group. A selected symbol is bought when its normalized target weight is above +0.05, sold when below -0.05, and closed when it leaves the selected group or the target sign no longer supports the open side.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_return_lookback_d1` | 5 | 3-10 | D1 bars used for percent return. |
| `strategy_stddev_window_d1` | 5 | 5-20 | D1 bars used for close standard deviation. |
| `strategy_top_divergence_n` | 3 | 2-5 | Number of symbols kept by absolute contrarian score. |
| `strategy_low_vol_n` | 3 | 2-5 | Number of symbols kept by lowest close standard deviation. |
| `strategy_min_abs_weight` | 0.05 | 0.00-1.00 | Minimum absolute normalized target weight required for entry or continued hold. |
| `strategy_min_active_symbols` | 5 | 1-8 | Minimum basket symbols with usable D1 data. |
| `strategy_atr_period` | 20 | 5-100 | ATR period for emergency stop. |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.0 | ATR multiple for emergency stop distance. |
| `strategy_spread_median_days` | 60 | 0-252 | D1 bars used for the median spread entry guard. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX component of the card's macro basket.
- `GBPUSD.DWX` - liquid FX component of the card's macro basket.
- `USDJPY.DWX` - liquid FX component of the card's macro basket.
- `AUDUSD.DWX` - liquid FX component of the card's macro basket.
- `USDCAD.DWX` - liquid FX component of the card's macro basket.
- `NDX.DWX` - liquid US equity-index component of the card's macro basket.
- `WS30.DWX` - liquid US equity-index component of the card's macro basket.
- `XAUUSD.DWX` - liquid gold component of the card's macro basket.

**Explicitly NOT for:**
- Symbols outside the registered eight-symbol DWX basket - the cross-sectional ranking depends on this fixed universe.

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
| Trades / year / symbol | 60 |
| Typical hold time | days, with daily rebalance checks |
| Expected drawdown profile | Sudden volatility expansion is the main adverse regime; emergency stop bounds each symbol trade. |
| Regime preference | cross-sectional mean reversion with low-volatility filter |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** cfeee113-154e-549a-9fba-501b7e3160c0
**Source type:** blog
**Pointer:** Teddy Koker, "Improving Cross Sectional Mean Reversion Strategy in Python", published 2019-05-05, https://teddykoker.com/2019/05/improving-cross-sectional-mean-reversion-strategy-in-python/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12530_chan-xsec-lowvol.md`

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
| v1 | 2026-06-18 | Initial build from card | 2563e53d-6913-4b12-929a-0927c8619f59 |
