# QM5_9133_aa-valmom-scale - Strategy Spec

**EA ID:** QM5_9133
**Slug:** `aa-valmom-scale`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

This EA implements a long-only monthly asset-class scaling rule from the approved Alpha Architect value-momentum card. On the first D1 bar of a new month, it treats the prior monthly close as the rebalance point, starts from fixed baseline sleeve weights, adjusts each sleeve by valuation versus a fixed center, then adjusts again by 12-month price momentum. It normalizes the resulting raw weights across the registered sleeves and opens a long position when the current symbol's normalized weight is at least the minimum slot threshold. Existing positions are closed on a monthly rebalance only when the refreshed normalized target weight falls below the minimum slot threshold; the emergency stop is 2.5 x ATR(20,D1).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_momentum_months` | 12 | 1-120 | Number of monthly bars used for the fixed price momentum comparison. |
| `strategy_min_monthly_bars` | 14 | `strategy_momentum_months + 2` or higher | Minimum MN1 history required before momentum can be evaluated. |
| `strategy_atr_period_d1` | 20 | 1-500 | D1 ATR period used for the emergency sleeve stop. |
| `strategy_atr_sl_mult` | 2.5 | > 0 | ATR multiplier for the emergency stop. |
| `strategy_max_spread_points` | 0 | 0 or higher | Optional spread cap; 0 disables the spread cap. |
| `strategy_min_slot_weight` | 0.01 | 0-1 | Normalized target weight below which the sleeve stays flat or exits. |
| `strategy_value_center` | 0.0 | any fixed value | Ex-ante fair-value center used by the valuation adjustment. |
| `strategy_value_threshold` | 0.01 | > 0 | Distance from center needed to classify cheap or expensive. |
| `strategy_valuation_data_approved` | true | true/false | Setup guard; false blocks trading rather than degrading to pure momentum. |
| `strategy_baseline_ndx` | 0.16666667 | 0-1 | Baseline sleeve weight for NDX.DWX. |
| `strategy_baseline_ws30` | 0.16666667 | 0-1 | Baseline sleeve weight for WS30.DWX. |
| `strategy_baseline_gdaxi` | 0.16666667 | 0-1 | Baseline sleeve weight for GDAXI.DWX. |
| `strategy_baseline_xauusd` | 0.16666667 | 0-1 | Baseline sleeve weight for XAUUSD.DWX. |
| `strategy_baseline_xtiusd` | 0.16666667 | 0-1 | Baseline sleeve weight for XTIUSD.DWX. |
| `strategy_baseline_sp500` | 0.16666667 | 0-1 | Baseline sleeve weight for SP500.DWX. |
| `strategy_value_ndx` | -0.02 | any fixed value | Fixed valuation score for NDX.DWX. |
| `strategy_value_ws30` | 0.0 | any fixed value | Fixed valuation score for WS30.DWX. |
| `strategy_value_gdaxi` | 0.0 | any fixed value | Fixed valuation score for GDAXI.DWX. |
| `strategy_value_xauusd` | -0.02 | any fixed value | Fixed valuation score for XAUUSD.DWX. |
| `strategy_value_xtiusd` | 0.02 | any fixed value | Fixed valuation score for XTIUSD.DWX. |
| `strategy_value_sp500` | 0.0 | any fixed value | Fixed valuation score for SP500.DWX. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, news, RNG seed, stress rejection, and Friday close controls) are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 sleeve from the card's index basket.
- `WS30.DWX` - Dow 30 sleeve from the card's index basket.
- `GDAXI.DWX` - DAX 40 DWX equivalent for the card's `GER40.DWX` target.
- `XAUUSD.DWX` - gold commodity sleeve from the card.
- `XTIUSD.DWX` - WTI crude commodity sleeve from the card.
- `SP500.DWX` - optional S&P 500 sleeve; valid for backtest-only use under the 2026-05-16 SP500.DWX rollout.

**Explicitly NOT for:**
- Any symbol not listed above - no implicit runtime universe expansion is allowed.
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX proxy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `MN1` close for 12-month momentum; `D1` ATR(20) for emergency stop |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the skeleton entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Monthly rebalance cadence; exact trade count not specified in card frontmatter |
| Typical hold time | Multi-week to multi-month sleeve holds between monthly rebalances |
| Expected drawdown profile | Portfolio-level V5 controls plus per-sleeve ATR emergency stop |
| Regime preference | Tactical asset allocation; long-only value and momentum participation |
| Win rate target (qualitative) | Not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** blog/source note
**Pointer:** Larry Swedroe, "Using Momentum to Find Value", 2022-05-05, Alpha Architect
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_9133_aa-valmom-scale.md`

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
| v1 | 2026-05-25 | Initial build from card | ae1f358d-1a17-429a-83e6-79b5abaef51c |
