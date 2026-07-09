# QM5_13093_xbr-audusd-rspr - Strategy Spec

**EA ID:** QM5_13093
**Slug:** `xbr-audusd-rspr`
**Source:** `EIA-RBA-XBR-AUDUSD-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

---

## 1. Strategy Logic

This EA trades a D1 two-leg return-spread reversion basket on `XBRUSD.DWX` and
`AUDUSD.DWX`. On each completed host D1 bar it computes a fixed-window Brent
log return, subtracts `strategy_beta_audusd` times the matching AUDUSD log
return, standardizes the return spread over a rolling window, and fades z-score
extremes.

Long spread means buy Brent and sell AUDUSD. Short spread means sell Brent
and buy AUDUSD. The EA exits both legs when the z-score normalizes, the package
exceeds max hold, Friday close fires, or one leg is orphaned. Each leg receives
a fixed ATR hard stop at entry.

This is deliberately different from `QM5_13073_xti-audusd-rspr`, which is the
WTI/AUDUSD return-spread basket, and from the Brent/CAD-cross family because
the FX hedge is AUDUSD rather than a CAD quote.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 20 | 10-40 | D1 bars in each leg's fixed return |
| `strategy_z_lookback_d1` | 120 | 80-180 | Return-spread observations used for z-score |
| `strategy_beta_audusd` | 1.00 | 0.70-1.30 | AUDUSD return multiplier in the spread |
| `strategy_entry_z` | 1.9 | 1.6-2.2 | Absolute z-score entry threshold |
| `strategy_exit_z` | 0.4 | 0.25-0.6 | Absolute z-score normalization exit |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR period for per-leg stops |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg hard stop distance in ATR |
| `strategy_max_hold_days` | 30 | 20-45 | Calendar-day package time stop |
| `strategy_xbr_max_spread_pts` | 1200 | 800-1800 | XBR entry spread cap |
| `strategy_audusd_max_spread_pts` | 80 | 50-120 | AUDUSD entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | MT5 order deviation for basket sends |

---

## 3. Symbol Universe

**Designed for:**

- `XBRUSD.DWX` - host chart and Brent energy leg, magic slot 0.
- `AUDUSD.DWX` - AUD commodity-currency leg, magic slot 1.

**Explicitly NOT for:**

- WTI/AUD, Brent/CAD-cross, gold/silver, oil/metals, XNG/AUD, and index sleeves.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Host chart | `XBRUSD.DWX` |
| Multi-symbol refs | `AUDUSD.DWX` completed D1 closes and ATR |
| Bar gating | `QM_IsNewBar()` |

---

## 5. Expected Behaviour

The EA should trade infrequently on completed D1 bars only. It opens both legs
as one package when the standardized Brent-minus-AUDUSD return spread reaches
an extreme, then closes the whole package on normalization, max-hold expiry,
Friday close, hard-stop loss, or orphan detection.

Expected exposure is market-neutral in implementation terms: every entry sends
one Brent leg and one AUDUSD hedge leg with opposite spread polarity. The
strategy is expected to diversify away from the existing index/metal book by
using Brent energy and commodity-currency exposure rather than equity index
beta, gold, silver, or natural gas directionality.

---

## 6. Source Citation

This card was mechanized from:

**Source ID:** `EIA-RBA-XBR-AUDUSD-2026`
**Source type:** official energy research plus central-bank AUD research
**Pointer:** `strategy-seeds/sources/EIA-RBA-XBR-AUDUSD-2026/source.md`
**R1-R4 verdict:** all PASS, with R3 synchronized XBR/AUD history left to Q02

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
| v1 | 2026-07-09 | Initial build from approved card | Mission-directed Brent/AUDUSD basket sleeve |

