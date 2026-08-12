# QM5_20160_xng-fri-trend — Strategy Spec

**EA ID:** QM5_20160
**Slug:** `xng-fri-trend`
**Source:** `BOROWSKI-MOP-XNG-FRITREND-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

On the first observed tick of each genuine Friday D1 bar immediately following
a completed Thursday D1 bar, the EA computes XNG's strictly completed 252-D1 log
return. It opens one short `XNGUSD.DWX` position only when that return is
strictly negative.

The package has a frozen `3.0 * ATR(20)` hard stop, no profit target, and a
two-day stale repair. The first non-Friday D1 bar is the ordinary exit. The
broker week is consumed before fallible gates, so a non-negative trend state,
rejection, blocked gate, stop, or restart cannot retry the week.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_d1` | 252 | locked | Completed XNG return horizon |
| `strategy_min_abs_return_pct` | 0.0 | locked | Strict negative sign; no deadband |
| `strategy_entry_grace_minutes` | 5 | locked | Maximum Friday-bar attachment delay |
| `strategy_atr_period` | 20 | locked | Completed D1 ATR estimator |
| `strategy_atr_sl_mult` | 3.0 | locked | Frozen hard-stop distance |
| `strategy_max_hold_days` | 2 | locked | Missed-next-bar stale repair |
| `strategy_max_spread_points` | 2500 | locked | Maximum entry spread |

Framework risk, news, stress, magic, and Friday-close inputs are documented in
`framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `XNGUSD.DWX` — registered Darwinex XNG CFD carrier for the cited Friday
  weakness and own-return trend interaction.

**Explicitly NOT for:**

- `XNGUSD.DWX` — the certified book already contains natural gas, and this
  source-defined interaction is XNG-specific.
- `XAUUSD.DWX` or `XAGUSD.DWX` — metals are outside this extraction.
- Equity indices and FX — they are not authorized carriers.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | framework `QM_IsNewBar()` |
| Calendar gate | current bar Friday and prior completed bar Thursday |
| Attempt key | Monday-anchored broker week derived from D1 bar time |

Only completed D1 history enters the trend state. The current Friday bar's
first executable quote determines entry; the Thursday-close to Friday-open gap
is not captured and is a declared falsification risk.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 12-30; retire below five completed on average |
| Typical hold time | Friday session only, bounded at two calendar days |
| Expected drawdown profile | XNG gaps and short squeezes during negative slow-trend states |
| Regime preference | Friday weakness aligned with negative 252-D1 XNG trend |
| Win rate target | unknown; no source performance claim |

The candidate is low-frequency and uses a physical-energy information clock
different from the certified index/metal book. Q02 and later gates remain
authoritative.

---

## 6. Source Citation

- **Source ID:** `BOROWSKI-MOP-XNG-FRITREND-2026`
- **Source type:** governed composite of two peer-reviewed journal papers
- **Pointer:**
  `strategy-seeds/sources/BOROWSKI-MOP-XNG-FRITREND-2026/source.md`
- **R1-R4 verdict (G0):** all PASS; see
  `strategy-seeds/cards/approved/QM5_20160_xng-fri-trend_card.md`

Borowski supply the XNG Friday direction. Moskowitz, Ooi, and
Pedersen supply the completed 12-month own-return sign. Their conjunction and
the continuous-CFD Friday-open package are QM hypotheses.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in | RISK_PERCENT | Not authorized by this build |
| Full live | RISK_PERCENT | Not authorized by this build |

Environment-to-risk validation is enforced by `QM_FrameworkInit`. Friday close
is enabled as a fail-safe, though the next-D1 exit should ordinarily leave no
position by Friday. This build creates no live setfile and grants no live,
deploy, certification, portfolio, or correlation authorization.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-25 | Initial build from approved G0 card | Q01 PASS; Q02 not enqueued because the seven-terminal factory CPU ceiling was occupied |
