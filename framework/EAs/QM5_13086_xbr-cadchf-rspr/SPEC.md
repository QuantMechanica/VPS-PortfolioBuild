# QM5_13086_xbr-cadchf-rspr - Strategy Spec

**EA ID:** QM5_13086
**Slug:** `xbr-cadchf-rspr`
**Source:** `EIA-BOC-XBR-CADCHF-2026` (see `strategy-seeds/sources/EIA-BOC-XBR-CADCHF-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-09

---

## 1. Strategy Logic

This EA trades a two-leg D1 return-spread reversion basket on `XBRUSD.DWX`
and `CADCHF.DWX`. On each new D1 host bar it computes
`log(XBR[t] / XBR[t-L]) - beta_cadchf * log(CADCHF[t] / CADCHF[t-L])`,
then standardizes that spread against a rolling lookback window.

`CADCHF` rises when CAD strengthens versus CHF. The minus sign is intentional:
Brent and CADCHF are expected to partially confirm each other through the
oil-CAD channel, so unusually wide return dislocations are faded. When the
z-score is above the entry threshold, the EA sells Brent and buys CADCHF. When
the z-score is below the negative entry threshold, it buys Brent and sells
CADCHF. The package exits when the z-score reverts inside the exit band, the
max-hold guard fires, Friday close fires, or only one leg remains open.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 20 | 10-40 | D1 return window for both legs |
| `strategy_z_lookback_d1` | 120 | 80-180 | Rolling normalization window for the return spread |
| `strategy_beta_cadchf` | 0.55 | 0.35-0.80 | CADCHF return multiplier and risk-weight proxy |
| `strategy_entry_z` | 1.9 | 1.6-2.2 | Absolute z-score threshold for opening the basket |
| `strategy_exit_z` | 0.4 | 0.25-0.60 | Absolute z-score band for mean-reversion exit |
| `strategy_atr_period_d1` | 20 | 14-30 | D1 ATR lookback for each leg's hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | ATR multiple used for each leg's hard stop |
| `strategy_max_hold_days` | 30 | 20-45 | Maximum calendar days before closing the package |
| `strategy_xbr_max_spread_pts` | 1200 | 800-1800 | Maximum allowed XBR spread in points |
| `strategy_cadchf_max_spread_pts` | 80 | 60-120 | Maximum allowed CADCHF spread in points |
| `strategy_deviation_points` | 20 | fixed | Basket order slippage/deviation cap in points |

---

## 3. Symbol Universe

**Designed for:**
- `XBRUSD.DWX` - Brent crude leg and host chart for the oil side of the return spread.
- `CADCHF.DWX` - CAD confirmation leg against defensive CHF.
- `QM5_13086_XBR_CADCHF_RSPREAD_D1` - logical Q02 basket symbol backed by the two traded legs above.

**Explicitly NOT for:**
- `XTIUSD.DWX` - covered by the separate `QM5_13011_xti-cadchf-rspr`.
- `USDCAD.DWX`, `AUDCAD.DWX`, and `CADJPY.DWX` - covered by separate Brent/oil-FX basket cards.
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
| Trades / year / symbol | 5-10 logical paired packages |
| Typical hold time | days to several weeks, capped at 30 days by default |
| Expected drawdown profile | Medium-high, driven by Brent volatility and synchronized two-leg fills |
| Regime preference | Mean-revert relative-value dislocations between Brent and CADCHF |
| Win rate target | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `EIA-BOC-XBR-CADCHF-2026`
**Source type:** official energy research / central bank research
**Pointer:** `strategy-seeds/sources/EIA-BOC-XBR-CADCHF-2026/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_13086_xbr-cadchf-rspr.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV to mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

---

## Evidence

- Build result: `artifacts/qm5_13086_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13086_q02_enqueue_20260709.json`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-09 | Mission-directed XBR/CADCHF return-spread basket build | Enqueue to Q02 |
