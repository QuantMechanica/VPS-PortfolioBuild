# QM5_20132_xng-stor-orb — Strategy Spec

**EA ID:** QM5_20132
**Slug:** `xng-stor-orb`
**Source:** `EIA-XNG-STORAGE-AFTERSHOCK-2026` (see `strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

On standard Thursdays, the EA freezes the completed 09:30 and 10:00 New York
M30 bars. Their combined range must be between `0.25 * ATR(20)` and
`1.25 * ATR(20)`.

From 10:30 inclusive to 11:00 exclusive, the first executable ask above range
high plus `0.10 * ATR(20)` signals long, while the first executable bid below
range low minus `0.10 * ATR(20)` signals short. The date is consumed before
fallible entry gates. Simultaneous triggers and overshoot beyond
`0.30 * ATR(20)` remain flat.

The stop is beyond the opposite side of the frozen range by
`0.10 * ATR(20)`, and the target is `1.50R`. Remaining exposure closes at
15:55 New York, on a New York date change, or after eight hours. There is no
retry, reversal, pending order, trailing stop, or overnight hold.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_release_hhmm_ny` | 1030 | locked | Standard WNGSR release-window open |
| `strategy_entry_end_hhmm_ny` | 1100 | locked | Exclusive live breakout-window end |
| `strategy_pre_release_bars` | 2 | locked | M30 bars forming the completed prior-hour range |
| `strategy_atr_period` | 20 | locked | Completed M30 volatility estimator |
| `strategy_min_range_atr` | 0.25 | locked | Minimum usable prior-range width |
| `strategy_max_range_atr` | 1.25 | locked | Maximum usable prior-range width |
| `strategy_break_buffer_atr` | 0.10 | locked | Trigger and structural-stop buffer |
| `strategy_max_overshoot_atr` | 0.30 | locked | Maximum executable trigger overshoot |
| `strategy_target_rr` | 1.50 | locked | Fixed reward/risk target |
| `strategy_session_flat_hhmm_ny` | 1555 | locked | Same-session forced-flat time |
| `strategy_max_hold_hours` | 8 | locked | Final stale-position guard |
| `strategy_max_spread_points` | 2500 | locked | Maximum entry spread |

Framework risk, news, stress, magic, and Friday-close inputs are documented in
`framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `XNGUSD.DWX` — registered Darwinex natural-gas CFD carrier for the EIA
  storage-release event.

**Explicitly NOT for:**

- `XTIUSD.DWX` — crude oil responds to a different EIA report and clock.
- Metals, equity indices, or FX — they do not represent this natural-gas
  information event.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | one latched `QM_IsNewBar()` call arms the release window; the cached first-escape test is O(1) per tick |

Broker timestamps are converted to New York time with `QM_BrokerToUTC` and
the framework U.S.-DST rule.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 10-30; card planning prior 20 |
| Typical hold time | under 5.5 hours, always same New York session |
| Expected drawdown profile | episodic and tail-heavy around gas releases |
| Regime preference | scheduled-event volatility expansion from a bounded prior range |
| Win rate target | unknown; no source performance claim |

Only standard Thursday releases are eligible. Holiday-shifted reports are
skipped because the EA has no external schedule feed.

---

## 6. Source Citation

- **Source ID:** `EIA-XNG-STORAGE-AFTERSHOCK-2026`
- **Source type:** official U.S. government energy report and schedule
- **Pointer:** `strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/source.md`
- **R1-R4 verdict (Q00):** R1 tier A and R2-R4 PASS; see
  `strategy-seeds/cards/approved/QM5_20132_xng-stor-orb_card.md`

The U.S. Energy Information Administration establishes the WNGSR event and
standard Thursday 10:30 a.m. eastern-time release. The range breakout,
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
| v1 | 2026-07-25 | Initial build from approved card | build task `afc4bd12-c23d-4003-87d2-2a8184876944` |
