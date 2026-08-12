# QM5_20136_wti-caltrend — Strategy Spec

**EA ID:** QM5_20136
**Slug:** `wti-caltrend`
**Source:** `KELOHARJU-MOP-WTI-CALTREND-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

On the first tradable D1 bar of each broker month, the EA estimates WTI's
historical return sign for that same calendar month over up to ten prior years
and computes the sign of WTI's completed 63-D1 log return. It opens one
`XTIUSD.DWX` position only when both non-zero signs agree: long for two
positive signs and short for two negative signs.

The prior package closes before a replacement. Each package has a frozen
`3.5 * ATR(20)` hard stop, no profit target, and a 35-day stale guard. The
broker month is consumed before fallible gates, so disagreement, a stop,
rejection, blocked gate, or restart cannot retry that month.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_history_years` | 10 | locked | Prior same-calendar years inspected |
| `strategy_min_history_years` | 5 | locked | Minimum valid seasonal samples |
| `strategy_history_bars` | 3000 | locked | Bounded D1 reconstruction buffer |
| `strategy_momentum_lookback_d1` | 63 | locked | Completed trend horizon |
| `strategy_min_abs_return_pct` | 0.0 | locked | Strict sign; no deadband |
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
  same-calendar seasonality and own-return trend interaction.

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

Only completed D1 history enters either signal state. No intrabar price path
determines direction.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 5-8 after warm-up; retire below five completed |
| Typical hold time | one broker month, bounded at 35 calendar days |
| Expected drawdown profile | WTI gaps, trend reversals, and sparse sign-agreement losses |
| Regime preference | recurring calendar direction confirmed by medium-horizon trend |
| Win rate target | unknown; no source performance claim |

The interaction is deliberately low-frequency and materially different from
the book's short-horizon XNG reversion clock. Q02 and later gates remain
authoritative.

---

## 6. Source Citation

- **Source ID:** `KELOHARJU-MOP-WTI-CALTREND-2026`
- **Source type:** two peer-reviewed governed paper lineages
- **Pointer:**
  `strategy-seeds/sources/KELOHARJU-MOP-WTI-CALTREND-2026/source.md`
- **R1-R4 verdict (Q00):** all PASS; see
  `strategy-seeds/cards/approved/QM5_20136_wti-caltrend_card.md`

Keloharju, Linnainmaa, and Nyberg supply recurring same-calendar information.
Moskowitz, Ooi, and Pedersen supply the own-past-return trend state. Their
agreement and the Darwinex CFD package are QM hypotheses.

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
| v1 | 2026-07-25 | Initial build from approved card | build task `23cb27a1-f8ce-4772-bea5-607597baebb9`; Q02 work item `1dc49254-5e14-401c-b2cb-440d98817ff4` |
