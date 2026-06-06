# QM5_10926_grimes-powerpull - Strategy Spec

**EA ID:** QM5_10926
**Slug:** grimes-powerpull
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades an H1 momentum approach into nearby support or resistance levels. It defines active targets from the previous D1 high/low, the 20-day highest high/lowest low, and the most recent H1 pivot high/low confirmed by three bars on each side. A long opens when the selected target is above price, close is advancing toward it, close is above a rising EMA(20), the level was not touched in the prior six H1 bars, and target distance is acceptable versus the ATR stop; shorts mirror the same rules below price. Exits are handled by target touch via TP, a prior-3-bar trailing stop after +0.75R, an eight-H1-bar time exit, or a closed-bar move away from the best favorable close by more than 0.8 ATR(20).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 20 | >=1 | ATR period for distance, stop, and away-from-target exit. |
| strategy_ema_period | 20 | >=1 | EMA period for trend/slope confirmation. |
| strategy_target_distance_atr | 1.25 | >0 | Maximum level distance from last close in ATR units. |
| strategy_momentum_window_bars | 4 | >=1 | Number of H1 close-to-close comparisons for approach momentum. |
| strategy_momentum_min_count | 3 | 1-window | Minimum advancing comparisons required. |
| strategy_stop_atr_mult | 1.20 | >0 | Initial stop distance in ATR units. |
| strategy_min_target_r | 0.80 | >0 | Minimum target distance as an R multiple. |
| strategy_prior_touch_bars | 6 | >=1 | H1 lookback where an already-touched level blocks entry. |
| strategy_daily_lookback_days | 20 | >=2 | D1 high/low lookback for 20-day target levels. |
| strategy_pivot_left_bars | 3 | >=1 | Bars to the left of a confirmed H1 pivot. |
| strategy_pivot_right_bars | 3 | >=1 | Bars to the right of a confirmed H1 pivot. |
| strategy_pivot_scan_bars | 96 | >=7 | Maximum H1 bars scanned for the most recent pivot. |
| strategy_trail_trigger_r | 0.75 | >0 | Profit threshold before prior-3-bar trailing activates. |
| strategy_trail_lookback_bars | 3 | >=1 | Bars used for trailing stop high/low. |
| strategy_time_exit_bars | 8 | >=1 | H1 bars held before time exit. |
| strategy_away_atr_mult | 0.80 | >0 | ATR distance away from best favorable close for early exit. |
| strategy_spread_stop_frac | 0.08 | >0 | Spread cap as a fraction of initial stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 custom-symbol proxy named in the card; valid for backtest-only baseline work.
- NDX.DWX - Nasdaq 100 index exposure in the card's major-index basket.
- GDAXI.DWX - Available DAX custom symbol in the matrix; build-time port from card-stated GER40.DWX.
- WS30.DWX - Dow 30 index exposure in the card's major-index basket.
- XAUUSD.DWX - Gold/metals exposure named in the card.

**Explicitly NOT for:**
- GER40.DWX - Not present in `dwx_symbol_matrix.csv`; use GDAXI.DWX for this build.
- SPX500.DWX, SPY.DWX, ES.DWX - Not canonical DWX S&P 500 symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 previous high/low and 20-day high/low |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework OnTick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Typical hold time | Up to 8 H1 bars unless target, trail, or away-from-target exit fires first |
| Expected drawdown profile | Conservative level-touch momentum with fixed 1.2 ATR initial risk |
| Regime preference | Momentum approach to nearby support/resistance levels |
| Win rate target (qualitative) | Medium |

Expected trade frequency: Approach-to-level momentum on major prior highs/lows; conservative estimate 12-30 trades/year/symbol.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** Adam H. Grimes, "How to Trade Support and Resistance Levels", 2020-10-16, https://www.adamhgrimes.com/how-to-trade-support-and-resistance-levels/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10926_grimes-powerpull.md`

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
| v1 | 2026-06-06 | Initial build from card | 32bd8da2-90eb-4449-b95a-3ac6f7dfdada |
