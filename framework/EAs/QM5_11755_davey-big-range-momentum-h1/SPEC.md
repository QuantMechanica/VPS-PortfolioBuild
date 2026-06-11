# QM5_11755_davey-big-range-momentum-h1 - Strategy Spec

**EA ID:** QM5_11755
**Slug:** davey-big-range-momentum-h1
**Source:** 82b485a3-2c05-565c-818d-f04e03f74c5a
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA evaluates each completed H1 bar. It measures the bar range as high minus low and requires that range to be greater than the rolling average range plus two rolling standard deviations over the configured `xr` lookback. When that large-range condition is true, it buys if the completed close is above the close `daysback` H1 bars earlier, and sells if it is below that prior close. Exits are only the initial 2x ATR(14) stop loss, 4x ATR(14) take profit, and framework-level Friday/news/kill-switch exits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_xr` | 20 | 2-500 | Rolling H1 range lookback for average and standard deviation. |
| `strategy_daysback` | 5 | 1-500 | H1 close momentum lookback used for long/short direction. |
| `strategy_atr_period` | 14 | 1-500 | ATR period used for initial stop and take-profit distances. |
| `strategy_atr_sl_mult` | 2.0 | >0 | Stop-loss distance as a multiple of ATR(14). |
| `strategy_atr_tp_mult` | 4.0 | >0 | Take-profit distance as a multiple of ATR(14). |
| `strategy_range_stddev_mult` | 2.0 | >0 | Standard-deviation multiplier in the big-range threshold. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with H1 DWX data.
- `GBPUSD.DWX` - card-listed major FX pair with H1 DWX data.
- `USDJPY.DWX` - card-listed major FX pair with H1 DWX data.
- `USDCHF.DWX` - card-listed major FX pair with H1 DWX data.
- `AUDUSD.DWX` - card-listed major FX pair with H1 DWX data.
- `USDCAD.DWX` - card-listed major FX pair with H1 DWX data.

**Explicitly NOT for:**
- Non-FX symbols - the approved card targets the six listed major FX pairs only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 150 |
| Typical hold time | hours to days, bounded by SL/TP |
| Expected drawdown profile | Volatility-expansion momentum with losses concentrated after false large-range bars. |
| Regime preference | volatility-expansion / trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 82b485a3-2c05-565c-818d-f04e03f74c5a
**Source type:** book / article PDF
**Pointer:** `374755020-My-5-Favorite-Entries.pdf`, pages 21-23
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11755_davey-big-range-momentum-h1.md`

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
| v1 | 2026-06-11 | Initial build from card | 0c531037-6d44-473e-bfd9-4d8e63b7fd4e |
