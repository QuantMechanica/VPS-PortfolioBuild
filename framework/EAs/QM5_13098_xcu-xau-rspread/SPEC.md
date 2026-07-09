# QM5_13098_xcu-xau-rspread - Strategy Spec

**EA ID:** QM5_13098
**Slug:** `xcu-xau-rspread`
**Source:** `PARNES-SSGA-COPPERGOLD-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

---

## 1. Strategy Logic

This EA trades a D1 two-leg return-spread reversion basket on `XCUUSD.DWX` and
`XAUUSD.DWX`. On each completed host D1 bar it computes a fixed-window copper
log return, subtracts `strategy_beta_xau` times the matching gold log return,
standardizes the return spread over a rolling window, and fades z-score
extremes.

Long spread means buy copper and sell gold. Short spread means sell copper and
buy gold. The EA exits both legs when the z-score normalizes, the package
exceeds max hold, Friday close fires, or one leg is orphaned. Each leg receives
a fixed ATR hard stop at entry.

This is deliberately different from solo copper trend/reversal, XCU/AUDUSD,
XTI/XCU, oil/gold, gas/gold, XAU/XAG, index, and commodity-RSI sleeves.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 20 | 10-40 | D1 bars in each leg's fixed return |
| `strategy_z_lookback_d1` | 120 | 80-180 | Return-spread observations used for z-score |
| `strategy_beta_xau` | 0.75 | 0.50-1.00 | Gold return multiplier in the spread |
| `strategy_entry_z` | 1.9 | 1.6-2.2 | Absolute z-score entry threshold |
| `strategy_exit_z` | 0.4 | 0.25-0.6 | Absolute z-score normalization exit |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR period for per-leg stops |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg hard stop distance in ATR |
| `strategy_max_hold_days` | 30 | 20-45 | Calendar-day package time stop |
| `strategy_xcu_max_spread_pts` | 1200 | 800-1800 | XCU entry spread cap |
| `strategy_xau_max_spread_pts` | 500 | 300-800 | XAU entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | MT5 order deviation for basket sends |

---

## 3. Symbol Universe

**Designed for:**

- `XCUUSD.DWX` - host chart and copper leg, magic slot 0.
- `XAUUSD.DWX` - gold leg, magic slot 1.

**Explicitly NOT for:**

- Solo copper, gold/silver, oil/gold, gas/gold, oil/copper, commodity-FX,
  energy calendar/event, and index sleeves.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Host chart | `XCUUSD.DWX` |
| Multi-symbol refs | `XAUUSD.DWX` completed D1 closes and ATR |
| Bar gating | `QM_IsNewBar()` |

---

## 5. Expected Behaviour

The EA should trade infrequently on completed D1 bars only. It opens both legs
as one package when the standardized copper-minus-gold return spread reaches
an extreme, then closes the whole package on normalization, max-hold expiry,
Friday close, hard-stop loss, or orphan detection.

Expected exposure is market-neutral in implementation terms: every entry sends
one copper leg and one gold hedge leg with opposite spread polarity. The
strategy is expected to diversify away from the existing index/metal book by
using copper/gold relative value rather than outright gold, silver, index, oil,
or natural gas directionality.

---

## 6. Source Citation

This card was mechanized from:

**Source ID:** `PARNES-SSGA-COPPERGOLD-2026`
**Source type:** peer-reviewed paper plus reputable market research and
exchange reference
**Pointer:** `strategy-seeds/sources/PARNES-SSGA-COPPERGOLD-2026/source.md`
**R1-R4 verdict:** all PASS, with R3 synchronized XCU/XAU history left to Q02

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per package |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

The committed Q02 setfile uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-09 | Initial build from approved card | Mission-directed copper/gold basket sleeve |

