# QM5_1486_ehlers-cg-oscillator-cross-h4 - Strategy Spec

**EA ID:** QM5_1486
**Slug:** `ehlers-cg-oscillator-cross-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-02

---

## 1. Strategy Logic

This EA trades the H4 Ehlers Center-of-Gravity oscillator cross. It computes CG from the median price over 10 bars, treats the one-bar-lagged CG as the signal line, and enters long or short when the closed H4 bar crosses the signal line from a pre-cross extreme region. Entries also require D1 SMA(50) trend agreement, sufficient ATR amplitude, no recent opposite CG cross, and meaningful pre-cross CG movement. The first profit objective closes 60% at 1.5 ATR from entry; the remainder exits on an opposite CG cross, while a 24-H4-bar time stop closes trades that never reach TP1.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cg_period` | 10 | >=2 | Ehlers CG lookback window. |
| `strategy_cg_range_lookback` | 200 | >=20 | CG range lookback for the pre-cross percentile gate. |
| `strategy_extreme_fraction` | 0.40 | 0.0-1.0 | Bottom/top range fraction required before a bullish/bearish cross. |
| `strategy_macro_sma_period` | 50 | >=2 | D1 SMA period for macro trend bias. |
| `strategy_macro_slope_bars` | 5 | >=1 | D1 bars used to confirm SMA slope. |
| `strategy_atr_period` | 14 | >=2 | ATR period for volatility floor and stop sizing. |
| `strategy_atr_mean_lookback` | 200 | >=1 | ATR average lookback for the volatility floor. |
| `strategy_atr_floor_mult` | 0.60 | >0 | Current ATR must exceed this multiple of mean ATR. |
| `strategy_no_opposite_bars` | 20 | >=1 | Lookback that must contain no opposite CG cross. |
| `strategy_stability_fraction` | 0.05 | >0 | Minimum pre-cross CG movement as a fraction of the CG range. |
| `strategy_sl_atr_mult` | 2.0 | >0 | Hard stop distance in ATR multiples. |
| `strategy_tp1_atr_mult` | 1.5 | >0 | Partial close trigger in ATR multiples. |
| `strategy_tp1_close_fraction` | 0.60 | 0.0-1.0 | Position fraction closed at TP1. |
| `strategy_time_stop_h4_bars` | 24 | >=1 | H4 bars before closing a trade that has not reached TP1. |
| `strategy_spread_lookback` | 20 | >=1 | H4 bars used for the median spread filter. |
| `strategy_spread_median_mult` | 1.5 | >0 | Maximum current spread versus median historical spread. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target FX major with DWX H4 and D1 price history.
- `GBPUSD.DWX` - card target FX major with DWX H4 and D1 price history.
- `XAUUSD.DWX` - card target gold CFD with DWX H4 and D1 price history.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - not valid for DWX backtest registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1` close and SMA(50) slope |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | `up to 24 H4 bars before time stop; shorter on TP1/opposite cross` |
| Expected drawdown profile | `ATR-bounded oscillator continuation trades in daily trend regimes` |
| Regime preference | `momentum-continuation` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum / book / article`
**Pointer:** `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1486_ehlers-cg-oscillator-cross-h4.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1486_ehlers-cg-oscillator-cross-h4.md`

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
| v1 | 2026-06-26 | Initial build from card | 2e975b1b-4a87-43b1-8ad6-1644d58c5c73 |
| v2 | 2026-07-02 | Entry-only news gate; management and exits run through blackout windows | c82bfb1c-2791-4845-9d27-12a9e3792848 |
