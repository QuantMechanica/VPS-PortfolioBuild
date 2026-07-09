# QM5_13082_xbr-nzdcad-rspr - Strategy Spec

**EA ID:** QM5_13082
**Slug:** `xbr-nzdcad-rspr`
**Source:** `EIA-BOC-RBNZ-XBR-NZDCAD-2026` (see `strategy-seeds/sources/EIA-BOC-RBNZ-XBR-NZDCAD-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-09

---

## 1. Strategy Logic

This EA trades a two-leg D1 return-spread reversion basket on `XBRUSD.DWX`
and `NZDCAD.DWX`. On each new D1 host bar it computes
`log(XBR[t] / XBR[t-L]) + beta_nzdcad * log(NZDCAD[t] / NZDCAD[t-L])`,
then standardizes that spread against a rolling lookback window.

`NZDCAD` rises when AUD strengthens or CAD weakens. The plus sign is
intentional: a Brent rally and CAD strength should pull the two terms in
opposite directions, so unusually large same-direction dislocations are faded.
When the z-score is above the entry threshold, the EA sells Brent and sells
NZDCAD. When the z-score is below the negative entry threshold, it buys Brent
and buys NZDCAD. The package exits when the z-score reverts inside the exit
band, the max-hold guard fires, Friday close fires, or only one leg remains
open.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 20 | 10-40 | D1 return window for both legs |
| `strategy_z_lookback_d1` | 120 | 80-180 | Rolling normalization window for the return spread |
| `strategy_beta_nzdcad` | 0.60 | 0.40-0.85 | NZDCAD return multiplier and risk-weight proxy |
| `strategy_entry_z` | 1.9 | 1.6-2.2 | Absolute z-score threshold for opening the basket |
| `strategy_exit_z` | 0.4 | 0.25-0.60 | Absolute z-score band for mean-reversion exit |
| `strategy_atr_period_d1` | 20 | 14-30 | D1 ATR lookback for each leg's hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | ATR multiple used for each leg's hard stop |
| `strategy_max_hold_days` | 30 | 20-45 | Maximum calendar days before closing the package |
| `strategy_xbr_max_spread_pts` | 1200 | 800-1800 | Maximum allowed XBR spread in points |
| `strategy_nzdcad_max_spread_pts` | 120 | 80-200 | Maximum allowed NZDCAD spread in points |
| `strategy_deviation_points` | 20 | fixed | Basket order slippage/deviation cap in points |

---

## 3. Symbol Universe

**Designed for:**
- `XBRUSD.DWX` - Brent crude leg and host chart for the oil side of the return spread.
- `NZDCAD.DWX` - inverse-CAD commodity-FX leg contrasting AUD commodity exposure with CAD oil exposure.
- `QM5_13082_XBR_NZDCAD_RSPREAD_D1` - logical Q02 basket symbol backed by the two traded legs above.

**Explicitly NOT for:**
- `XTIUSD.DWX` - related oil exposure, but existing WTI return-spread cards use it.
- `USDCAD.DWX` - already covered by separate oil/CAD sleeves.
- `XNGUSD.DWX`, `XAUUSD.DWX`, and `XAGUSD.DWX` - outside this card's source and logic.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 7-12 logical paired packages |
| Typical hold time | days to several weeks, capped at 30 days by default |
| Expected drawdown profile | Medium-high, driven by Brent volatility and synchronized two-leg fills |
| Regime preference | Mean-revert relative-value dislocations between Brent and inverse-CAD NZDCAD |
| Win rate target | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `EIA-BOC-RBNZ-XBR-NZDCAD-2026`
**Source type:** official energy research / central bank research
**Pointer:** `strategy-seeds/sources/EIA-BOC-RBNZ-XBR-NZDCAD-2026/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_13082_xbr-nzdcad-rspr.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV to mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-09 | Initial build from approved card | manual-codex-2026-07-09-xbr-nzdcad-rspr |
