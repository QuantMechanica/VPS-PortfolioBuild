# QM5_10925_grimes-polarity - Strategy Spec

**EA ID:** QM5_10925
**Slug:** grimes-polarity
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades H1 retests of broken support or resistance. Candidate levels come from the prior D1 high/low and the most recent confirmed H1 3-left/3-right swing high/low. A long trade requires a close above resistance by 0.25 ATR(20), then a retest within 12 H1 bars where price trades back to the level and closes above it; shorts mirror this below support. The stop is beyond the retest bar by 0.25 ATR(20), the target is 1.8R, stop moves to breakeven at 1R, and the EA exits after 18 H1 bars or if a closed bar returns through the polarity level by 0.25 ATR(20).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 20 | 1+ | ATR period for breakout threshold, retest tolerance, stop buffer, and stop validation. |
| `strategy_pivot_left_bars` | 3 | 1+ | Older bars required on the left side of a confirmed H1 pivot. |
| `strategy_pivot_right_bars` | 3 | 1+ | Newer bars required on the right side of a confirmed H1 pivot. |
| `strategy_pivot_scan_bars` | 96 | 8+ | Maximum H1 history searched for the most recent confirmed pivot. |
| `strategy_breakout_atr_mult` | 0.25 | >0 | Minimum close-through distance for breakout and failed-polarity exit. |
| `strategy_retest_window_bars` | 12 | 1+ | Maximum H1 bars between breakout close and retest close. |
| `strategy_retest_atr_mult` | 0.15 | 0+ | Retest tolerance around the broken level. |
| `strategy_stop_buffer_atr_mult` | 0.25 | >0 | Stop buffer beyond the retest bar high or low. |
| `strategy_min_stop_atr_mult` | 0.50 | >0 | Reject trades with initial stop distance tighter than this ATR multiple. |
| `strategy_max_stop_atr_mult` | 3.00 | > min | Reject trades with initial stop distance wider than this ATR multiple. |
| `strategy_target_r_mult` | 1.80 | >0 | Fixed take-profit distance in R. |
| `strategy_breakeven_trigger_r` | 1.00 | >0 | Move stop to breakeven once price reaches this R multiple. |
| `strategy_time_exit_bars` | 18 | 1+ | Maximum H1 bars to hold a position. |
| `strategy_ema_period` | 20 | 2+ | EMA slope filter period. |
| `strategy_spread_stop_frac` | 0.10 | >0 | Maximum spread as a fraction of initial stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with DWX H1 OHLC history.
- `GBPUSD.DWX` - card-listed major FX pair with DWX H1 OHLC history.
- `USDJPY.DWX` - card-listed major FX pair with DWX H1 OHLC history.
- `XAUUSD.DWX` - card-listed liquid metal CFD with DWX H1 OHLC history.
- `GDAXI.DWX` - DWX matrix DAX equivalent used because card-listed `GER40.DWX` is unavailable.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX tick/history guarantee.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 prior high/low |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 24 |
| Typical hold time | Up to 18 H1 bars |
| Expected drawdown profile | Stop-defined pullback/retest losses with fixed 1.8R targets. |
| Regime preference | Breakout then pullback/polarity retest. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "How to Trade Support and Resistance Levels", 2020-10-16, https://www.adamhgrimes.com/how-to-trade-support-and-resistance-levels/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10925_grimes-polarity.md`

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
| v1 | 2026-06-06 | Initial build from card | 029e4b5e-98b8-48df-b5c5-b293ca2c6b7b |
