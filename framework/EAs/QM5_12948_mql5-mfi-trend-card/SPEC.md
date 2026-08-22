# QM5_12948_mql5-mfi-trend-card - Strategy Spec

**EA ID:** QM5_12948
**Slug:** `mql5-mfi-trend-card`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

The EA evaluates completed H1 candles for trend-following pullbacks using the Money Flow Index (MFI) on tick volume filtered by a 100-period Exponential Moving Average (EMA). In an uptrend (Close > EMA100), an MFI pullback below 50 triggers a Long entry. In a downtrend (Close < EMA100), an MFI pullback above 50 triggers a Short entry. Volatility is gated by a baseline filter requiring ATR(14) to be at least 50% of ATR(100) to avoid dead market ranges. Protective stops are placed at 1.5 * ATR(14) from entry. Positions are closed when MFI reaches profit targets (MFI >= 70 for Longs, MFI <= 30 for Shorts) or when the trend filter flips (Close < EMA100 for Longs, Close > EMA100 for Shorts). Only one position per magic is held at any time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_mfi_period` | 24 | 1-100 | MFI indicator period calculated on tick volume. |
| `strategy_ema_period` | 100 | 10-500 | EMA trend filter period on close prices. |
| `strategy_mfi_long_trigger` | 50.0 | 10-90 | MFI upper threshold for buy pullback signal. |
| `strategy_mfi_short_trigger` | 50.0 | 10-90 | MFI lower threshold for sell pullback signal. |
| `strategy_mfi_long_exit` | 70.0 | 50-100 | MFI level triggering Long take-profit exit. |
| `strategy_mfi_short_exit` | 30.0 | 0-50 | MFI level triggering Short take-profit exit. |
| `strategy_atr_period` | 14 | 1-100 | Fast ATR period for stop loss and volatility ratio. |
| `strategy_atr_slow_period` | 100 | 20-500 | Slow ATR baseline period. |
| `strategy_atr_sl_mult` | 1.5 | 0.5-10.0 | Multiplier of ATR(14) for protective stop distance. |
| `strategy_atr_min_ratio` | 0.5 | 0.0-2.0 | Minimum ratio of ATR(14) to ATR(100) to allow trade entry. |
| `strategy_max_spread_points` | 0 | 0-100000 | Optional maximum spread filter in points; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Major FX pair with high liquidity and tick volume on Darwinex.
- `GBPUSD.DWX` - Major FX pair with high liquidity and tick volume on Darwinex.
- `XAUUSD.DWX` - Liquid precious metal CFD with robust trend and pullback dynamics.

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
| Trades / year / symbol | `75` |
| Typical hold time | Intraday to several days depending on MFI exit / trend duration. |
| Expected drawdown profile | Moderate trend-pullback drawdown with fixed ATR risk controls. |
| Regime preference | Trending markets with standard volatility. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** `MQL5 article`
**Pointer:** Mohamed Abdelmaaboud, "Learn how to design a trading system by MFI", MQL5 Articles, 2022-06-07, https://www.mql5.com/en/articles/11037
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12948_mql5-mfi-trend-card.md`

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
| v1 | 2026-08-22 | Initial build from card | Task fc522a96-49a9-498e-9a1e-9d5a77e31c99 |
