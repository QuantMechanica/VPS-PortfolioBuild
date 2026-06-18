# QM5_10996_ftmo-obv-tl - Strategy Spec

**EA ID:** QM5_10996
**Slug:** `ftmo-obv-tl`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades H1 breakouts confirmed by On Balance Volume. A long setup requires the last closed bar to close above the prior Donchian(30) high by at least 0.10 ATR(14), with OBV above a descending trendline built from the two latest OBV swing highs and with positive 10-bar OBV slope. A short setup mirrors the rule below the Donchian(30) low, using an ascending OBV swing-low trendline and negative OBV slope. The stop is placed 0.75 ATR beyond the breakout level, the target is 2R, and discretionary exits close after 40 H1 bars or when price closes back inside the Donchian range while OBV recrosses the broken trendline.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_donchian_period` | 30 | 2-120 | Donchian breakout lookback using prior closed bars. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for breakout buffer, stop, and range filter. |
| `strategy_break_atr_mult` | 0.10 | 0.0-2.0 | Required price clearance beyond Donchian level in ATR units. |
| `strategy_sl_atr_mult` | 0.75 | 0.1-5.0 | Stop offset from the breakout level in ATR units. |
| `strategy_tp_rr` | 2.0 | 0.1-10.0 | Take-profit multiple of initial risk. |
| `strategy_time_exit_bars` | 40 | 1-240 | Maximum holding period in base timeframe bars. |
| `strategy_range_min_atr` | 1.0 | 0.0-10.0 | Minimum Donchian range height in ATR units. |
| `strategy_range_max_atr` | 4.0 | 0.1-20.0 | Maximum Donchian range height in ATR units. |
| `strategy_obv_swing_lookback` | 60 | 10-140 | OBV bars scanned for swing highs and lows. |
| `strategy_obv_slope_bars` | 10 | 1-80 | OBV slope comparison length. |
| `strategy_obv_recent_bars` | 2 | 0-2 | Bars allowed since the OBV trendline break. |
| `strategy_swing_gap_min` | 8 | 1-60 | Minimum bar distance between the two OBV swing points. |
| `strategy_swing_gap_max` | 45 | 2-120 | Maximum bar distance between the two OBV swing points. |
| `strategy_spread_stop_pct` | 15.0 | 0.0-100.0 | Blocks only genuinely wide spread relative to stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; liquid FX pair with MT5 tick volume for OBV.
- `GBPUSD.DWX` - card target; liquid FX pair with MT5 tick volume for OBV.
- `GDAXI.DWX` - canonical DWX DAX symbol mapped from card target `GER40.DWX`.
- `XAUUSD.DWX` - card target; liquid metal CFD with MT5 tick volume for OBV.

**Explicitly NOT for:**
- `GER40.DWX` - card spelling is not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- Symbols outside `dwx_symbol_matrix.csv` - no verified DWX custom-symbol data.

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
| Trades / year / symbol | `35` |
| Typical hold time | Up to 40 H1 bars |
| Expected drawdown profile | Breakout strategy with ATR-bounded initial risk and 2R targets. |
| Regime preference | Breakout / volatility expansion with volume confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `FTMO blog`
**Pointer:** `https://ftmo.com/en/technical-indicators-in-trading-strategies/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10996_ftmo-obv-tl.md`

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
| v1 | 2026-06-18 | Initial build from card | 4409db1b-40d8-4917-8311-5b88e8b12f0a |
