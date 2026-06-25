# QM5_1219_carver-accel - Strategy Spec

**EA ID:** QM5_1219
**Slug:** carver-accel
**Source:** 2a380bee-1ec4-50d1-a348-b10fac642c7a
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades Rob Carver's EWMAC acceleration rule on closed D1 bars. It computes a volatility-normalised EWMAC value as `(EMA(close, Lfast) - EMA(close, 4 * Lfast)) / StdDev(close-to-close changes, 25)`, then subtracts the EWMAC value from `Lfast` bars ago. The result is multiplied by a fixed forecast scalar, capped to `[-20, +20]`, and a long opens above `+EntryForecast` while a short opens below `-EntryForecast`. Longs close when the cached closed-bar forecast falls below zero, and shorts close when it rises above zero.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_period | 32 | 16-64 P3 sweep | Fast EMA period; slow period is always `4 * fast`. |
| strategy_vol_lookback | 25 | >= 2 | Close-to-close change standard deviation lookback. |
| strategy_forecast_scalar | 10.0 | > 0 | Fixed multiplier applied to raw acceleration forecast. |
| strategy_entry_forecast | 2.0 | > 0 | Long/short entry threshold around zero. |
| strategy_forecast_cap | 20.0 | > 0 | Absolute forecast cap after scaling. |
| strategy_atr_period | 20 | >= 2 | ATR period for the emergency stop. |
| strategy_stop_atr_mult | 2.5 | 2.0-3.0 P3 sweep | ATR multiple for the emergency stop. |
| strategy_min_extra_bars | 30 | >= 0 | Extra D1 warmup bars required beyond slow plus fast periods. |
| strategy_max_spread_points | 0 | >= 0 | Optional current-spread cap in points; zero disables so DWX zero-spread tests do not fail closed. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed FX major with DWX matrix support.
- GBPUSD.DWX - card-listed FX major with DWX matrix support.
- USDJPY.DWX - card-listed FX major with DWX matrix support.
- GDAXI.DWX - matrix-canonical DAX symbol used for the card's GER40 exposure.
- NDX.DWX - card-listed US index with DWX matrix support.
- WS30.DWX - card-listed US index with DWX matrix support.
- XAUUSD.DWX - card-listed gold exposure using the matrix `.DWX` symbol.
- XTIUSD.DWX - card-listed oil exposure using the matrix `.DWX` symbol.

**Explicitly NOT for:**
- GER40.DWX - not present in `dwx_symbol_matrix.csv`; use GDAXI.DWX.
- Non-DWX symbols - research and backtest artifacts must keep the `.DWX` suffix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 140 |
| Typical hold time | Multi-day trend-following holds; exits on forecast sign loss or emergency ATR stop. |
| Expected drawdown profile | Trend-family drawdowns during choppy or mean-reverting regimes. |
| Regime preference | Trend acceleration / volatility-normalised momentum improvement. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 2a380bee-1ec4-50d1-a348-b10fac642c7a
**Source type:** blog plus open-source code
**Pointer:** https://qoppac.blogspot.com/2021/12/my-trading-system.html and https://github.com/pst-group/pysystemtrade/blob/develop/systems/provided/rules/accel.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1219_carver-accel.md`

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
| v1 | 2026-06-25 | Initial build from card | e506d7ef-317b-4d66-a46b-ef7233775fdf |
