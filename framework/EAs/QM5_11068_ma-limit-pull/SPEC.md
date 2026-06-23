# QM5_11068_ma-limit-pull - Strategy Spec

**EA ID:** QM5_11068
**Slug:** ma-limit-pull
**Source:** 429e4612-2e1d-57be-b12e-ff8b94d42117
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades EURUSD.DWX pullbacks on M5 using a short-term EMA trend state. A long setup exists when EMA(12) is above EMA(36) and the fast EMA is rising; a short setup exists when EMA(12) is below EMA(36) and the fast EMA is falling. While the trend remains valid, the EA refreshes one pending limit order per closed M5 bar: Buy Limit at Bid minus 0.35 ATR(14), or Sell Limit at Ask plus 0.35 ATR(14). The EA skips flat or explosive regimes using ADX(14) and ATR(14)/ATR(96), places ATR-based SL/TP, and closes an open position if the EMA trend reverses against it.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_ma_period | 12 | 2+ | Fast EMA period on close. |
| strategy_slow_ma_period | 36 | 2+ | Slow EMA period on close. |
| strategy_slope_lookback | 3 | 1+ | Bars used to confirm the fast EMA slope. |
| strategy_atr_period | 14 | 2+ | ATR period for pullback offset, SL, and TP. |
| strategy_atr_long_period | 96 | 2+ | Long ATR baseline for volatility expansion filter. |
| strategy_pullback_atr | 0.35 | greater than 0 | Pending limit offset in ATR multiples. |
| strategy_sl_atr_mult | 1.2 | greater than 0 | Stop distance in ATR multiples from pending entry. |
| strategy_tp_atr_mult | 1.8 | greater than 0 | Take-profit distance in ATR multiples from pending entry. |
| strategy_order_expiry_bars | 12 | 0+ | Pending order expiry in current-chart bars; 0 disables explicit expiry. |
| strategy_adx_period | 14 | 2+ | ADX period for the flat-regime filter. |
| strategy_min_adx | 18.0 | 0+ | Minimum ADX required; 0 disables the ADX floor. |
| strategy_max_vol_expansion | 2.0 | 0+ | Maximum ATR(14)/ATR(96) ratio; 0 disables the filter. |
| strategy_max_spread_stop_pct | 15.0 | 0+ | Blocks only genuinely wide spread above this percent of stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Direct R3 mapping from the approved card; liquid FX major with available DarwinexZero history.

**Explicitly NOT for:**
- Other `.DWX` symbols - The approved card's R3 section names only EURUSD.DWX, so no broader portable basket is registered for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 220 |
| Typical hold time | Not specified in frontmatter; expected intraday M5 holding because SL/TP and MA-reversal exits are M5-native. |
| Expected drawdown profile | Not specified in frontmatter; bounded per-trade risk through hard ATR stop and fixed-risk sizing. |
| Regime preference | Trend pullback; skips flat ADX and high ATR-expansion regimes. |
| Win rate target (qualitative) | Not specified in card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 429e4612-2e1d-57be-b12e-ff8b94d42117
**Source type:** MQL5 article interview
**Pointer:** Boris Odintsov interview, MQL5 Articles, 2010-10-21, https://www.mql5.com/en/articles/532
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11068_ma-limit-pull.md`.

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
| v1 | 2026-06-23 | Initial build from card | a219ccad-bae6-46f1-b9f0-219705a1d0e2 |
