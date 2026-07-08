# QM5_13073_xti-audusd-rspr - Strategy Spec

**EA ID:** QM5_13073
**Slug:** `xti-audusd-rspr`
**Source:** `EIA-RBA-WTI-AUD-2026` (see `strategy-seeds/sources/EIA-RBA-WTI-AUD-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-08

---

## 1. Strategy Logic

This EA trades a two-leg D1 return-spread reversion basket on `XTIUSD.DWX`
and `AUDUSD.DWX`. On each new D1 host bar it computes
`log(XTI[t] / XTI[t-L]) - beta_audusd * log(AUDUSD[t] / AUDUSD[t-L])`,
then standardizes that spread against a rolling lookback window.

`AUDUSD` rises when AUD strengthens against USD. The minus sign treats AUDUSD
as the commodity-FX hedge leg, so a high spread means WTI has outperformed AUD
and a low spread means WTI has underperformed AUD. When the z-score is above
the entry threshold, the EA sells WTI and buys AUDUSD. When the z-score is
below the negative entry threshold, it buys WTI and sells AUDUSD. The package exits when the z-score
reverts inside the exit band, the max-hold guard fires, Friday close fires, or
only one leg remains open.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 20 | 10-40 | D1 return window for both legs |
| `strategy_z_lookback_d1` | 120 | 80-180 | Rolling normalization window for the return spread |
| `strategy_beta_audusd` | 1.00 | 0.70-1.30 | AUDUSD return multiplier and risk-weight proxy |
| `strategy_entry_z` | 1.9 | 1.6-2.2 | Absolute z-score threshold for opening the basket |
| `strategy_exit_z` | 0.4 | 0.25-0.60 | Absolute z-score band for mean-reversion exit |
| `strategy_atr_period_d1` | 20 | 14-30 | D1 ATR lookback for each leg's hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | ATR multiple used for each leg's hard stop |
| `strategy_max_hold_days` | 30 | 20-45 | Maximum calendar days before closing the package |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | Maximum allowed XTI spread in points |
| `strategy_audusd_max_spread_pts` | 80 | 50-120 | Maximum allowed AUDUSD spread in points |
| `strategy_deviation_points` | 20 | fixed | Basket order slippage/deviation cap in points |

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - crude leg and host chart for the oil side of the return spread.
- `AUDUSD.DWX` - commodity-FX hedge leg representing AUD/global commodity beta.
- `QM5_13073_XTI_AUDUSD_RSPREAD_D1` - logical Q02 basket symbol backed by the two traded legs above.

**Explicitly NOT for:**
- `XNGUSD.DWX` - natural gas dynamics are outside the approved card.
- `USDCAD.DWX` - CAD exposure belongs to separate oil/CAD baskets.
- `CADJPY.DWX`, `CADCHF.DWX`, `GBPCAD.DWX`, or `AUDCAD.DWX` - covered by separate oil/CAD baskets.
- `AUDJPY.DWX` - covered by a separate WTI/AUDJPY return-spread basket.
- `XBRUSD.DWX` - Brent is excluded; the card is WTI against AUDUSD.

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
| Regime preference | Mean-revert relative-value dislocations between WTI and AUDUSD commodity-FX beta |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `EIA-RBA-WTI-AUD-2026`
**Source type:** government energy / central bank research
**Pointer:** `strategy-seeds/sources/EIA-RBA-WTI-AUD-2026/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_13073_xti-audusd-rspr.md`

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
| v1 | 2026-07-08 | Initial build from approved card | manual-codex-2026-07-08-xti-audusd-rspr |

