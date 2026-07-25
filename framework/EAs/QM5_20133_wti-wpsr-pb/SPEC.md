# QM5_20133_wti-wpsr-pb — Strategy Spec

**EA ID:** QM5_20133
**Slug:** `wti-wpsr-pb`
**Source:** `EIA-WTI-WPSR-INTRADAY-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

On standard Wednesdays, the EA loads the completed 09:30 and 10:00 New York
M30 bars as the pre-release range. The 10:30 release bar must have range at
least `0.75 * ATR(20)`, body/range at least `0.50`, and close at least
`0.05 * ATR(20)` beyond that prior range.

The completed 11:00 bar must move against the release impulse, retrace
`0.15-0.50` of the release range from its close, and still close outside the
pre-release range. At 11:30 the EA enters in the original release direction if
the executable-price gap from the pullback close is no more than
`0.25 * ATR(20)`.

The stop is beyond the adverse extreme of the release/pullback sequence by
`0.10 * ATR(20)`, and the target is `1.50R`. Remaining exposure closes at
15:55 New York, on a New York date change, or after six hours. The New York
date is consumed before all fallible gates. There is no retry, pending order,
trailing stop, or overnight hold.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_release_hhmm_ny` | 1030 | locked | Standard WPSR release-bar open |
| `strategy_pullback_hhmm_ny` | 1100 | locked | Completed counter-bar open |
| `strategy_entry_hhmm_ny` | 1130 | locked | Post-pullback decision |
| `strategy_pre_release_bars` | 2 | locked | Completed prior-hour M30 range |
| `strategy_atr_period` | 20 | locked | Completed M30 volatility estimator |
| `strategy_min_release_range_atr` | 0.75 | locked | Event impulse range floor |
| `strategy_min_release_body_ratio` | 0.50 | locked | Event impulse body floor |
| `strategy_break_buffer_atr` | 0.05 | locked | Close beyond the prior range |
| `strategy_min_retrace_fraction` | 0.15 | locked | Minimum pullback depth |
| `strategy_max_retrace_fraction` | 0.50 | locked | Maximum non-failure pullback |
| `strategy_max_entry_gap_atr` | 0.25 | locked | Executable gap ceiling |
| `strategy_stop_buffer_atr` | 0.10 | locked | Stop beyond sequence extreme |
| `strategy_min_stop_atr` | 0.25 | locked | Minimum stop distance |
| `strategy_max_stop_atr` | 3.00 | locked | Maximum stop distance |
| `strategy_target_rr` | 1.50 | locked | Fixed reward/risk target |
| `strategy_entry_grace_minutes` | 15 | locked | Late-attach tolerance |
| `strategy_session_flat_hhmm_ny` | 1555 | locked | Same-session forced flat |
| `strategy_max_hold_hours` | 6 | locked | Final stale-position guard |
| `strategy_max_spread_points` | 1000 | locked | Maximum entry spread |

Framework risk, news, stress, magic, and Friday-close inputs are documented in
`framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — registered Darwinex WTI CFD carrier for the EIA WPSR event.

**Explicitly NOT for:**

- `XNGUSD.DWX` — natural gas responds to the WNGSR and has separate builds.
- Metals, equity indices, or FX — they do not represent this petroleum event.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | one `QM_IsNewBar()` evaluation at the 11:30 decision bar |

Broker timestamps are converted to New York time with `QM_BrokerToUTC` and
the framework U.S.-DST rule.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 8-20; card planning prior 12 |
| Typical hold time | under 4.5 hours, always same New York session |
| Expected drawdown profile | episodic and tail-heavy around petroleum releases |
| Regime preference | directional information impulse with shallow non-failing pullback |
| Win rate target | unknown; no source performance claim |

Only standard Wednesday releases are eligible. Holiday-shifted reports are
skipped because the EA has no external schedule feed.

---

## 6. Source Citation

- **Source ID:** `EIA-WTI-WPSR-INTRADAY-2026`
- **Source type:** official U.S. government energy report and schedule
- **Pointer:**
  `strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md`
- **R1-R4 verdict (Q00):** R1 tier A and R2-R4 PASS; see
  `strategy-seeds/cards/approved/QM5_20133_wti-wpsr-pb_card.md`

The U.S. Energy Information Administration establishes the WPSR event and
official schedule lineage. The impulse, pullback, thresholds, stop, target,
and lifecycle are QM hypotheses for Q02 falsification.

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
| v1 | 2026-07-25 | Initial build from approved card | build task `697cad68-6a97-4f33-9cf6-3e24fb54d437`; Q02 work item `c8f77304-f43b-4d5b-bd00-a4b9afbaa482` |
