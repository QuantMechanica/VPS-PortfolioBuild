# QM5_20128_xng-stor-fade — Strategy Spec

**EA ID:** QM5_20128
**Slug:** `xng-stor-fade`
**Source:** `EIA-XNG-STORAGE-AFTERSHOCK-2026` (see `strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

On standard Thursdays, the EA waits for two completed New York M30 bars:
the 10:30-11:00 EIA natural-gas storage release impulse and the
11:00-11:30 reclaim confirmation.

The release bar must be directional, span at least `0.75 * ATR(20)`, and
close beyond the preceding 09:30-10:30 range. The confirmation must have the
opposite body direction and close back inside that prior range and beyond the
release midpoint. At 11:30 the EA fades the failed break toward the release
open.

The 11:30 decision consumes the New York date before any fallible gate. A
hard stop sits beyond the more extreme of the release and confirmation bars
plus `0.25 * ATR(20)`. Take profit is the release open, subject to a minimum
reward/risk of `0.50`. Remaining exposure closes at 15:55 New York, on a New
York date change, or after six hours.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_release_hhmm_ny` | 1030 | locked | Standard WNGSR release-bar open |
| `strategy_confirmation_hhmm_ny` | 1100 | locked | Reclaim confirmation-bar open |
| `strategy_entry_hhmm_ny` | 1130 | locked | Entry after both bars complete |
| `strategy_pre_release_bars` | 2 | locked | M30 bars forming the prior-hour range |
| `strategy_min_release_range_atr` | 0.75 | locked | Minimum release range / ATR |
| `strategy_min_body_ratio` | 0.50 | locked | Minimum release body / range |
| `strategy_reclaim_mid_fraction` | 0.50 | locked | Required release-midpoint cross |
| `strategy_atr_period` | 20 | locked | Release-bar ATR estimator |
| `strategy_stop_buffer_atr` | 0.25 | locked | Buffer beyond event extremes |
| `strategy_min_reward_risk` | 0.50 | locked | Release-open target geometry floor |
| `strategy_entry_grace_minutes` | 15 | locked | Maximum late first tick after 11:30 |
| `strategy_session_flat_hhmm_ny` | 1555 | locked | Same-session forced-flat time |
| `strategy_max_hold_hours` | 6 | locked | Final stale-position guard |
| `strategy_max_spread_points` | 2500 | locked | Maximum entry spread |

Framework risk, news, stress, magic, and Friday-close inputs are documented in
`framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `XNGUSD.DWX` — registered Darwinex natural-gas CFD carrier for the EIA
  storage-release event.

**Explicitly NOT for:**

- `XTIUSD.DWX` — crude oil responds to the separate petroleum report.
- Metals, equity indices, or FX — they do not represent this natural-gas
  information clock.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | one latched `QM_IsNewBar()` call on the M30 host chart |

Broker timestamps are converted to New York time with `QM_BrokerToUTC` and
the framework U.S.-DST rule.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 6-18; card planning prior 8 |
| Typical hold time | under 4.5 hours, always same New York session |
| Expected drawdown profile | episodic and tail-heavy around gas releases |
| Regime preference | large release impulse followed by immediate rejection |
| Win rate target | unknown; no source performance claim |

Only standard Thursday releases are eligible. Holiday-shifted reports are
skipped because the EA has no external schedule feed.

---

## 6. Source Citation

- **Source ID:** `EIA-XNG-STORAGE-AFTERSHOCK-2026`
- **Source type:** official U.S. government energy report and schedule
- **Pointer:** `strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/source.md`
- **R1-R4 verdict (Q00):** all PASS; see
  `strategy-seeds/cards/approved/QM5_20128_xng-stor-fade_card.md`

The U.S. Energy Information Administration establishes the WNGSR event and
standard Thursday 10:30 a.m. eastern-time release. The failed-break fade,
thresholds, stop, target, and lifecycle are QM hypotheses for Q02
falsification.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Not authorized by this build |
| Full live (post-Q13 PASS) | RISK_PERCENT | Not authorized by this build |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). This build creates no live setfile and grants
no live, deploy, or portfolio authorization.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-25 | Initial build from approved card | Q01 evidence recorded separately |
