# QM5_13034_xti-audcad-rspr - Strategy Spec

**EA ID:** QM5_13034
**Slug:** `xti-audcad-rspr`
**Source:** `EIA-RBA-BOC-XTI-AUDCAD-2026` (see `strategy-seeds/sources/EIA-RBA-BOC-XTI-AUDCAD-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

This EA trades a two-leg D1 return-spread reversion basket on `XTIUSD.DWX`
and `AUDCAD.DWX`. On each new D1 host bar it computes:

`log(XTI[t] / XTI[t-L]) + beta_audcad * log(AUDCAD[t] / AUDCAD[t-L])`

The AUDCAD term is positive in the executable formula because the CAD proxy is
the negative AUDCAD return. When the z-score is above the entry threshold, the
EA sells WTI and sells AUDCAD. When the z-score is below the negative entry
threshold, it buys WTI and buys AUDCAD. The package exits when the z-score
reverts inside the exit band, the max-hold guard fires, Friday close fires, or
only one leg remains open.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 20 | 10-40 | D1 return window for both legs |
| `strategy_z_lookback_d1` | 120 | 80-180 | Rolling normalization window for the return spread |
| `strategy_beta_audcad` | 0.65 | 0.40-0.90 | AUDCAD return multiplier and risk-weight proxy |
| `strategy_entry_z` | 1.9 | 1.6-2.2 | Absolute z-score threshold for opening the basket |
| `strategy_exit_z` | 0.4 | 0.25-0.60 | Absolute z-score band for mean-reversion exit |
| `strategy_atr_period_d1` | 20 | 14-30 | D1 ATR lookback for each leg's hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | ATR multiple used for each leg's hard stop |
| `strategy_max_hold_days` | 30 | 20-45 | Maximum calendar days before closing the package |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | Maximum allowed XTI spread in points |
| `strategy_audcad_max_spread_pts` | 120 | 80-180 | Maximum allowed AUDCAD spread in points |
| `strategy_deviation_points` | 20 | fixed | Basket order slippage/deviation cap in points |

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - crude leg and host chart for the oil side of the return spread.
- `AUDCAD.DWX` - FX leg expressing CAD strength/weakness through AUDCAD.
- `QM5_13034_XTI_AUDCAD_RSPREAD_D1` - logical Q02 basket symbol backed by the
  two traded legs above.

**Explicitly NOT for:**
- `AUDUSD.DWX` - related AUD exposure, but this card specifically uses AUDCAD.
- `USDCAD.DWX` - related CAD exposure, but this card avoids direct USD/CAD.
- `CADJPY.DWX` / `CADCHF.DWX` / `NZDUSD.DWX` - existing sibling sleeves use
  those different hedge legs.
- `XNGUSD.DWX`, `XBRUSD.DWX`, XAU/XAG, and index CFDs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 6-12 logical paired packages |
| Typical hold time | days to several weeks, capped at 30 days by default |
| Expected drawdown profile | Medium-high, driven by crude volatility and synchronized two-leg fills |
| Regime preference | Mean-revert relative-value dislocations between WTI and AUDCAD |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `EIA-RBA-BOC-XTI-AUDCAD-2026`
**Source type:** government research / central bank research
**Pointer:** `strategy-seeds/sources/EIA-RBA-BOC-XTI-AUDCAD-2026/`
**R1-R4 verdict (Q00):** all PASS / see
`strategy-seeds/cards/approved/QM5_13034_xti-audcad-rspr_card.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV to mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-07 | Initial build from approved card | manual-codex-2026-07-07-xti-audcad-rspr |
