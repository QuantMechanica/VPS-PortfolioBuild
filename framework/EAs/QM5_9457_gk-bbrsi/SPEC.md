# QM5_9457_gk-bbrsi — Strategy Spec

**EA ID:** QM5_9457
**Slug:** `gk-bbrsi`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175` (see `strategy-seeds/sources/3b3ec48a-0755-5187-9331-afb36e174175/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

Bollinger Band RSI Re-Entry mean-reversion on M5 bars. Computes Bollinger Bands with period 500 and 2 standard deviations plus RSI(7) on closed bar prices.

**Long entry**: bar[2] must have RSI < 30 and close < lower band (oversold breakout below band). Bar[1] then re-enters above the lower band with 30 < RSI < 50 and close < middle band (confirming mean-reversion has begun). Entry is at the current ask on the next tick after bar[1] close.

**Short entry**: bar[2] must have RSI > 70 and close > upper band (overbought breakout above band). Bar[1] then re-enters below the upper band with 50 < RSI < 70 and close > middle band. Entry is at the current bid.

**Stop loss (long)**: lower_band[1] - 0.9 * (middle_band[1] - lower_band[1]), placing the stop below the band by 90% of the half-band width. **Stop loss (short)**: upper_band[1] + 0.9 * (upper_band[1] - middle_band[1]).

**Take profit**: 1R from entry (tp_coef = 1.0, SL distance mirrored on the profit side).

**Exit rules**: Primary exit via SL/TP. Secondary: close long if close[1] crosses above the middle band; close short if close[1] crosses below middle band. Tertiary time-stop: close after 72 M5 bars regardless.

**Position gating**: one position per symbol per magic (MultipleOpenPos = false equivalent). Grid disabled.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 500 | 20-2000 | Bollinger Band period (card default 500) |
| `strategy_bb_deviation` | 2.0 | 1.0-4.0 | Bollinger Band standard deviation multiplier |
| `strategy_rsi_period` | 7 | 2-50 | RSI period (card default 7) |
| `strategy_tp_coef` | 1.0 | 0.5-5.0 | TP distance = tp_coef * SL distance (card TPCoef=1) |
| `strategy_sl_dev_mult` | 0.0 | 0.0-2.0 | SL extension beyond band: mult * band_half_width (card P2 seed=0; 0.9 candidate for Q07 sweep) |
| `strategy_max_hold_bars` | 72 | 1-500 | Time-stop: close after N M5 bars (card default 72) |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — card primary test symbol; M5 Bollinger/RSI re-entry suits gold's mean-reverting intraday behaviour
- `EURUSD.DWX` — liquid FX major; card R3 passes for all DWX CFD majors
- `GBPUSD.DWX` — liquid FX major; included in card target_symbols
- `USDJPY.DWX` — liquid FX major; included in card target_symbols

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only, not live-routable; card does not list it

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~160 |
| Typical hold time | minutes to hours (M5 bars; max 72 bars = 6 hours) |
| Expected drawdown profile | Moderate intraday; mean-reversion losses occur on trending days |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** `forum` (GitHub public repository)
**Pointer:** `https://github.com/geraked/metatrader5/blob/main/Experts/BBRSI.mq5` (commit d3eb29c382acf715727d5cd6a0414151e821fc2d)
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9457_gk-bbrsi.md`

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
| v1 | 2026-06-11 | Initial build from card | Initial commit |
