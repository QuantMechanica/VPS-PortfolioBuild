# QM5_1407_classical-symmetric-triangle-breakout-h4 - Strategy Spec

**EA ID:** QM5_1407
**Slug:** `classical-symmetric-triangle-breakout-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1407_classical-symmetric-triangle-breakout-h4.md`)
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

The EA detects classical Edwards-Magee symmetric triangle consolidation patterns on closed H4 bars and trades directional breakouts. The pattern is identified by alternating Williams-fractal swing pivots within a bounded lookback window of 25 to 80 H4 bars:
- At least 3 descending pivot highs forming a downward supply line with linear regression slope in `[-2.0, -0.3] * ATR / 50`.
- At least 3 ascending pivot lows forming an upward demand line with linear regression slope in `[+0.3, +2.0] * ATR / 50`.
- Slopes must exhibit bilateral symmetry with relative ratio `|slope_supply + slope_demand| / (|slope_supply| + |slope_demand|) <= 0.40`.
- Pattern amplitude must exceed 3.0 * ATR(14, H4) and projected apex distance from the right edge must not exceed 30% of pattern length.
- No prior bar close in the pattern window may violate the trendline boundaries (+/- 0.2 ATR buffer).

Breakout Entry Trigger:
- Bullish breakout: closed H4 bar breaks above the supply line by 0.5 * ATR(14, H4), triggering BUY entry.
- Bearish breakout: closed H4 bar breaks below the demand line by 0.5 * ATR(14, H4), triggering SELL entry.

Exits and Risk Management:
- Target (TP): Full measured move projection equal to triangle height (`highest_high - lowest_low`).
- Partial Take Profit (TP1): Half-position (50%) exit at 50% measured move, moving the stop loss to break-even.
- Stop Loss (SL): Opposite triangle boundary +/- 0.3 * ATR(14, H4), capped at 3.0 * ATR(14, H4).
- Pattern Failure Exit: Hard close if H4 bar closes back inside triangle boundaries.
- Time Stop: Maximum holding duration of 36 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tf` | `PERIOD_H4` | H4 | Execution and pattern detection timeframe. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for volatility scaling and buffers. |
| `strategy_fractal_wing_bars` | 2 | 1-5 | Williams-fractal wing bars for pivot confirmation. |
| `strategy_pivot_scan_bars` | 200 | 50-300 | History scan window for fractal pivots. |
| `strategy_pattern_min_bars` | 25 | 10-50 | Minimum duration in H4 bars for triangle formation. |
| `strategy_pattern_max_bars` | 80 | 40-200 | Maximum duration in H4 bars for triangle formation. |
| `strategy_min_high_pivots` | 3 | 2-6 | Minimum descending pivot highs required. |
| `strategy_min_low_pivots` | 3 | 2-6 | Minimum ascending pivot lows required. |
| `strategy_slope_min_atr_factor` | 0.30 | 0.05-1.0 | Minimum slope steepness in ATR units per 50 bars. |
| `strategy_slope_max_atr_factor` | 2.00 | 0.50-5.0 | Maximum slope steepness in ATR units per 50 bars. |
| `strategy_slope_symmetry_ratio` | 0.40 | 0.10-0.80 | Maximum asymmetry ratio between supply and demand slopes. |
| `strategy_min_amplitude_atr` | 3.00 | 1.0-10.0 | Minimum height of triangle pattern in ATR units. |
| `strategy_apex_max_extension_pct` | 0.30 | 0.10-1.0 | Maximum apex projection beyond pattern right edge relative to N bars. |
| `strategy_breakout_buffer_atr` | 0.50 | 0.10-2.0 | Buffer beyond trendline for confirmed breakout close. |
| `strategy_sl_buffer_atr` | 0.30 | 0.10-1.0 | Buffer beyond opposite structural pivot for initial stop loss. |
| `strategy_sl_cap_atr` | 3.00 | 1.0-5.0 | Maximum stop loss distance in ATR units. |
| `strategy_tp1_ratio` | 0.50 | 0.20-0.80 | Partial exit fraction and 50% measured move target trigger. |
| `strategy_time_stop_bars` | 36 | 10-100 | Maximum position hold time in H4 bars. |
| `strategy_reuse_guard_bars` | 20 | 0-100 | Cooldown bars after entry before new pattern detection. |
| `strategy_spread_lookback_bars` | 20 | 5-50 | Lookback bars for rolling average spread calculation. |
| `strategy_spread_average_multiplier` | 1.50 | 1.0-5.0 | Spread filter multiplier vs rolling average spread. |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - DAX index CFD named in card R3.
- `NDX.DWX` - Nasdaq 100 index CFD named in card R3.
- `SP500.DWX` - S&P 500 index CFD named in card R3.
- `UK100.DWX` - FTSE 100 index CFD named in card R3.
- `WS30.DWX` - Dow Jones index CFD named in card R3.
- `XAUUSD.DWX` - Spot Gold named in card R3.
- `EURUSD.DWX` - FX major named in card R3.
- `GBPUSD.DWX` - FX major named in card R3.
- `USDJPY.DWX` - FX major named in card R3.
- `USDCHF.DWX` - FX major named in card R3.
- `AUDUSD.DWX` - FX major named in card R3.
- `USDCAD.DWX` - FX major named in card R3.
- `NZDUSD.DWX` - FX major named in card R3.

**Explicitly NOT for:**
- Illiquid exotics or instruments outside `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | None (bias-neutral classical chart pattern) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H4)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `15-35` |
| Typical hold time | `1-6 days` (up to 36 H4 bars time stop) |
| Expected drawdown profile | Contained within 5% daily / 10% total DD constraints |
| Regime preference | Coiling volatility contraction resolving into directional expansion |
| Win rate target (qualitative) | `40-50%` with >= 1.5:1 average reward-to-risk ratio |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `book / forum`
**Pointer:** Robert D. Edwards & John Magee, *Technical Analysis of Stock Trends*, 10th edition (CRC Press 2018, ISBN 978-1-138-06416-5), ch. 8 (Consolidation Formations) — Symmetric Triangle (pp. 177-200) and Apex Theorem (pp. 196-200); `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1407_classical-symmetric-triangle-breakout-h4.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1407_classical-symmetric-triangle-breakout-h4.md`

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
| v1 | 2026-08-22 | Initial build from approved card | Gemini EA implementation |
