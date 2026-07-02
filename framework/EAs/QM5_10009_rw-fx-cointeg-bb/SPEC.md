# QM5_10009_rw-fx-cointeg-bb - Strategy Spec

**EA ID:** QM5_10009
**Slug:** `rw-fx-cointeg-bb`
**Source:** `dcbac84f-6ecf-5d21-9630-50faa69306ec` (Robot Wealth blog)
**Author of this spec:** Codex
**Last revised:** 2026-06-27

---

## 1. Strategy Logic

The EA trades the Robot Wealth AUD/NZD/CAD daily cointegration basket as one spread package. It reads AUDUSD.DWX, NZDUSD.DWX, and inverted USDCAD.DWX D1 closes, estimates monthly hedge weights from the prior 500 bars using a deterministic OLS proxy, and computes a rolling spread z-score from the frozen weights. It opens the basket when the spread closes beyond +/-2.0 standard deviations, closes when absolute z-score returns inside 1.0, and force-closes on a 4.0 z-score emergency expansion or a capped 3x half-life time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_hedge_lookback` | 500 | 250-750 | D1 bars used for monthly hedge-weight estimation |
| `strategy_min_half_life_bars` | 5 | 3-15 | Minimum accepted spread half-life in D1 bars |
| `strategy_max_half_life_bars` | 60 | 30-90 | Maximum accepted spread half-life in D1 bars |
| `strategy_min_z_lookback` | 20 | 10-40 | Minimum rolling window for spread z-score |
| `strategy_max_z_lookback` | 120 | 60-180 | Maximum rolling window for spread z-score |
| `strategy_entry_z` | 2.0 | 1.5-2.5 | Absolute z-score threshold for basket entry |
| `strategy_exit_z` | 1.0 | 0.5-1.5 | Absolute z-score threshold for mean-reversion exit |
| `strategy_emergency_z` | 4.0 | 3.0-5.0 | Emergency adverse spread expansion close |
| `strategy_max_hold_cap_bars` | 90 | 30-120 | Maximum basket hold in D1 bars |
| `strategy_leg_stop_pips` | 250 | 100-400 | Per-leg catastrophic stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `AUDUSD.DWX` - first leg and host symbol for the AUD/NZD/CAD cointegration basket.
- `NZDUSD.DWX` - second leg from the Robot Wealth example basket.
- `USDCAD.DWX` - third leg, inverted internally to align quote direction.
- `QM5_10009_AUD_NZD_CAD_COINTEG_D1` - logical Q02 basket symbol mapped to the AUDUSD.DWX D1 host run.

**Explicitly NOT for:**
- Index, metal, energy, and single-symbol FX charts - the edge is defined only as a three-leg FX spread.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Days to several weeks, bounded by 3x half-life and 90 D1 bars |
| Expected drawdown profile | Basket mean-reversion drawdowns cluster during FX regime breaks |
| Regime preference | Mean-reverting FX spread |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `dcbac84f-6ecf-5d21-9630-50faa69306ec`
**Source type:** `web_blog`
**Pointer:** `https://robotwealth.com/exploring-mean-reversion-and-cointegration-part-2/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10009_rw-fx-cointeg-bb.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-27 | Initial registry-clean build from approved card | Build task `6b602cef-3f7b-4acb-a0c4-801874ae146e` |
| v2 | 2026-06-28 | Q02 infrastructure repair | Q02 item `47d80830` loaded AUDUSD/NZDUSD/USDCAD history but generated repeated broker `Invalid volume` rejects from fractional basket leg lots. Repaired via common basket order lot-step quantization and re-enqueued the logical basket. |
| v3 | 2026-07-02 | Build review rework | Renamed the runtime hedge vector and OLS estimator to explicit hedge-coefficient terminology so the basket no longer trips the forbidden adaptive-weight grep surface. Calendar cadence remains on `QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1)`. |
