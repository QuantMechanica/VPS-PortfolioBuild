# QM5_41032_wti-flow-div — Strategy Spec

**EA ID:** QM5_41032
**Slug:** `wti-flow-div`
**Source:** `WILLIAMS-MOP-WTI-WFLOWDIV-2026`
**Author of this spec:** Codex
**Last revised:** 2026-08-17

Canonical card: `strategy-seeds/cards/approved/QM5_41032_wti-flow-div_card.md`

## 1. Strategy Logic

On the first eligible tick of an exact broker Monday, reconstruct the exact
completed prior Monday-through-Friday `XTIUSD.DWX` D1 week plus its preceding
Friday anchor. For the five completed sessions, sum close-to-open log returns
as `overnight_flow` and open-to-close log returns as `session_flow`.

Buy only when `session_flow > 0` and `overnight_flow < 0`. Sell only when
`session_flow < 0` and `overnight_flow > 0`. Agreement, exact zero, invalid
data, a holiday-shifted week, late attachment, or a consumed Monday remains
flat. The current Monday bar is excluded. Each date attempt is persisted
before every fallible entry gate, so there is no same-week retry.

One slot-0 position carries a frozen `3.0 * ATR(20,D1)` hard stop, no target,
and the framework Friday close at broker hour 21. Later-week and eight-day
checks repair malformed or stale exposure.

## 2. Parameters

All values are locked for Q02; there is no optimization range.

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_grace_minutes` | 180 | locked | latest eligible Monday tick after normalized D1 open |
| `strategy_atr_period` | 20 | locked | completed-bar D1 ATR period |
| `strategy_atr_sl_mult` | 3.0 | locked | frozen hard-stop distance |
| `strategy_max_hold_days` | 8 | locked | stale-position repair guard |
| `strategy_max_spread_points` | 1500 | locked | entry spread ceiling |

## 3. Symbol Universe

**Designed for:** exact host and traded symbol `XTIUSD.DWX`, slot 0, magic
`410320000`.

**Explicitly NOT for:** any other crude grade, continuous futures contract,
cash symbol, synthetic basket, metal, index, or standalone proxy.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(XTIUSD.DWX, PERIOD_D1)` |
| Formation | exact prior Monday–Friday plus preceding-Friday anchor |
| Decision clock | genuine Monday, within 180 normalized minutes |
| Normal lifecycle | framework Friday close at broker hour 21 |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Completed positions / year | approximately 15–30; Q02 floor is 5 |
| Typical hold time | Monday to Friday |
| Expected drawdown profile | sparse weekly fixed-risk losses bounded by frozen stops |
| Regime preference | disagreement between overnight repricing and completed session flow |
| Win-rate target | unknown; positive governed economics must be demonstrated |

The mechanic deliberately occupies only the sign-opposition states excluded
by `QM5_41029_wti-flow-agree`, and follows session flow rather than reversing
it. It has no moving-average crossover, fitted ratio, magnitude threshold,
optimizer, scale-in, grid, martingale, target, or trailing stop. Q09 alone may
establish realized correlation with the certified book.

## 6. Source Citation

**Source ID:** `WILLIAMS-MOP-WTI-WFLOWDIV-2026`

**Source type:** OWNER-approved Tier-A market-microstructure extraction plus
peer-reviewed WTI trend carrier lineage.

**Pointer:** `strategy-seeds/sources/WILLIAMS-MOP-WTI-WFLOWDIV-2026/source.md`

**R1–R4 verdict:** all PASS; see the approved canonical card and
`decisions/2026-08-16_wti_weekly_flow_divergence_g0.md`.

The sources motivate a public/professional information-time decomposition and
WTI as the carrier. They do not supply this exact opposition rule, direction,
CFD mapping, risk settings, profitability, or portfolio decorrelation; those
are disclosed QM falsification choices.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Q02 baseline | `RISK_FIXED` | USD 1,000 per position |
| Any live phase | not authorized | no preset or deployment artifact |

The sole backtest setfile locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes are OFF. This build does not authorize a
manual tester run, AutoTrading, `T_Live`, portfolio admission, or edits to any
live or portfolio manifest.

## Q01 Evidence

- independent mechanic reference suite: 12 tests PASS
- strict compile: 0 errors, 0 warnings
- targeted V5 build check: 0 failures, 0 warnings
- card/schema, seven-section spec, magic, and fixed-risk set identity: PASS
- static P1 artifact validation: PASS
- compile log: `framework/build/compile/20260816_220539/QM5_41032_wti-flow-div.compile.log`
- build report: `D:/QM/reports/framework/21/build_check_20260816_220604.json`
- P1 report: `D:/QM/reports/pipeline/QM5_41032/P1/P1_QM5_41032_result.json`

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-16 | approved identity shell | G0 approved |
| v1-build | 2026-08-17 | deterministic implementation | Q01 PASS |
