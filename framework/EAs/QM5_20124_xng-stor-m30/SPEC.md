# QM5_20124_xng-stor-m30 — Strategy Spec

**EA ID:** QM5_20124
**Slug:** `xng-stor-m30`
**Source:** `EIA-XNG-STORAGE-AFTERSHOCK-2026` (see `strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-25

---

## 1. Strategy Logic

On standard Thursdays, the EA waits until the EIA natural-gas storage
release's 10:30-11:00 New York M30 bar has closed. It enters long when that
bar is bullish, its range is at least 0.75 times ATR(20), its body is at least
half of its range, and its close is above the high of the prior two M30 bars.
It enters short under the mirrored bearish conditions below the prior range.

The first 11:00 New York decision consumes the date even when a later gate
rejects the order. An entry carries a 2.0 times ATR(20) broker stop and no
profit target. The EA closes on the first tick at or after 15:55 New York,
on a New York date change, or after eight hours, whichever comes first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_release_hhmm_ny` | 1030 | locked | Official standard WNGSR release time in New York |
| `strategy_entry_hhmm_ny` | 1100 | locked | First bar after the release bar is complete |
| `strategy_pre_release_bars` | 2 | locked | M30 bars forming the prior 60-minute range |
| `strategy_min_release_range_atr` | 0.75 | locked | Minimum release-bar range as an ATR multiple |
| `strategy_min_body_ratio` | 0.50 | locked | Minimum absolute body divided by range |
| `strategy_atr_period` | 20 | locked | Completed-bar ATR estimator |
| `strategy_atr_sl_mult` | 2.0 | locked | Initial broker stop distance |
| `strategy_entry_grace_minutes` | 15 | locked | Maximum late first-tick delay after 11:00 |
| `strategy_session_flat_hhmm_ny` | 1555 | locked | Same-session forced-flat time |
| `strategy_max_hold_hours` | 8 | locked | Final stale-position guard |
| `strategy_max_spread_points` | 2500 | locked | Maximum allowed entry spread |

Framework risk, news, stress, magic, and Friday-close inputs are documented in
`framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `XNGUSD.DWX` — the registered Darwinex natural-gas CFD carrier for the
  EIA natural-gas storage event.

**Explicitly NOT for:**

- `XTIUSD.DWX` — crude oil responds to the separate petroleum report and has
  different event mechanics.
- Metals, equity indices, and FX — they do not represent the source event's
  natural-gas exposure.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | one latched `QM_IsNewBar()` call on the M30 host chart |

Broker bar timestamps are converted to New York time with
`QM_BrokerToUTC`, `QM_UTCToBroker`, and the framework US-DST rule.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 8-30; card floor 10 |
| Typical hold time | less than five hours, always same New York session |
| Expected drawdown profile | episodic and tail-heavy around natural-gas release volatility |
| Regime preference | scheduled-event volatility expansion with directional continuation |
| Win rate target (qualitative) | medium; no source performance claim |

Only standard Thursday releases are eligible. Holiday-shifted reports are
intentionally skipped because the EA has no external schedule feed.

---

## 6. Source Citation

This card was mechanised from:

- **Source ID:** `EIA-XNG-STORAGE-AFTERSHOCK-2026`
- **Source type:** official U.S. government energy report and schedule
- **Pointer:** `strategy-seeds/sources/EIA-XNG-STORAGE-AFTERSHOCK-2026/source.md`
- **R1-R4 verdict (Q00):** all PASS; see
  `strategy-seeds/cards/approved/QM5_20124_xng-stor-m30_card.md`

The U.S. Energy Information Administration establishes the WNGSR event and
standard Thursday 10:30 a.m. eastern-time release. The impulse-continuation
hypothesis and all trading thresholds are QM rules subject to Q02
falsification.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). This build creates no live setfile and grants
no live or portfolio authorization.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-25 | Initial build from approved card | build task `6158129f-43b0-45e2-be2d-11e6654a37ad` |
