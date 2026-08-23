# QM5_1401_harmonic-shark-xabcd-h4 - Strategy Spec

**EA ID:** QM5_1401
**Slug:** `harmonic-shark-xabcd-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1401_harmonic-shark-xabcd-h4.md`)
**Author of this spec:** Gemini
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

The EA scans closed H4 bars for a Williams-fractal XABCD Shark pattern (Scott Carney Harmonic Trading Vol 2). A bullish setup requires alternating pivots O-high, X-low, A-high, B-low, C-high where AB extends 1.13-1.618 of XA, BC extends 1.618-2.24 of AB, D completes in the 0.886-1.13 OX retracement/extension zone, with C not exceeding A (invalidation guard). A bullish rejection bar confirms the D completion. A bearish setup mirrors the same ratios and rejection rule. The EA enters at market on the next H4 bar, places a structural stop beyond C capped at 2.5 ATR, exits half at the 38.2% CD retracement (moving the remaining runner to break-even), and targets the 61.8% CD retracement for full exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fractal_wing_bars` | 2 | 1-5 | Williams-fractal wing length used to confirm pivots. |
| `strategy_min_od_bars` | 25 | 1-100 | Minimum bars from O pivot to D rejection bar. |
| `strategy_max_od_bars` | 80 | 20-200 | Maximum bars from O pivot to D rejection bar. |
| `strategy_scan_bars` | 200 | 50-300 | Closed H4 bars scanned for recent pivots. |
| `strategy_fib_tolerance_pct` | 0.03 | 0.0-0.10 | Ratio and D-zone tolerance (±3%). |
| `strategy_ab_xa_min` | 1.130 | 1.0-2.0 | Minimum AB/XA extension. |
| `strategy_ab_xa_max` | 1.618 | 1.1-2.5 | Maximum AB/XA extension. |
| `strategy_bc_ab_min` | 1.618 | 1.0-3.0 | Minimum BC/AB extension. |
| `strategy_bc_ab_max` | 2.240 | 1.2-3.5 | Maximum BC/AB extension. |
| `strategy_ox_d_min` | 0.886 | 0.7-1.2 | Minimum D-completion retracement of OX leg. |
| `strategy_ox_d_max` | 1.130 | 0.8-1.5 | Maximum D-completion extension of OX leg. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for stop placement. |
| `strategy_sl_atr_mult` | 0.5 | 0.1-5.0 | ATR buffer beyond C structure. |
| `strategy_sl_cap_atr_mult` | 2.5 | 0.5-10.0 | Maximum allowed stop distance in ATR units. |
| `strategy_tp1_cd_retracement` | 0.382 | 0.1-1.0 | First C-D retracement target and half-exit trigger. |
| `strategy_tp2_cd_retracement` | 0.618 | 0.2-2.0 | Final C-D retracement target. |
| `strategy_tp1_close_fraction` | 0.50 | 0.1-0.9 | Position fraction closed at TP1. |
| `strategy_macro_bias_enabled` | true | true/false | Enable H4 SMA(50/200) trend bias filter. |
| `strategy_macro_fast_sma` | 50 | 10-200 | Fast macro SMA period on H4. |
| `strategy_macro_slow_sma` | 200 | 50-500 | Slow macro SMA period on H4. |
| `strategy_reuse_guard_bars` | 20 | 0-100 | H4 bars to block redetection after an entry signal. |
| `strategy_spread_filter_enabled` | true | true/false | Enable spread filter versus average H4 spread. |
| `strategy_spread_avg_multiplier` | 1.5 | 1.0-10.0 | Current-spread multiplier above average spread that blocks entry. |
| `strategy_time_filter_enabled` | false | true/false | Optional broker-hour trading window. |
| `strategy_start_hour_broker` | 0 | 0-23 | Start hour when time filter is enabled. |
| `strategy_end_hour_broker` | 24 | 1-24 | End hour when time filter is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with native DWX H4 history.
- `GBPUSD.DWX` - FX major with native DWX H4 history.
- `USDJPY.DWX` - FX major with native DWX H4 history.
- `AUDUSD.DWX` - FX major with native DWX H4 history.
- `USDCAD.DWX` - FX major with native DWX H4 history.
- `USDCHF.DWX` - FX major with native DWX H4 history.
- `NZDUSD.DWX` - FX major with native DWX H4 history.
- `NDX.DWX` - liquid index CFD named in the card's R3 basket.
- `WS30.DWX` - liquid index CFD named in the card's R3 basket.
- `GDAXI.DWX` - DAX index CFD named in the card's R3 basket.
- `UK100.DWX` - FTSE index CFD named in the card's R3 basket.
- `SP500.DWX` - optional S&P 500 custom symbol named in card R3; backtest-only.
- `XAUUSD.DWX` - native DWX gold feed named in the card's R3 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `H4` SMA(50/200) trend bias filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30-60` |
| Typical hold time | H4 swing hold, usually hours to days until TP/SL. |
| Expected drawdown profile | Standard harmonic pattern drawdowns around failed D rejection clusters. |
| Regime preference | Mean-reversion fade following C-leg extension. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `book / forum`
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1401_harmonic-shark-xabcd-h4.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1401_harmonic-shark-xabcd-h4.md`

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
