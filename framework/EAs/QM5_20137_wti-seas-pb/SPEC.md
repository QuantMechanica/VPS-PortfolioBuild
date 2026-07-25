# QM5_20137_wti-seas-pb — Strategy Spec

**EA ID:** QM5_20137
**Slug:** `wti-seas-pb`
**Source:** `KELOHARJU-YANG-WTI-SEASPULL-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

On the first tradable D1 bar of each broker month, the EA estimates WTI's
historical return sign for that same calendar month over up to ten prior years
and reconstructs WTI's immediately completed broker-month log return. It opens
one `XTIUSD.DWX` position in the seasonal direction only when the two non-zero
signs disagree: long after a negative completed month when the seasonal state
is positive, and short after a positive completed month when the seasonal
state is negative.

The prior package closes before a replacement. Each package has a frozen
`3.5 * ATR(20)` hard stop, no profit target, and a 35-day stale guard. The
broker month is consumed before fallible gates, so aligned signs, a stop,
rejection, blocked gate, or restart cannot retry that month.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_history_years` | 10 | locked | Prior same-calendar years inspected |
| `strategy_min_history_years` | 5 | locked | Minimum valid seasonal samples |
| `strategy_history_bars` | 3000 | locked | Bounded D1 reconstruction buffer |
| `strategy_min_abs_return_pct` | 0.0 | locked | Strict sign; no fitted deadband |
| `strategy_atr_period` | 20 | locked | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.5 | locked | Frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | locked | Stale monthly-package guard |
| `strategy_max_spread_points` | 1500 | locked | Maximum entry spread |

Framework risk, news, stress, magic, and Friday-close inputs are documented in
`framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — registered Darwinex WTI CFD carrier for the cited
  same-calendar seasonality and commodity counter-move interaction.

**Explicitly NOT for:**

- `XNGUSD.DWX` — the current book already contains natural gas, and this
  extraction is specific to WTI.
- `XAUUSD.DWX` or `XAGUSD.DWX` — metals are outside this variant.
- Equity indices and FX — they are not the authorized carrier.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` plus `QM_CalendarPeriodKey(PERIOD_MN1, ...)` |

Only completed D1 month-end history enters either signal state. No intrabar
price path determines direction.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 5-7 after warm-up; retire below five completed |
| Typical hold time | one broker month, bounded at 35 calendar days |
| Expected drawdown profile | WTI gaps, failed seasonal continuation, and sparse interaction losses |
| Regime preference | recurring calendar direction after an immediately completed counter-move |
| Win rate target | unknown; no source performance claim |

The interaction is low-frequency and materially different from the book's
short-horizon XNG oscillator clock. Q02 and later gates remain authoritative.

---

## 6. Source Citation

- **Source ID:** `KELOHARJU-YANG-WTI-SEASPULL-2026`
- **Source type:** peer-reviewed primary plus governed academic supplement
- **Pointer:**
  `strategy-seeds/sources/KELOHARJU-YANG-WTI-SEASPULL-2026/source.md`
- **R1-R4 verdict (Q00):** all PASS; see
  `strategy-seeds/cards/approved/QM5_20137_wti-seas-pb_card.md`

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar information.
Yang, Goncu, and Pantelous supply commodity reversal lineage. Their
interaction and the Darwinex CFD package are QM hypotheses.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Not authorized by this build |
| Full live (post-Q13 PASS) | RISK_PERCENT | Not authorized by this build |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). Friday close is disabled to preserve the
month-spanning package. This build creates no live setfile and grants no live,
deploy, or portfolio authorization.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-25 | Initial build from approved card | build task `5beef69c-8a2b-4792-bd69-a5c654566f14`; Q02 work item `7dff45e1-d4c7-4f5c-b8e0-2f2ea254a725` |
