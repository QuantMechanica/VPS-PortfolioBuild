# QM5_11767_connors-double7s-200sma-d1 - Strategy Spec

**EA ID:** QM5_11767
**Slug:** `connors-double7s-200sma-d1`
**Source:** `ef7afc8e-406f-5f05-90d5-8258a7fb7123` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades the Connors/Alvarez Double 7s rule on D1 closes. It enters long when the last closed D1 bar is above SMA(200) and is the lowest close in the last 7 closed D1 bars, then enters at the next D1 bar open. It enters short using the factory-added symmetric rule: close below SMA(200) and highest close in the last 7 closed D1 bars. Long positions exit when the last closed D1 bar is the highest close in the 7-bar window; short positions exit when it is the lowest close in the 7-bar window.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sma_period` | 200 | `1+` | D1 SMA trend filter period. |
| `strategy_extreme_lookback` | 7 | `1+` | Number of closed D1 bars used for lowest/highest close entry and exit tests. |
| `strategy_atr_period` | 14 | `1+` | D1 ATR period for factory stop and hard take-profit cap. |
| `strategy_atr_sl_mult` | 2.0 | `> 0` | Stop-loss distance in ATR multiples. |
| `strategy_atr_tp_mult` | 4.0 | `> 0` | Hard take-profit cap distance in ATR multiples. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-targeted major forex pair available in the DWX matrix.
- `GBPUSD.DWX` - Card-targeted major forex pair available in the DWX matrix.
- `USDJPY.DWX` - Card-targeted major forex pair available in the DWX matrix.
- `USDCHF.DWX` - Card-targeted major forex pair available in the DWX matrix.
- `AUDUSD.DWX` - Card-targeted major forex pair available in the DWX matrix.
- `USDCAD.DWX` - Card-targeted major forex pair available in the DWX matrix.

**Explicitly NOT for:**
- Non-card symbols - The approved card adapts Double 7s specifically to the six listed forex majors; other symbols require a separate card or registry expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entries; D1 closed-bar gate for exits while a position is open |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `25` |
| Expected trade frequency | About 25 D1 signals per symbol per year, from card frontmatter cadence. |
| Typical hold time | Multi-day hold until the opposite 7-bar close extreme appears. |
| Regime preference | Mean-reversion pullback inside an SMA(200) trend regime. |
| Win rate target (qualitative) | Medium to high; exits seek recovery to the 7-bar opposite close extreme. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ef7afc8e-406f-5f05-90d5-8258a7fb7123`
**Source type:** book
**Pointer:** Larry Connors and Cesar Alvarez, "Double 7s Strategy", in *Short-Term Trading Strategies That Work*, 2009; approved card at `artifacts/cards_approved/QM5_11767_connors-double7s-200sma-d1.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11767_connors-double7s-200sma-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | 103d3093-1ce1-4768-9bdc-94643fb29d72 |
