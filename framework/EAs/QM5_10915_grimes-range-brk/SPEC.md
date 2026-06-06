# QM5_10915_grimes-range-brk - Strategy Spec

**EA ID:** QM5_10915
**Slug:** grimes-range-brk
**Source:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c (Adam H. Grimes, Ranges and measured moves)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades an M15 breakout after price first makes a directional thrust and then pauses in a compact range near the thrust extreme. A long setup requires a prior upside move of at least 1.8 ATR(14), a 6-18 bar range no wider than 0.9 ATR(14), the range midpoint in the upper 35% of the thrust, and the last closed bar closing above the range high by 0.1 ATR(14). Short setups mirror the same rules after a downside thrust, compact lower-pressure range, and close below the range low. Stops are placed just beyond the range by 0.2 ATR(14), targets use the measured thrust projected from breakout but capped at 2R, stops move to breakeven after 1R, ATR trailing then applies, and positions time out after 24 M15 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_atr_period | 14 | 2-100 | ATR period used for thrust, range, breakout, stop, and trailing calculations. |
| strategy_thrust_lookback_bars | 24 | 2-100 | Bars before the range scanned for the prior thrust. |
| strategy_min_thrust_atr_mult | 1.80 | 0.1-10.0 | Minimum prior thrust size as a multiple of ATR(14). |
| strategy_min_range_bars | 6 | 1-50 | Minimum compact range length before breakout. |
| strategy_max_range_bars | 18 | 1-100 | Maximum compact range length before breakout. |
| strategy_max_range_atr_mult | 0.90 | 0.1-10.0 | Maximum range width as a multiple of ATR(14). |
| strategy_pressure_fraction | 0.35 | 0.05-0.95 | Fraction defining upper or lower thrust location for range pressure. |
| strategy_breakout_atr_mult | 0.10 | 0.0-2.0 | Required close break beyond range high or low as a multiple of ATR(14). |
| strategy_stop_buffer_atr_mult | 0.20 | 0.0-2.0 | Stop buffer beyond range low or high as a multiple of ATR(14). |
| strategy_min_stop_atr_mult | 0.50 | 0.1-5.0 | Minimum allowed stop distance as a multiple of ATR(14). |
| strategy_max_stop_atr_mult | 2.00 | 0.1-10.0 | Maximum allowed stop distance as a multiple of ATR(14). |
| strategy_trail_atr_mult | 1.50 | 0.1-10.0 | ATR trailing stop multiplier after the 1R breakeven trigger. |
| strategy_ema_slope_period | 50 | 2-300 | EMA period used to reject breakouts against the EMA slope. |
| strategy_time_exit_bars | 24 | 1-200 | Maximum hold time in base-timeframe bars. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 custom symbol; matches the card's US large-cap index basket and is backtest-only by infrastructure rule.
- NDX.DWX - Nasdaq 100 index CFD; liquid US large-cap growth index exposure.
- GDAXI.DWX - Canonical DAX custom symbol in the DWX matrix; used for the card's DAX/GER40 exposure.
- WS30.DWX - Dow 30 index CFD; liquid US large-cap industrial index exposure.

**Explicitly NOT for:**
- GER40.DWX - Card-stated DAX alias is not present in `dwx_symbol_matrix.csv`; GDAXI.DWX is the registered canonical DWX DAX symbol.
- SPX500.DWX - Not a valid DWX symbol; SP500.DWX is the available S&P 500 custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Intraday; up to 24 M15 bars after entry |
| Expected drawdown profile | Breakout strategy with stop-bounded losses during failed range breaks. |
| Regime preference | volatility-expansion breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fbfd7f6e-462a-55c8-9efa-9005a70c9f5c
**Source type:** blog
**Pointer:** https://www.adamhgrimes.com/ranges-and-measured-moves/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10915_grimes-range-brk.md`

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
| v1 | 2026-06-06 | Initial build from card | 7fdcf923-dc9d-4068-b7e0-93a631bc12a4 |

