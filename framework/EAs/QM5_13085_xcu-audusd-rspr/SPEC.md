# QM5_13085_xcu-audusd-rspr - Strategy Spec

**EA ID:** QM5_13085
**Slug:** `xcu-audusd-rspr`
**Source:** `RBA-CME-XCU-AUDUSD-RSPREAD-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

---

## 1. Strategy Logic

This EA trades a D1 two-leg return-spread reversion basket on `XCUUSD.DWX` and
`AUDUSD.DWX`. On each completed host D1 bar it computes a fixed-window copper
log return, subtracts `strategy_beta_audusd` times the matching AUDUSD log
return, standardizes the return spread over a rolling window, and fades z-score
extremes.

Long spread means buy copper and sell AUDUSD. Short spread means sell copper
and buy AUDUSD. The EA exits both legs when the z-score normalizes, the package
exceeds max hold, Friday close fires, or one leg is orphaned. Each leg receives
a fixed ATR hard stop at entry.

This is deliberately different from `QM5_13080_xcu-donchian55` and
`QM5_13081_xcu-4w-reversal`, which are solo copper EAs, and from the WTI/AUD
return-spread family because the commodity leg is industrial copper.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 20 | 10-40 | D1 bars in each leg's fixed return |
| `strategy_z_lookback_d1` | 120 | 80-180 | Return-spread observations used for z-score |
| `strategy_beta_audusd` | 1.20 | 0.80-1.60 | AUDUSD return multiplier in the spread |
| `strategy_entry_z` | 1.9 | 1.6-2.2 | Absolute z-score entry threshold |
| `strategy_exit_z` | 0.4 | 0.25-0.6 | Absolute z-score normalization exit |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR period for per-leg stops |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg hard stop distance in ATR |
| `strategy_max_hold_days` | 30 | 20-45 | Calendar-day package time stop |
| `strategy_xcu_max_spread_pts` | 1200 | 800-1800 | XCU entry spread cap |
| `strategy_audusd_max_spread_pts` | 80 | 50-120 | AUDUSD entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | MT5 order deviation for basket sends |

---

## 3. Symbol Universe

**Designed for:**

- `XCUUSD.DWX` - host chart and copper/base-metal leg, magic slot 0.
- `AUDUSD.DWX` - AUD commodity-currency leg, magic slot 1.

**Explicitly NOT for:**

- Solo copper, gold/silver, oil/metals, XTI/AUD, XNG/AUD, and index sleeves.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Host chart | `XCUUSD.DWX` |
| Multi-symbol refs | `AUDUSD.DWX` completed D1 closes and ATR |
| Bar gating | `QM_IsNewBar()` |

---

## 5. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per package |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

The committed Q02 setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

---

## 6. Source Citation

This card was mechanized from:

**Source ID:** `RBA-CME-XCU-AUDUSD-RSPREAD-2026`
**Source type:** central-bank explainer plus official exchange/government
copper references
**Pointer:** `strategy-seeds/sources/RBA-CME-XCU-AUDUSD-RSPREAD-2026/source.md`
**R1-R4 verdict:** all PASS, with R3 synchronized XCU/AUD history left to Q02

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-09 | Initial build from approved card | Mission-directed copper/AUD basket sleeve |

