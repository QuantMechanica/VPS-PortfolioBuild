# QM5_20135_wti-winter-trend — Strategy Spec

**EA ID:** QM5_20135
**Slug:** `wti-winter-trend`
**Source:** `BURAKOV-MOP-WTI-WINTER-TREND-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

On the first tradable D1 bar of each broker month from November through May,
the EA computes the completed 252-D1 WTI log return:

`momentum = ln(Close[1] / Close[253])`.

It opens one monthly `XTIUSD.DWX` package long when momentum is positive and
short when momentum is negative. Exact equality remains flat. An older package
closes before the new monthly decision. June through October is a forced-flat
state.

Each package has a frozen `4.0 * ATR(20)` hard stop, no profit target, and a
35-day stale guard. The broker month is consumed before fallible gates, so a
stop, rejection, blocked gate, or restart cannot retry the month.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_first_active_month` | 11 | locked | First winter-regime entry month |
| `strategy_last_active_month` | 5 | locked | Final winter-regime entry month |
| `strategy_momentum_lookback_d1` | 252 | locked | Completed own-return horizon |
| `strategy_min_abs_return_pct` | 0.0 | locked | No deadband; strict return sign |
| `strategy_atr_period` | 20 | locked | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 4.0 | locked | Frozen hard-stop distance |
| `strategy_max_hold_days` | 35 | locked | Stale guard around monthly renewal |
| `strategy_max_spread_points` | 1500 | locked | Maximum entry spread |

Framework risk, news, stress, magic, and Friday-close inputs are documented in
`framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — registered Darwinex WTI CFD carrier for the source-backed
  winter regime and own-return trend hypothesis.

**Explicitly NOT for:**

- `XNGUSD.DWX` — the certified book already contains natural gas, and its
  seasonal mechanics use different physical windows.
- `XAUUSD.DWX` or `XAGUSD.DWX` — metals are outside the cited WTI evidence.
- Equity indices and FX — their calendar regimes are not the cited energy
  regime.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` plus `QM_CalendarPeriodKey(PERIOD_MN1, ...)` |

The EA reads completed D1 closes only. No intrabar price path determines the
signal.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | seven eligible packages after warm-up; retire below five completed |
| Typical hold time | one broker month, bounded at 35 calendar days |
| Expected drawdown profile | crude-oil gap and trend-reversal losses with monthly leverage reset |
| Regime preference | directional WTI persistence inside November-May |
| Win rate target | unknown; no source performance claim |

The interaction is expected to be sparse, tail-sensitive, and materially
different from the book's short-horizon XNG reversion clock. Q02 and later
gates remain authoritative.

---

## 6. Source Citation

- **Source ID:** `BURAKOV-MOP-WTI-WINTER-TREND-2026`
- **Source type:** two peer-reviewed governed paper lineages
- **Pointer:**
  `strategy-seeds/sources/BURAKOV-MOP-WTI-WINTER-TREND-2026/source.md`
- **R1-R4 verdict (Q00):** all PASS; see
  `strategy-seeds/cards/approved/QM5_20135_wti-winter-trend_card.md`

Burakov, Freidin, and Solovyev supply the alternative-two November-May WTI
regime. Moskowitz, Ooi, and Pedersen supply the own-past-return-sign mechanic.
Their interaction and the Darwinex CFD package are QM hypotheses.

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
| v1 | 2026-07-25 | Initial build from approved card | build task `cbc28003-dc43-4c3c-8ee2-ac2a71fb6e06`; Q02 work item `063e9d6c-8a54-461a-8113-a3f098e3e5e7` |
