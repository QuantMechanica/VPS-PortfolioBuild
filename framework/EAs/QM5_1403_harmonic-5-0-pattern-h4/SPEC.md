# QM5_1403_harmonic-5-0-pattern-h4 - Strategy Spec

**EA ID:** QM5_1403
**Slug:** `harmonic-5-0-pattern-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA scans closed H4 bars for a Williams-fractal XABCD 5-0 pattern. A bullish setup requires low-high-low-high pivots with AB/XA in 1.13-1.618, BC/AB in 1.618-2.24, X-to-D time between 25 and 80 H4 bars, and a bullish rejection bar whose low touches the D completion zone. A bearish setup mirrors the same ratios and rejection rule. The EA enters at market on the next H4 bar, uses an ATR-capped stop beyond D, exits half at the 50% C-D retracement, moves the rest to break-even, and leaves final TP at the 88.6% C-D retracement.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fractal_wing_bars` | 2 | 1-5 | Williams-fractal wing length used to confirm pivots. |
| `strategy_min_xd_bars` | 25 | 1-200 | Minimum bars from X pivot to D rejection bar. |
| `strategy_max_xd_bars` | 80 | 1-300 | Maximum bars from X pivot to D rejection bar. |
| `strategy_scan_bars` | 96 | 32-300 | Closed H4 bars scanned for recent pivots. |
| `strategy_fib_tolerance_pct` | 0.03 | 0.0-0.10 | Ratio and D-zone tolerance. |
| `strategy_ab_xa_min` | 1.13 | 1.0-2.0 | Minimum AB/XA extension. |
| `strategy_ab_xa_max` | 1.618 | 1.0-2.5 | Maximum AB/XA extension. |
| `strategy_bc_ab_min` | 1.618 | 1.0-3.0 | Minimum BC/AB extension. |
| `strategy_bc_ab_max` | 2.24 | 1.0-3.0 | Maximum BC/AB extension. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for stop placement. |
| `strategy_sl_atr_mult` | 0.5 | 0.1-5.0 | ATR buffer beyond D zone. |
| `strategy_sl_cap_atr_mult` | 2.5 | 0.5-10.0 | Maximum allowed stop distance in ATR units. |
| `strategy_tp1_cd_retracement` | 0.500 | 0.1-1.0 | First C-D retracement target and half-exit trigger. |
| `strategy_tp2_cd_retracement` | 0.886 | 0.1-2.0 | Final C-D retracement target. |
| `strategy_tp1_close_fraction` | 0.50 | 0.1-0.9 | Position fraction closed at TP1. |
| `strategy_macro_bias_enabled` | true | true/false | Enable D1 SMA(50/200) directional filter. |
| `strategy_macro_fast_sma_d1` | 50 | 2-300 | Fast D1 SMA period. |
| `strategy_macro_slow_sma_d1` | 200 | 10-500 | Slow D1 SMA period. |
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
- `SP500.DWX` - optional S&P 500 custom symbol named in the card's R3 section; backtest-only.
- `XAUUSD.DWX` - native DWX gold feed named in the card's R3 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol tick source is registered for P2.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1` SMA(50/200) macro-bias filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | H4 swing hold, usually hours to days until TP/SL. |
| Expected drawdown profile | Mean-reversion pattern drawdowns around failed D rejection clusters. |
| Regime preference | Mean-revert after extension, with daily trend context. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `book / forum`
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1403_harmonic-5-0-pattern-h4.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1403_harmonic-5-0-pattern-h4.md`

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
| v1 | 2026-06-26 | Initial build from card | 652b4964-4645-490c-96a1-94bfebb8faf1 |
