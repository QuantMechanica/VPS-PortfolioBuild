# QM5_12978 repaired-binary Q03 enqueue

**Date:** 2026-07-21  
**Branch:** `agents/board-advisor`  
**EA:** `QM5_12978_edgelab-gbpusd-usdcad-cointegration`  
**Logical basket:** `QM5_12978_GBPUSD_USDCAD_COINTEGRATION_D1`

## Outcome

The repaired GBPUSD/USDCAD cointegration basket was advanced from its
2026-07-14 Q02 PASS into a distinct Q03 task:

- repaired Q02 work item: `06539d34-2fef-4ac0-b11c-779de3d87a83`
- repaired Q02 parent task: `14abceb9-2d86-4621-a5b0-f6f839598498`
- repaired Q03 task: `b0227e1b-d214-44c9-85c6-bebede1bfaef`
- enqueue command: `python tools/strategy_farm/farmctl.py enqueue-backtest --review-task-id 14abceb9-2d86-4621-a5b0-f6f839598498 --phase Q03`

The older Q03 PASS and Q04 FAIL belong to the pre-repair binary. They remain
valid historical evidence but cannot classify the repaired implementation,
whose z-score now scores the newest closed spread against 60 strictly prior
closed spreads.

## Selection rationale

The two anchor baskets are not blocked at Q02: QM5_12532 passed Q02 and Q04
before failing Q05, and QM5_12533 passed Q02 before failing Q04. The all-sign
66-pair scan lineage is also exhausted: QM5_13119 USDJPY/EURAUD is documented
as the final strict row and is already built with a terminal Q04 FAIL.

QM5_12978 is therefore the highest-ranked existing strict-scan forex sleeve
with an unclassified repaired binary. Its approved card records the
GBPUSD/USDCAD row at DEV net Sharpe 0.2612, OOS net Sharpe 1.5477, 19 OOS
state changes, and a fixed beta of -1.140460285727. Those are research-screen
measurements only; Q03 and later gates remain the judge.

## Safety and capacity

`farmctl.py mt5-slots` reported no running T1-T10 factory terminal at enqueue
time. The only observed terminal processes were T_Live and an FTMO terminal;
neither was accessed or changed. No manual MT5 process was launched. No
AutoTrading, live manifest, portfolio admission, portfolio KPI, or Q08
contribution artifact was touched.

The Q03 enqueue created the phase task without immediately creating a new
work item. This is recorded explicitly so the paced dispatcher can perform
the canonical de-duplication/promotion step; no manual duplicate work-item row
was inserted.
