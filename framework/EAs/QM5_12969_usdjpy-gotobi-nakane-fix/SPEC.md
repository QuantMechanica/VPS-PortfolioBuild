# QM5_12969_usdjpy-gotobi-nakane-fix - Strategy Spec

**EA ID:** QM5_12969
**Slug:** `usdjpy-gotobi-nakane-fix`
**Source:** `CEO-ANOMALY-SLATE-2026-07-03` (see approved farm card)
**Author of this spec:** Codex
**Last revised:** 2026-07-17

---

## 1. Strategy Logic

The EA trades the USDJPY Tokyo fix flow anomaly on gotobi settlement days. A gotobi day is a Japanese business day whose nominal calendar date is 5, 10, 15, 20, 25, or 30, with weekend and January 1-3 bank-holiday dates rolled forward to the next Japanese business day. On those days it buys `USDJPY.DWX` during the first M30 bar at 02:00 JST and closes the position on the M30 bar containing the 09:55 JST Nakane fix.

There are no price-pattern or indicator signals. The only non-calendar risk control is a wide fixed-pip catastrophic stop required by the V5 fixed-risk sizing path; the intended strategy exit remains the same-day Nakane-fix time exit. The approved baseline is 120 pips. Under OWNER authorization dated 2026-07-17, `strategy_risk_stop_pips` is the sole Q03 axis with the ordered lattice `[60, 90, 120, 150, 180, 240, 360]`; Q03 selects the plateau median.

The position is same-day in JST but crosses the tested broker rollover boundary. It is therefore swap-bearing, not zero-swap. The 2026-07-17 FTMO recost observed 321 rollover units and +$465.61 swap across 213 long trades; the sign and magnitude are snapshot-dependent and must be refreshed for every release.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_jst_hhmm` | 200 | locked | Source-defined JST entry; not tunable. |
| `strategy_exit_jst_hhmm` | 955 | locked | Source-defined JST fix exit; not tunable. |
| `strategy_holiday_volume_proxy_enabled` | true | locked | Skip entry if the two most recent M30 bars have zero tick volume; remains enabled during Q03. |
| `strategy_risk_stop_pips` | 120 | 60, 90, 120, 150, 180, 240, 360 | Catastrophic-stop baseline and sole OWNER-authorized Q03 axis. |
| `strategy_max_spread_points` | 0 | locked | Guard disabled on `.DWX`; not a Q03 axis. |
| `PORTFOLIO_WEIGHT` | 1.0 | locked | Framework portfolio weight; explicitly locked during Q03. |

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - the peer-reviewed Tokyo/Nakane fix anomaly is defined specifically on USDJPY importer dollar demand.

**Explicitly NOT for:**
- Non-JPY FX pairs - the source anomaly is not a generic FX calendar effect.
- Non-FX `.DWX` symbols - the card targets Japanese corporate USD settlement flow, not indices, metals, or energy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | D1 calendar-period key only for restart-safe day validation |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Executed trades / year / symbol | 35.5 observed; planning value 36 |
| Frequency evidence | 213 trades over the bound 2017-2022 Q02 window |
| Nominal gotobi opportunities / year | Approximately 65-72 before calendar mapping and guards |
| Typical hold time | About 7.5 hours, from 02:00 JST to the 09:30 JST M30 fix bar |
| Rollover profile | Same-JST-day but broker-rollover crossing; swap-bearing |
| Expected drawdown profile | Intraday event-flow drawdown with occasional sharp adverse moves on intervention or policy days. |
| Regime preference | Calendar-session / fix-anomaly |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `CEO-ANOMALY-SLATE-2026-07-03`
**Source type:** paper
**Pointer:** Ito, T. and Yamada, M. (2017), "Puzzles in the Tokyo fixing in the forex market", Journal of the Japanese and International Economies 44; approved card at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_12969_usdjpy-gotobi-nakane-fix.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12969_usdjpy-gotobi-nakane-fix.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

Q03 is a native Model-4 plateau test. It does not waive cost qualification: after the
plateau median is selected, downstream evidence must be regenerated from that set and
reconciled against the current FTMO commission and swap snapshot. Existing Q05/Q06/Q10
sets belong to the earlier lineage until regenerated, even if Q03 selects 120 again.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-03 | Initial build from approved card | 53875e39-f386-4b32-b00f-2b5bdd15b5ed |
| v2 | 2026-07-17 | OWNER contract repair | 120-pip baseline; sole Q03 stop lattice; observed frequency; swap/rollover correction |
