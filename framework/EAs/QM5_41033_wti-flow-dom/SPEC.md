# QM5_41033_wti-flow-dom — Strategy Spec

**EA ID:** QM5_41033
**Slug:** `wti-flow-dom`
**Source:** `WILLIAMS-MOP-WTI-WFLOWDOM-2026`
**Author of this spec:** Codex
**Last revised:** 2026-08-17

Canonical card: `strategy-seeds/cards/approved/QM5_41033_wti-flow-dom_card.md`

## 1. Strategy Logic

On the first eligible tick of an exact broker Monday, reconstruct the exact
completed prior Monday-through-Friday `XTIUSD.DWX` D1 week plus its preceding
Friday anchor. Sum five close-to-open log returns as `overnight_flow` and five
open-to-close log returns as `session_flow`, then reconcile their total to the
completed Friday-to-Friday log return.

Trade only when the two component signs strictly oppose. Buy when the
reconciled total is positive and sell when it is negative, which follows the
component with greater absolute magnitude. Agreement, component equality,
zero, invalid data, failed reconciliation, a holiday-shifted week, late
attachment, or a consumed Monday remains flat. The current Monday bar is
excluded. Each date attempt is persisted before every fallible entry gate.

One slot-0 position carries a frozen `3.0 * ATR(20,D1)` hard stop, no target,
and the framework Friday close at broker hour 21. Later-week and eight-day
checks repair malformed or stale exposure.

## 2. Parameters

All values are locked for Q02; there is no optimization range.

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_grace_minutes` | 180 | locked | latest eligible Monday tick after executable session open |
| `strategy_atr_period` | 20 | locked | completed-bar D1 ATR period |
| `strategy_atr_sl_mult` | 3.0 | locked | frozen hard-stop distance |
| `strategy_max_hold_days` | 8 | locked | stale-position repair guard |
| `strategy_max_spread_points` | 1500 | locked | entry spread ceiling |
| `strategy_reconcile_tolerance` | 1e-10 | locked | telescoping identity tolerance |

## 3. Symbol Universe

**Designed for:** exact host and traded symbol `XTIUSD.DWX`, slot 0, magic
`410330000`.

**Explicitly NOT for:** any other crude grade, futures contract, cash symbol,
metal, index, synthetic basket, or standalone proxy.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(XTIUSD.DWX, PERIOD_D1)` |
| Formation | exact prior Monday–Friday plus preceding-Friday anchor |
| Decision clock | genuine broker Monday, within 180 normalized minutes |
| Normal lifecycle | framework Friday close at broker hour 21 |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Completed positions / year | approximately 15–30; Q02 floor is 5 |
| Typical hold time | Monday to Friday |
| Expected drawdown profile | sparse weekly fixed-risk losses bounded by frozen stops |
| Regime preference | disagreement whose larger information-time component determines the completed weekly move |
| Win-rate target | unknown; positive governed economics must be demonstrated |

This mechanic shares the strict sign-opposition eligibility state with
`QM5_41032_wti-flow-div`, but it is directionally different: it agrees with
that EA only when session flow dominates, takes the opposite side when
overnight flow dominates, and stays flat on an exact tie. It is disjoint from
the agreement-only `QM5_41029_wti-flow-agree`. No moving-average crossover,
fitted ratio, magnitude threshold, optimizer, scale-in, grid, martingale,
target, or trailing stop exists. Q09 alone may establish realized correlation
with the certified book.

## 6. Source Citation

**Source ID:** `WILLIAMS-MOP-WTI-WFLOWDOM-2026`

**Source type:** OWNER-approved Tier-A market-microstructure extraction plus
peer-reviewed WTI trend-carrier lineage.

**Pointer:** `strategy-seeds/sources/WILLIAMS-MOP-WTI-WFLOWDOM-2026/source.md`

**R1–R4 verdict:** all PASS; see the approved canonical card and
`decisions/2026-08-17_wti_weekly_flow_dominance_g0.md`.

The sources motivate a public/professional information-time decomposition and
WTI as the carrier. They do not supply this exact opposition gate, dominant
direction translation, CFD mapping, risk settings, profitability, or
portfolio decorrelation; those are disclosed QM falsification choices.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Q02 baseline | `RISK_FIXED` | USD 1,000 per position |
| Any live phase | not authorized | no preset or deployment artifact |

The sole setfile is a backtest preset locking `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Both news axes are OFF by the
source defaults and enforced no-trade contract. This build does not authorize
a manual tester run, AutoTrading, `T_Live`, portfolio admission, or edits to
any live or portfolio manifest.

## Q01 Evidence

- independent mechanic reference suite: 15 tests PASS
- strict compile: 0 errors, 0 warnings
- targeted V5 build check after final preset: 0 failures, 0 warnings
- card/schema, seven-section spec, magic, and fixed-risk set identity: PASS
- static P1 artifact validation: PASS
- compile log: `framework/build/compile/20260816_231159/QM5_41033_wti-flow-dom.compile.log`
- build report: `D:/QM/reports/framework/21/build_check_20260816_231231.json`
- P1 report: `D:/QM/reports/pipeline/QM5_41033/P1/P1_QM5_41033_result.json`

## Q02 Capacity Stop

The exact-path sample at `2026-08-16T23:13:27.1452304Z` found seven running
factory roots (`T1/T3/T5/T6/T7/T8/T9`) against the seven-terminal ceiling.
No queue dry run or enqueue command was invoked. Read-only target readback
returned zero work items. Evidence:
`docs/ops/evidence/2026-08-17_qm5_41033_wti_flowdom_q01_cpu_ceiling_stop.md`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | approved identity shell | G0 approved |
| v1-build | 2026-08-17 | deterministic implementation | Q01 PASS |
| v1-q02-hold | 2026-08-17 | binding paced-fleet capacity gate | Q02 not enqueued |
