# QM5_41240_wti-samecal-ramsaye5 — Strategy Spec

**EA ID:** QM5_41240
**Slug:** `wti-samecal-ramsaye5`
**Source:** `KELOHARJU-STATSMODELS-WTI-SAMECAL-RAMSAYE5-2026`
**Author of this spec:** Codex
**Last revised:** 2026-09-08

---

## 1. Strategy Logic

At the first executable D1 bar of each new normalized broker month, the EA reconstructs WTI's completed log return for that same calendar month in each exact year from Y-5 through Y-1. It starts at the five-return median, freezes the scale at `1.4826 × raw MAD`, then performs exactly 32 Ramsay-E weighted-location updates using `weight = exp(-0.3 × abs((return - location) / scale))`. It buys when the final location is strictly above `1e-12`, sells when it is strictly below `-1e-12`, and remains flat otherwise. The monthly attempt is consumed before fallible entry checks; an open trade keeps its initial `3.5 × ATR(20,D1)` hard stop and exits at the next normalized month or after 40 elapsed calendar days as repair.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_history_years` | 5 | locked at 5 | Exact prior matching-calendar years required |
| `strategy_history_bars_d1` | 3000 | locked at 3000 | Bounded D1 endpoint scan |
| `strategy_scale_multiplier` | 1.4826 | locked at 1.4826 | Frozen raw-MAD scale multiplier |
| `strategy_ramsay_a` | 0.3 | locked at 0.3 | Ramsay-E exponential attenuation constant |
| `strategy_ramsay_iterations` | 32 | locked at 32 | Fixed weighted-location update count |
| `strategy_signal_epsilon` | 1e-12 | locked at 1e-12 | Inclusive no-trade band around zero |
| `strategy_atr_period_d1` | 20 | locked at 20 | Completed D1 bars used for ATR |
| `strategy_atr_sl_mult` | 3.5 | locked at 3.5 | Initial hard-stop distance in ATR units |
| `strategy_max_hold_days` | 40 | locked at 40 | Survivor-repair time limit in calendar days |
| `strategy_max_spread_points` | 1500 | locked at 1500 | Maximum positive entry spread in points |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — the approved card defines direct WTI crude-oil exposure and the DWX matrix provides the required D1 history.

**Explicitly NOT for:**

- Every other `.DWX` symbol — the card is explicitly single-symbol and forbids proxies, baskets, or symbol expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

Execution, endpoint reconstruction, ATR, and the normalized broker-month clock are D1-native.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 11 |
| Expected trade frequency | Approximately 10–12 completed WTI positions per full post-warm-up year; Q02 must prove at least five in every full scored year or retire |
| Typical hold time | Until the first executable D1 tick of the next normalized broker month, with a 40-calendar-day survivor repair |
| Expected drawdown profile | High-risk class; card prior `expected_dd_pct` is 30% |
| Regime preference | Calendar-seasonality; no trend, volatility, event, carry, or prior-result regime gate |
| Win rate target (qualitative) | Not specified by the approved card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `KELOHARJU-STATSMODELS-WTI-SAMECAL-RAMSAYE5-2026`
**Source type:** governed composite of peer-reviewed trading papers and the official statsmodels Ramsay-E implementation
**Pointer:** `strategy-seeds/sources/KELOHARJU-STATSMODELS-WTI-SAMECAL-RAMSAYE5-2026/source.md`; approved runtime card at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_41240_wti-samecal-ramsaye5_card.md`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_41240_wti-samecal-ramsaye5.md`.

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
| v1 | 2026-09-08 | Initial build from card | 2a064c71-8567-47e2-80a4-b02948aa510f |
