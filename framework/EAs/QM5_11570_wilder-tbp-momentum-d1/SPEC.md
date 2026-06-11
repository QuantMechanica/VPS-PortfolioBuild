# QM5_11570_wilder-tbp-momentum-d1 - Strategy Spec

**EA ID:** QM5_11570
**Slug:** wilder-tbp-momentum-d1
**Source:** 0ab0a479-4a09-5ecc-bb90-6a37148fa78b (see local book/source registry)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades Wilder's D1 Trend Balance Point momentum setup on each newly closed daily bar. The momentum factor is the latest completed close minus the close two bars earlier; a long signal fires when that factor is higher than the prior two momentum factors, and a short signal fires when it is lower than both. The EA enters at market on the next available tick and places the protective stop and target from the prior daily bar: X = (High + Low + Close) / 3, true range from the prior bar, long stop at X - TR, short stop at X + TR, long target at 2X - Low, and short target at 2X - High. No reversal is taken after either stop or target; the EA waits for the next D1 signal.

---

## 2. Parameters

The strategy card declares no free strategy parameters. Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| none | n/a | n/a | Wilder TBP constants are fixed by the approved card. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed DWX forex major with D1 OHLC history.
- GBPUSD.DWX - card-listed DWX forex major with D1 OHLC history.
- USDJPY.DWX - card-listed DWX forex major with D1 OHLC history.
- AUDUSD.DWX - card-listed DWX forex major with D1 OHLC history.
- USDCAD.DWX - card-listed DWX forex major with D1 OHLC history.
- USDCHF.DWX - card-listed DWX forex major with D1 OHLC history.
- GBPJPY.DWX - card-listed DWX forex cross with D1 OHLC history.

**Explicitly NOT for:**
- Index, metals, energy, and non-card FX symbols - not listed in the approved card's target universe for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Open until prior-bar SL or TP is hit; expected to be short multi-day when target is reached quickly. |
| Expected drawdown profile | Wider volatility-derived stops with small targets; losing streaks possible if FX momentum extrema do not follow through. |
| Regime preference | D1 momentum follow-through after local two-day momentum extrema. |
| Win rate target (qualitative) | high per source claim, subject to P2 FX validation |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0ab0a479-4a09-5ecc-bb90-6a37148fa78b
**Source type:** book
**Pointer:** local book/source registry entry `0ab0a479-4a09-5ecc-bb90-6a37148fa78b`; J. Welles Wilder Jr., *New Concepts in Technical Trading Systems*, Section V.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11570_wilder-tbp-momentum-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | f641a8a2-be64-47f4-b369-bf15d395ae39 |
