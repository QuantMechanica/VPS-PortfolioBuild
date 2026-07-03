# QM5_12969_usdjpy-gotobi-nakane-fix - Strategy Spec

**EA ID:** QM5_12969
**Slug:** `usdjpy-gotobi-nakane-fix`
**Source:** `CEO-ANOMALY-SLATE-2026-07-03` (see approved farm card)
**Author of this spec:** Codex
**Last revised:** 2026-07-03

---

## 1. Strategy Logic

The EA trades the USDJPY Tokyo fix flow anomaly on gotobi settlement days. A gotobi day is a Japanese business day whose nominal calendar date is 5, 10, 15, 20, 25, or 30, with weekend and January 1-3 bank-holiday dates rolled forward to the next Japanese business day. On those days it buys `USDJPY.DWX` during the first M30 bar at 02:00 JST and closes the position on the M30 bar containing the 09:55 JST Nakane fix.

There are no price-pattern or indicator signals. The only non-calendar risk control is a wide fixed-pip catastrophic stop required by the V5 fixed-risk sizing path; the intended strategy exit remains the same-day Nakane-fix time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_jst_hhmm` | 200 | 0000-2359 | JST time for the first eligible entry bar. |
| `strategy_exit_jst_hhmm` | 955 | 0000-2359 | JST fix time; the EA exits on the M30 bar containing this time. |
| `strategy_holiday_volume_proxy_enabled` | true | true/false | Skip entry if the two most recent M30 bars have zero tick volume. |
| `strategy_risk_stop_pips` | 120 | >0 | Catastrophic stop distance used for V5 fixed-risk sizing. |
| `strategy_max_spread_points` | 0 | >=0 | Maximum spread in points; 0 disables the guard so .DWX zero spread does not block. |

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
| Trades / year / symbol | 68 |
| Typical hold time | About 7.5 hours, from 02:00 JST to the 09:30 JST M30 fix bar |
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

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-03 | Initial build from approved card | 53875e39-f386-4b32-b00f-2b5bdd15b5ed |
