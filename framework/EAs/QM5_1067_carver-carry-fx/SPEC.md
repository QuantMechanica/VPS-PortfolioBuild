# QM5_1067_carver-carry-fx — Strategy Spec

**EA ID:** QM5_1067
**Slug:** `carver-carry-fx`
**Source:** `2a380bee-1ec4-50d1-a348-b10fac642c7a`
**Author of this spec:** Claude
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

On each closed D1 bar the EA computes an EWMA standard deviation of daily price returns (span=25 bars), annualises it by √256, then divides the user-supplied annualised carry in basis points by the annualised vol to get a raw carry ratio. The ratio is scaled by a forecast scalar (30) and capped at ±20. If the capped forecast exceeds +2 the EA goes long; below −2 it goes short. The position is closed when the forecast crosses zero (carry signal reverses); a 2.5×ATR(20,D1) emergency stop is placed at entry. One position per symbol/magic at a time; no trailing stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `InpCarryBpsAnnual` | 100.0 | any | Annualised carry in bps (+long earns, −short earns). 0=broker swap (=0 in DWX). Set per-symbol in setfile. |
| `InpEWMASpan` | 25 | 5–100 | EWMA span (bars) for daily-return vol. Carver default = 25. |
| `InpForecastScalar` | 30.0 | 10–50 | Multiplies raw carry ratio to get forecast. |
| `InpForecastCap` | 20.0 | 5–50 | Forecast capped at ±this value. |
| `InpEntryForecast` | 2.0 | 0.5–10 | Min |forecast| to enter. |
| `InpAtrPeriod` | 20 | 5–50 | D1 ATR period for emergency stop distance. |
| `InpAtrSlMult` | 2.5 | 1.0–5.0 | ATR multiplier for SL. |
| `InpSpreadCapPips` | 5.0 | 0–20 | Max spread in pips to allow entry (0=off). DWX spread=0, never blocks. |

---

## 3. Symbol Universe

**Designed for:**
- `AUDJPY.DWX` — AUD/JPY carry pair: AUD typically high-yielding vs JPY low-yielding
- `NZDJPY.DWX` — NZD/JPY carry pair: similar carry profile to AUD/JPY
- `AUDUSD.DWX` — AUD/USD: moderate carry when AUD rates exceed USD
- `NZDUSD.DWX` — NZD/USD: NZD occasionally higher-yielding
- `USDJPY.DWX` — USD/JPY: USD vs near-zero JPY rates = reliable carry
- `GBPJPY.DWX` — GBP/JPY: GBP rates vs JPY; significant carry in high-rate regimes
- `EURUSD.DWX` — EUR/USD: smaller carry differential, diversifies the basket
- `USDCAD.DWX` — USD/CAD: USD vs CAD rate differential

**Explicitly NOT for:**
- Index or commodity DWX symbols — no interest-rate carry concept applies

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none (EWMA uses PERIOD_D1 shifted closes) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~2 |
| Typical hold time | weeks to months |
| Expected drawdown profile | slow-moving, drawdowns during carry unwind events |
| Regime preference | trending / carry (persistent interest-rate differential) |
| Win rate target (qualitative) | medium (carry strategies have moderate hit rate, high RR) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `2a380bee-1ec4-50d1-a348-b10fac642c7a`
**Source type:** blog / book (Rob Carver, Systematic Trading ch.7)
**Pointer:** https://qoppac.blogspot.com/2015/09/python-code-for-two-trading-rules-in.html
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1067_carver-carry-fx.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-25 | Initial build from card | 649b99a9-4264-408d-b27c-74c343bc97b0 |
