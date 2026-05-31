# QM5_10495_mql5-sep-trade - Strategy Spec

**EA ID:** QM5_10495
**Slug:** mql5-sep-trade
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades confirmed moving-average crosses on the close of an M15 bar. A long entry is allowed when the first EMA crosses above the second EMA and the configured MA-distance, ATR, and StdDev thresholds pass. A short entry is allowed when the first EMA crosses below the second EMA and the sell-side thresholds pass. Exits use ATR-based SL, a fixed 2.0R take-profit, framework Friday close, and a discretionary close on the opposite confirmed MA cross.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_first_ma_period | 20 | 2-500 | First EMA period used for cross detection. |
| strategy_second_ma_period | 50 | 2-500 | Second EMA period used for cross detection. |
| strategy_atr_period | 14 | 2-500 | ATR period for volatility filter and stop distance. |
| strategy_stddev_period | 20 | 2-500 | StdDev period for the volatility filter. |
| strategy_buy_min_ma_points | 0.0 | >= 0 | Minimum first-vs-second EMA distance for long entries, in points. |
| strategy_sell_min_ma_points | 0.0 | >= 0 | Minimum first-vs-second EMA distance for short entries, in points. |
| strategy_buy_min_atr_points | 0.0 | >= 0 | Minimum ATR value for long entries, in points. |
| strategy_sell_min_atr_points | 0.0 | >= 0 | Minimum ATR value for short entries, in points. |
| strategy_buy_min_std_points | 0.0 | >= 0 | Minimum StdDev value for long entries, in points. |
| strategy_sell_min_std_points | 0.0 | >= 0 | Minimum StdDev value for short entries, in points. |
| strategy_atr_sl_mult | 1.5 | > 0 | Stop-loss distance as ATR multiple. |
| strategy_take_profit_rr | 2.0 | > 0 | Take-profit distance in units of initial risk. |
| strategy_max_spread_points | 30 | >= 0 | Maximum allowed current spread for M15 entry, in points. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair from the card's R3 basket.
- GBPUSD.DWX - liquid major FX pair from the card's R3 basket.
- USDJPY.DWX - liquid major FX pair from the card's R3 basket.
- XAUUSD.DWX - liquid metal instrument from the card's R3 basket.

**Explicitly NOT for:**
- Non-DWX symbols - the build registers only verified symbols from `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | M15 trend hold until SL, TP, Friday close, or opposite MA cross |
| Expected drawdown profile | Fixed-risk M15 trend-following drawdowns during chop and low-volatility false crosses |
| Regime preference | MA-cross trend with ATR and StdDev filters on M15 |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/21523
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10495_mql5-sep-trade.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-28 | Initial build from card | 875063c5-f099-4603-b9fa-23aa5a597511 |
