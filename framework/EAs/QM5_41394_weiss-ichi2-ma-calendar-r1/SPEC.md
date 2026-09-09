# QM5_41394_weiss-ichi2-ma-calendar-r1 — Strategy Spec

**EA ID:** QM5_41394  
**Slug:** `weiss-ichi2-ma-calendar-r1`  
**Source:** `3005c768-aa91-5daf-9dd7-500d7bfcb7a6` (see approved card)  
**Author of this spec:** Codex  
**Last revised:** 2026-09-09

---

## 1. Strategy Logic

The EA evaluates completed D1 bars. A long signal occurs when SMA(9)[1] is above SMA(26)[1] and SMA(26)[1] is rising versus SMA(26)[2]. A short signal occurs when SMA(26)[1] is below SMA(9)[1] and SMA(26)[1] is falling versus SMA(26)[2]. An opposite qualified signal closes the current position, after which the normal closed-bar entry path may reverse direction. New entries receive a catastrophic protective stop at `max(3 × ATR(20,D1), broker minimum)` and no profit target.

This is a new identity under `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909`, receipt `70823296-549a-4fba-8d2d-68ef34607664`. No earlier pipeline result, verdict, binary, setfile binding, or evidence is inherited.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_sma_period` | 9 | integer ≥ 1 | Fast D1 simple-moving-average period. |
| `strategy_slow_sma_period` | 26 | integer ≥ 1 | Slow D1 simple-moving-average period used for alignment and slope. |
| `strategy_atr_period` | 20 | integer ≥ 1 | D1 ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | 3.0 | real > 0 | ATR multiplier for the catastrophic stop distance. |

Framework inputs, including the current temporal/compliance calendar bundle, are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — approved liquid major-FX member of the source-card universe.
- `USDJPY.DWX` — approved liquid major-FX member of the source-card universe.
- `XAUUSD.DWX` — approved liquid metals member of the source-card universe.
- `SP500.DWX` — approved index research symbol; backtest-only pending any separate routing decision.
- `XTIUSD.DWX` — approved liquid energy member of the source-card universe.

**Explicitly NOT for:**

- Symbols outside the five entries above — no candidate-universe extension is authorized.
- Broker/live symbols — this build carries no T6 or live-use authorization.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on a D1 tester chart; indicator reads use `PERIOD_D1` completed bars |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 10 |
| Typical hold time | multiple days; stop-and-reverse trend holding |
| Expected drawdown profile | whipsaw losses during sideways regimes |
| Regime preference | sustained trend |
| Win rate target (qualitative) | low-to-medium, offset by larger trend wins |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3005c768-aa91-5daf-9dd7-500d7bfcb7a6`  
**Source type:** book  
**Pointer:** Richard L. Weissman, *Mechanical Trading Systems: Pairing Trader Psychology with Technical Analysis*, Wiley, 2005, Chapter 3, pp. 52–53; approved card at `artifacts/cards_approved/QM5_41394_weiss-ichi2-ma-calendar-r1.md`  
**R1–R4 verdict (G0):** all PASS in the approved card

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02–Q10) | `RISK_FIXED` | $1,000 per trade; `RISK_PERCENT=0` |
| Live burn-in (Q13) | `RISK_PERCENT` | not authorized by this build |
| Full live | `RISK_PERCENT` | not authorized by this build |

Environment-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`). The calendar bundle is also explicit: `qm_news_temporal`, `qm_news_compliance`, `qm_news_min_impact`, and `qm_news_stale_max_hours`, with stale allowance capped at 336 hours.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-09-09 | OWNER-authorized new-identity calendar-bundle rebuild | Fresh Q02 lineage only; build commit recorded in COMPILE_EA evidence. |
