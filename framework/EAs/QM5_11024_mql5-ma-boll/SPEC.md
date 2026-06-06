# QM5_11024_mql5-ma-boll - Strategy Spec

**EA ID:** QM5_11024
**Slug:** `mql5-ma-boll`
**Source:** `9441393d-5ffc-5b43-87be-bd532110f204` (see `strategy-seeds/sources/9441393d-5ffc-5b43-87be-bd532110f204/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates completed H1 bars. It buys when the prior H1 bar opens below the lower 20-period Bollinger Band and closes back above it, but only when the completed D1 close is above the D1 SMA(64). It sells when the prior H1 bar opens above the upper Bollinger Band and closes back below it, but only when the completed D1 close is below the D1 SMA(64). Open trades exit through fixed SL/TP, the point trailing stop, framework Friday close, or an opposite Bollinger bounce with matching opposite D1 bias.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_d1_sma_period` | 64 | 32-128 | D1 SMA baseline period for the trend filter. |
| `strategy_bb_period` | 20 | 14-30 | H1 Bollinger Band period for entry and opposite-signal exit. |
| `strategy_bb_deviation` | 2.0 | 1.5-2.5 | H1 Bollinger Band standard-deviation multiplier. |
| `strategy_atr_period` | 20 | 20 | H1 ATR period used for the minimum band-width noise filter. |
| `strategy_min_band_atr_mult` | 0.5 | 0.0+ | Minimum Bollinger band width as a multiple of ATR(20,H1). |
| `strategy_sl_points` | 160 | 120-220 | Fixed stop-loss distance in broker points. |
| `strategy_tp_points` | 310 | 200-450 | Fixed take-profit distance in broker points. |
| `strategy_trailing_points` | 50 | 0+ | Optional trailing stop distance in points; zero disables trailing. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread ceiling in points; zero disables the spread ceiling. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major with DWX OHLC availability.
- `GBPUSD.DWX` - card-listed liquid FX major with DWX OHLC availability.
- `USDJPY.DWX` - card-listed liquid FX major with DWX OHLC availability.
- `XAUUSD.DWX` - card-listed liquid metals CFD with DWX OHLC availability.

**Explicitly NOT for:**
- Non-DWX symbols - research and backtest artifacts must use the `.DWX` suffix.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom tick data is available.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1` SMA trend filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `32` |
| Typical hold time | Hours to days, bounded by opposite signal, SL/TP, trailing stop, or Friday close |
| Expected drawdown profile | Trend-filtered Bollinger mean-reversion entries with fixed-loss containment |
| Regime preference | Trend-aligned mean reversion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9441393d-5ffc-5b43-87be-bd532110f204`
**Source type:** `article`
**Pointer:** `https://www.mql5.com/en/articles/148`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11024_mql5-ma-boll.md`

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
| v1 | 2026-06-07 | Initial build from card | d7682306-1e90-48a9-ab16-b2e609fc8969 |
