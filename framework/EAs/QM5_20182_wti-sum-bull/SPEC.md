# QM5_20182_wti-sum-bull — Strategy Spec

**EA ID:** QM5_20182
**Slug:** `wti-sum-bull`
**Source:** `EWALD-MOP-WTI-SUMBULL-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-29

---

## 1. Strategy Logic

On the first tradable D1 bar of each broker-calendar week from July through
November, the EA computes WTI's completed 252-D1 log return. It opens one
short `XTIUSD.DWX` position only when that return is strictly positive.

The package has a frozen `3.0 * ATR(20)` hard stop, no profit target, and a
seven-day stale guard. The framework Friday-close control at broker hour 21 is
the ordinary exit. The broker week is consumed before fallible gates, so a
non-positive trend state, rejection, blocked gate, stop, or restart cannot retry
the week.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_start_month` | 7 | locked | First Ewald WTI short-window month |
| `strategy_end_month` | 11 | locked | Final entry month before December cover |
| `strategy_momentum_lookback_d1` | 252 | locked | Completed WTI return horizon |
| `strategy_min_abs_return_pct` | 0.0 | locked | Strict positive sign; no deadband |
| `strategy_atr_period` | 20 | locked | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.0 | locked | Frozen hard-stop distance |
| `strategy_max_hold_days` | 7 | locked | Weekly stale-position guard |
| `strategy_max_spread_points` | 1500 | locked | Maximum entry spread |

Framework risk, news, stress, magic, and Friday-close inputs are documented in
`framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — registered Darwinex WTI CFD carrier for the cited
  trading-time seasonality and own-return trend interaction.

**Explicitly NOT for:**

- `XNGUSD.DWX` — the certified book already contains natural gas, and the
  source-defined direction here is WTI-specific.
- `XAUUSD.DWX` or `XAGUSD.DWX` — metals are outside this extraction.
- Equity indices and FX — they are not authorized carriers.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | framework `QM_IsNewBar()` |
| Calendar gate | Monday-anchored broker week derived from D1 bar times |

Only completed D1 history enters the trend state. No intrabar price path
determines direction.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 5-14; retire below five completed on average |
| Typical hold time | first weekly bar through Friday, bounded at seven calendar days |
| Expected drawdown profile | WTI gaps and short squeezes during positive slow-trend states |
| Regime preference | July-November seasonal short counter to a positive 252-D1 trend |
| Win rate target | unknown; no source performance claim |

The candidate is low-frequency and uses a physical-energy information clock
different from the certified index/metal book. Q02 and later gates remain
authoritative.

---

## 6. Source Citation

- **Source ID:** `EWALD-MOP-WTI-SUMBULL-2026`
- **Source type:** governed composite of two peer-reviewed journal papers
- **Pointer:**
  `strategy-seeds/sources/EWALD-MOP-WTI-SUMBULL-2026/source.md`
- **R1-R4 verdict (G0):** all PASS; see
  `strategy-seeds/cards/approved/QM5_20182_wti-sum-bull_card.md`

Ewald et al. supply the July-to-December WTI trading-time short. Moskowitz,
Ooi, and Pedersen establish the completed 12-month own-return state. Using
the positive state as a counterfade condition, and the continuous-CFD weekly
package, are explicit QM hypotheses rather than source performance claims.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in | RISK_PERCENT | Not authorized by this build |
| Full live | RISK_PERCENT | Not authorized by this build |

Environment-to-risk validation is enforced by `QM_FrameworkInit`. Friday
close is enabled to create non-overlapping weekly packages. This build creates
no live setfile and grants no live, deploy, certification, portfolio, or
correlation authorization.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-29 | Initial build from approved G0 card | Q01 PASS; Q02 not yet enqueued |
