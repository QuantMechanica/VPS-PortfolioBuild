# QM5_10612_mql5-3xma-rev - Strategy Spec

**EA ID:** QM5_10612
**Slug:** `mql5-3xma-rev`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades the MQL5 `up3x1` three-moving-average reversal rule on completed H4 bars. It enters long when the fast SMA crosses above the middle SMA while both are still below the slow SMA, and enters short when the fast SMA crosses below the middle SMA while both are still above the slow SMA. Positions use fixed point stop loss and take profit by default. Open trades close on an opposite three-MA signal, fixed SL/TP, framework Friday close, or after 20 completed H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_period` | 24 | >=1 | Fast SMA period from the source EA. |
| `strategy_fast_shift` | 6 | >=0 | Bar shift applied to the fast SMA signal read. |
| `strategy_middle_period` | 60 | >=1 | Middle SMA period from the source EA. |
| `strategy_middle_shift` | 6 | >=0 | Bar shift applied to the middle SMA signal read. |
| `strategy_slow_period` | 120 | >=1 | Slow SMA period from the source EA. |
| `strategy_slow_shift` | 6 | >=0 | Bar shift applied to the slow SMA signal read. |
| `strategy_stop_loss_points` | 100 | >=0 | Fixed stop-loss distance in broker points; 0 activates ATR fallback. |
| `strategy_take_profit_points` | 150 | >=0 | Fixed take-profit distance in broker points; 0 uses RR fallback from the stop. |
| `strategy_atr_period` | 14 | >=1 | ATR period used only when fixed stop-loss points are 0. |
| `strategy_atr_sl_mult` | 2.5 | >0 | ATR stop multiplier used only when fixed stop-loss points are 0. |
| `strategy_rr_fallback` | 1.5 | >0 | Take-profit R multiple used only when fixed take-profit points are 0. |
| `strategy_trailing_stop_points` | 0 | >=0 | Optional source-style trailing stop in points; 0 disables trailing. |
| `strategy_close_on_opposite` | true | true/false | Close an open position when the opposite three-MA signal appears. |
| `strategy_time_stop_h4_bars` | 20 | >=0 | Fallback time stop measured in completed H4 bars; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target symbol; liquid major FX pair with OHLC data for SMA logic.
- `GBPUSD.DWX` - card target symbol; liquid major FX pair with OHLC data for SMA logic.
- `USDJPY.DWX` - card target symbol; liquid major FX pair with OHLC data for SMA logic.
- `XAUUSD.DWX` - card target symbol; liquid metal CFD with OHLC data for SMA logic.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX history for build registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | Not specified in card frontmatter; capped by 20 completed H4 bars. |
| Expected drawdown profile | Not specified in card frontmatter; fixed SL/TP trend-reversal profile. |
| Regime preference | Trend reversal after fast/middle SMA cross while still on the opposite side of the slow SMA. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/1077`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10612_mql5-3xma-rev.md`

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
| v1 | 2026-06-13 | Initial build from card | f778f12e-acf6-4117-97a5-dee3235473df |
