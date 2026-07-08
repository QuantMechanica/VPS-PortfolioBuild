# QM5_13071_xti-usdchf-rspr - Strategy Spec

**EA ID:** QM5_13071
**Slug:** `xti-usdchf-rspr`
**Source:** `EIA-SNB-XTI-USDCHF-RSPREAD-2026` (see `strategy-seeds/sources/EIA-SNB-XTI-USDCHF-RSPREAD-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-08

---

## 1. Strategy Logic

This EA trades a two-leg D1 return-spread reversion basket on `XTIUSD.DWX`
and `USDCHF.DWX`. On each new D1 host bar it computes
`log(XTI[t] / XTI[t-L]) + beta_usdchf * log(USDCHF[t] / USDCHF[t-L])`,
then standardizes that spread against a rolling lookback window.

The plus sign expresses WTI in CHF terms: USDCHF rises when CHF weakens versus
USD, so the spread captures WTI strength combined with weaker CHF, or WTI
weakness combined with stronger CHF. When the z-score is above the entry
threshold, the EA sells WTI and sells USDCHF. When the z-score is below the
negative entry threshold, it buys WTI and buys USDCHF. The package exits when
the z-score reverts inside the exit band, the max-hold guard fires, Friday
close fires, or only one leg remains open.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 20 | 10-40 | D1 return window for both legs |
| `strategy_z_lookback_d1` | 120 | 80-180 | Rolling normalization window for the return spread |
| `strategy_beta_usdchf` | 0.75 | 0.50-1.00 | USDCHF return multiplier and risk-weight proxy |
| `strategy_entry_z` | 2.0 | 1.7-2.3 | Absolute z-score threshold for opening the basket |
| `strategy_exit_z` | 0.35 | 0.20-0.50 | Absolute z-score band for mean-reversion exit |
| `strategy_atr_period_d1` | 20 | 14-30 | D1 ATR lookback for each leg's hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | ATR multiple used for each leg's hard stop |
| `strategy_max_hold_days` | 30 | 20-45 | Maximum calendar days before closing the package |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | Maximum allowed XTI spread in points |
| `strategy_usdchf_max_spread_pts` | 80 | 50-120 | Maximum allowed USDCHF spread in points |
| `strategy_deviation_points` | 20 | fixed | Basket order slippage/deviation cap in points |

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - crude leg and host chart for the oil side of the return spread.
- `USDCHF.DWX` - CHF safe-haven FX leg used to express oil in CHF terms.
- `QM5_13071_XTI_USDCHF_RSPREAD_D1` - logical Q02 basket symbol backed by the two traded legs above.

**Explicitly NOT for:**
- `XNGUSD.DWX` - natural gas dynamics are outside the approved card.
- `XAUUSD.DWX` / `XAGUSD.DWX` - metal-ratio logic is outside this sleeve.
- `GBPCAD.DWX`, `AUDJPY.DWX`, `EURCAD.DWX`, `CADJPY.DWX`, or `CADCHF.DWX` - covered by separate oil/FX baskets.
- `USDJPY.DWX` or `EURGBP.DWX` - CHF-only FX cointegration is not this energy/FX sleeve.
- `XBRUSD.DWX` - Brent is excluded; the card is WTI against USDCHF.

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
| Trades / year / symbol | 5-10 logical paired packages |
| Typical hold time | days to several weeks, capped at 30 days by default |
| Expected drawdown profile | Medium-high, driven by crude volatility and synchronized two-leg fills |
| Regime preference | Mean-revert relative-value dislocations between WTI and CHF safe-haven pressure |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `EIA-SNB-XTI-USDCHF-RSPREAD-2026`
**Source type:** government energy / central bank research
**Pointer:** `strategy-seeds/sources/EIA-SNB-XTI-USDCHF-RSPREAD-2026/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_13071_xti-usdchf-rspr.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-08 | Initial build from approved card | manual-codex-2026-07-08-xti-usdchf-rspr |
