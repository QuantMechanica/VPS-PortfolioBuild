# QM5_12947_mql5-ha-ema-trend-card - Strategy Spec

**EA ID:** QM5_12947
**Slug:** `mql5-ha-ema-trend-card`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

The EA evaluates completed H1 candles for trend-following signals combining Smoothed Heiken Ashi (HA) candle flips with an Exponential Moving Average (EMA) baseline filter and slope confirmation. A Long entry is triggered when the smoothed Heiken Ashi flips bullish (green), price closes above the EMA, and the EMA slope is positive (at least 0.1 * ATR14 over 5 bars). A Short entry is triggered when smoothed Heiken Ashi flips bearish (red), price closes below the EMA, and the EMA slope is negative. Protective stop loss is placed at ATR(14) * 2.0 or beyond the signal candle extreme (low for Longs, high for Shorts), whichever is wider. Take profit is placed at a hard 2R distance. Discretionary exits occur if smoothed Heiken Ashi flips against the trade or price crosses back over the EMA filter.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_pre_smooth_period` | 6 | 1-50 | Pre-smoothing EMA period applied to raw OHLC prices. |
| `strategy_post_smooth_period` | 2 | 1-20 | Post-smoothing SMA period applied to Heiken Ashi values. |
| `strategy_ha_seed_bars` | 120 | 20-300 | Historical seed bar depth for Heiken Ashi recursion. |
| `strategy_ema_period` | 50 | 10-200 | EMA baseline trend filter period. |
| `strategy_ema_slope_lookback` | 5 | 1-20 | Lookback bars for EMA slope calculation. |
| `strategy_ema_min_slope_atr_ratio` | 0.1 | 0.0-1.0 | Minimum slope delta as a fraction of ATR(14). |
| `strategy_atr_period` | 14 | 1-100 | ATR period for stop distance and slope scaling. |
| `strategy_atr_sl_mult` | 2.0 | 0.5-10.0 | ATR multiplier for protective stop loss distance. |
| `strategy_tp_r_mult` | 2.0 | 1.0-5.0 | Reward-to-risk ratio multiplier for hard take-profit. |
| `strategy_max_spread_points` | 0 | 0-100000 | Optional maximum spread filter in points; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Major FX pair with continuous liquid OHLC data on Darwinex.
- `GBPUSD.DWX` - Major FX pair with high trend follow-through.
- `GDAXI.DWX` - Major European equity index (DAX 40 / GER40 port) with strong intraday trend momentum.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline phases require canonical `.DWX` symbols from `dwx_symbol_matrix.csv`.

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
| Trades / year / symbol | `45` |
| Typical hold time | Several hours to multiple days until 2R TP or trend flip. |
| Expected drawdown profile | Trend-following profile with tight ATR-based risk control. |
| Regime preference | Trending momentum regimes with clean directional swings. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** `MQL5 article`
**Pointer:** Christian Benjamin, "Price Action Analysis Toolkit Development (Part 56): EMA Filtered Smoothed Heiken Ashi in MQL5", MQL5 Articles, 2025-12-22, https://www.mql5.com/en/articles/20851
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12947_mql5-ha-ema-trend-card.md`

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
| v1 | 2026-08-22 | Initial build from card | Task fb7ed34a-46f1-479f-9f1c-b9b0ae91914e |
