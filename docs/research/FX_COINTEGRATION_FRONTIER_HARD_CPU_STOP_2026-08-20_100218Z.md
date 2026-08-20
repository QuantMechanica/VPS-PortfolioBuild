# FX cointegration frontier hard CPU stop

Date: 2026-08-20

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; exact rank-21 Q04 successor already
exists once; stopped at the explicit backtest CPU ceiling

## Outcome

No new FX Strategy Card or EA was created. The checked-in sign-aware
reconciliation in commit `a80493291` covers all 66 relationships from
`analyze_cross_asset_v3.py --include-negative-hedges`. Creating another pair
Card, registry allocation, basket manifest, or EA would duplicate governed
work.

The latest governed anchor evidence (`bc02694a7`) records no Q02 setup defect:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.
- Neither anchor has an open Q02 ONINIT or NO_HISTORY blocker.

## Existing-pair fallback

The highest-ranked exact frozen-scan relationship still awaiting its next
economic verdict is rank 21, `EURUSD.DWX` / `AUDJPY.DWX`, implemented once as
`QM5_20203_eurusd-audjpy`. Its reputable-source, OWNER-approved Card is
structural, deterministic, non-ML, and low-frequency D1. Its manifest declares
EURUSD/AUDJPY as traded legs and AUDUSD/USDJPY as conversion-only histories.
The logical backtest setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

At the latest governed queue observation in `bc02694a7`, exact logical Q02 work
item `85be20b6-d19d-46a2-9084-8786d9837399` was DONE/PASS and its single exact
Q04 successor `113ae6d1-33c0-42bc-b9b0-bf3a48ef3445` was PENDING, unclaimed,
at attempt zero. This run did not query or mutate the live queue after the CPU
ceiling became binding, and it performed no duplicate enqueue, requeue,
priority change, or timestamp restamp.

## Binding capacity stop

At `10:02Z`, five whole-host CPU samples taken two seconds apart were `100%`,
`100%`, `100%`, `100%`, and `100%`. The average and maximum were both `100%`,
above the mission's explicit `97%` hard ceiling.

Per the CPU-ceiling stop condition, no Q02/Q04 dispatch, queue mutation, tester
launch, terminal reservation, terminal reconciliation, or terminal control
followed. This is a new capacity observation about 76 minutes after the prior
`08:46Z` binding observation, not a duplicate queue work item. Machine-readable
evidence is
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260820T100218Z_board_advisor.json`.

## Safety

No portfolio admission, portfolio KPI, Q08 contribution, T_Live manifest,
T_Live terminal, AutoTrading state, Card, EA, EX5, setfile, basket manifest,
registry row, magic row, queue row, history archive, or containment state was
changed. Concurrent unrelated worktree changes were left unstaged and
untouched.
