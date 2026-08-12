# QM5_11411_wilder-parabolic-sar-reversal-d1 — Strategy Spec

**EA ID:** QM5_11411
**Slug:** `wilder-parabolic-sar-reversal-d1`
**Source:** `0ab0a479-4a09-5ecc-bb90-6a37148fa78b`
**Author of this spec:** Codex
**Last revised:** 2026-08-08

---

## 1. Strategy Logic

This D1 system is always positioned in the direction indicated by Wilder's Parabolic SAR. A bullish reversal occurs when the SAR moves from above the prior daily price range to below the just-closed range; a bearish reversal is the mirror, and the EA enters at the next bar's market open. The initial stop is the current SAR value, capped at 100 pips from entry, and it advances to each new closed-bar SAR value; an opposite SAR state closes and reverses the position. The optional DI(14) switch permits a long only when +DI exceeds -DI and a short only when -DI exceeds +DI.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sar_step` | 0.02 | 0.01–0.03 | PSAR acceleration-factor start and increment. |
| `strategy_sar_maximum` | 0.20 | 0.15–0.25 | Maximum PSAR acceleration factor. |
| `strategy_use_di_filter` | false | false/true | Enables the card's optional DI direction filter. |
| `strategy_di_period` | 14 | fixed at 14 | Wilder directional-index period. |
| `strategy_max_sl_pips` | 100 | fixed at 100 | Maximum initial stop distance for the P2 baseline. |
| `strategy_spread_cap_pips` | 25 | fixed at 25 | Blocks a new entry only when modeled spread genuinely exceeds 25 pips. |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid major FX pair with D1 trend legs suitable for PSAR.
- `GBPUSD.DWX` — liquid major with sustained daily directional swings.
- `USDJPY.DWX` — liquid major whose macro trends suit stop-and-reverse logic.
- `AUDUSD.DWX` — liquid commodity-linked major with persistent D1 moves.
- `USDCAD.DWX` — liquid commodity-linked major with multi-day trend legs.

**Explicitly NOT for:**

- Non-FX symbols — the approved card scopes this baseline to the five named DWX major pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)`; all strategy reads use closed `PERIOD_D1` bars |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Expected trade frequency | approximately 2–3 reversals per month |
| Typical hold time | days to weeks, one PSAR trend leg |
| Expected drawdown profile | clustered small whipsaw losses during range-bound periods |
| Regime preference | trend-following |
| Win rate target (qualitative) | low-to-medium, with larger trend wins offsetting whipsaws |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0ab0a479-4a09-5ecc-bb90-6a37148fa78b`
**Source type:** book
**Pointer:** J. Welles Wilder Jr., *New Concepts in Technical Trading Systems* (Trend Research, 1978), Section II; local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\53093880-Welles-Wilder-New-Concepts-in-Technical-Trading-Systems.pdf`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11411_wilder-parabolic-sar-reversal-d1.md`

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
| v1 | 2026-08-08 | Initial build from card | 7f656d49-591c-4f18-a746-9abe373f5918 |
