# QM5_20155 WTI Tuesday Trend — Build And Q02 Evidence

**Date:** 2026-07-25
**Branch:** `agents/board-advisor`
**EA:** `QM5_20155_wti-tue-trend`
**Scope:** source-backed card, V5 build, and one paced Q02 enqueue

## Edge And Duplicate Gate

The new edge sells only a genuine Tuesday `XTIUSD.DWX` D1 session when the
instrument's completed 252-D1 log return is negative. It combines the
peer-reviewed negative WTI Tuesday lineage of Gorska and Krawiec (2015) with
the completed own-return sign from Moskowitz, Ooi, and Pedersen (2012).

The deterministic pre-allocation command returned `VERDICT: CLEAN` for slug
`wti-tue-trend`, strategy ID
`GORSKA-MOP-WTI-TUETREND-2026_S01`, and mechanic "Tuesday WTI short only when
completed 252-D1 return is negative". Manual semantic review distinguishes it
from unconditional `QM5_12610_wti-tue-fade`, year-round WTI trend, the
Monday/Wednesday/Thursday/Friday weekday-trend siblings, and
`QM5_12567_cum-rsi2-commodity`.

## Governed Build Evidence

- Source packet:
  `strategy-seeds/sources/GORSKA-MOP-WTI-TUETREND-2026/source.md`
- Approved card:
  `strategy-seeds/cards/approved/QM5_20155_wti-tue-trend_card.md`
- Registry allocation: EA `20155`, slot 0, `XTIUSD.DWX`, magic `201550000`
- Card schema/ML lint: PASS; no missing sections and no ML hits
- Strict compile: PASS, 0 errors, 0 warnings
- Compile log:
  `C:/QM/repo/framework/build/compile/20260725_140829/QM5_20155_wti-tue-trend.compile.log`
- Targeted build check: PASS, 0 failures, 0 warnings
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260725_140841.json`
- Backtest setfile locks `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

No manual smoke test or backtest was started. The build result used
`deferred_p2_smoke`, delegating test execution to the paced fleet.

## Paced Q02 Handoff

The read-only capacity scan at `2026-07-25T14:00:44Z` found six active factory
tester terminals (`T1`, `T2`, `T3`, `T4`, `T9`, `T10`), below the documented
seven-terminal ceiling. `T_Live` and the FTMO terminal were separately
identified as non-pipeline processes and were not touched.

Governed build task `6ed5af33-da19-45d0-a7ce-44adc0c5c608` completed and
auto-enqueued exactly one priority-track work item:

- Work item: `5d2b088b-bf75-4703-9a07-74158fbe4224`
- Phase: `Q02`
- Symbol/timeframe: `XTIUSD.DWX` / `D1`
- State at handoff: `pending`
- Cohort size: 1

No portfolio gate, deploy or T_Live manifest, live setfile, live terminal,
AutoTrading state, or `T_Live` file was changed.
