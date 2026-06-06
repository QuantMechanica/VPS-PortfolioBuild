# QM5_11023_mql5-env-rev - Strategy Spec

**EA ID:** QM5_11023
**Slug:** `mql5-env-rev`
**Source:** `9441393d-5ffc-5b43-87be-bd532110f204` (see `strategy-seeds/sources/9441393d-5ffc-5b43-87be-bd532110f204/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates each completed H1 bar against a 22-period SMA envelope with 0.3 percent bands. It opens long when the completed bar opens below the lower band and closes back above it, and opens short when the completed bar opens above the upper band and closes back below it. Open trades carry fixed 160-point SL and 310-point TP, close on the opposite envelope bounce, and use a 48-H1-bar time stop when no price exit occurs first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_envelopes_period` | 22 | 10-40 test family | H1 SMA length used as the envelope center line. |
| `strategy_envelopes_deviation` | 0.3 | 0.1-0.8 test family | Percent distance of upper and lower envelope bands from the SMA. |
| `strategy_sl_points` | 160 | 100-250 test family | Fixed stop-loss distance in symbol points. |
| `strategy_tp_points` | 310 | 160-500 test family | Fixed take-profit distance in symbol points. |
| `strategy_time_stop_bars` | 48 | 0, 24, 48 test family | Maximum H1 bars to hold; 0 disables the time stop. |
| `strategy_max_spread_points` | 0 | 0 or positive integer | Optional spread cap in points; 0 leaves spread ungated. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major for H1 envelope mean reversion.
- `GBPUSD.DWX` - card-listed liquid FX major for H1 envelope mean reversion.
- `USDJPY.DWX` - card-listed liquid FX major for H1 envelope mean reversion.
- `XAUUSD.DWX` - card-listed liquid gold CFD for H1 envelope mean reversion.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtesting.

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
| Trades / year / symbol | `50` |
| Typical hold time | Up to 48 H1 bars unless fixed SL/TP or opposite signal exits first. |
| Expected drawdown profile | Mean-reversion losses can cluster during persistent directional trends. |
| Regime preference | mean-revert / channel-bounce |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9441393d-5ffc-5b43-87be-bd532110f204`
**Source type:** MQL5 article
**Pointer:** https://www.mql5.com/en/articles/148
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11023_mql5-env-rev.md`

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
| v1 | 2026-06-07 | Initial build from card | 5756495f-1148-4d06-9e48-755dbda3ae05 |
