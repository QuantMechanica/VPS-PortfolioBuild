# FX cointegration frontier hard CPU stop

Date: 2026-08-20

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; exact rank-21 Q04 successor remains
enqueued once; stopped at the explicit backtest CPU ceiling

## Outcome

No new FX Strategy Card or EA was created. The committed sign-aware
reconciliation in `a80493291` accounts for all 66 relationships from
`analyze_cross_asset_v3.py --include-negative-hedges`; another pair Card,
registry allocation, basket manifest, or EA would duplicate governed work.

The canonical farm database returned `PRAGMA quick_check=ok`. The preferred
anchors do not have an open Q02 setup defect:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Neither anchor is blocked at Q02 by ONINIT or NO_HISTORY.

## Existing-pair fallback

The highest-ranked frozen-scan relationship still awaiting its next economic
verdict is rank 21, `EURUSD.DWX` / `AUDJPY.DWX`, implemented once as
`QM5_20203_eurusd-audjpy`. Its logical Q02 result is PASS. Exactly one Q04
successor exists: work item `113ae6d1-33c0-42bc-b9b0-bf3a48ef3445` remains
pending, unclaimed, and at attempt zero.

The package remains unchanged. Its logical backtest setfile retains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; the EA has a
basket manifest and the approved Tier-A Chan Card snapshot. No enqueue,
requeue, priority mutation, or timestamp restamp was made because each would
duplicate or disturb the existing governed successor.

## Binding capacity stop

At `15:48Z`, five one-second whole-host CPU samples were `98.146297%`,
`97.274754%`, `93.460975%`, `98.929651%`, and `99.419647%`. Their
`97.446265%` average and `99.419647%` maximum exceeded the explicit `97%`
hard ceiling.

Six canonical work items were active across `T1` through `T6`: two Q04, two
Q05, and two Q07 runs. This is a fresh capacity snapshot 48 minutes after the
preceding FX-frontier observation. Per the mission stop condition, no Q02 or
Q04 dispatch, queue mutation, tester launch, terminal reservation, terminal
reconciliation, or terminal control followed.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260820T154843Z_board_advisor.json`.

## Safety

No portfolio admission, portfolio KPI, Q08 contribution, T_Live manifest,
T_Live terminal, AutoTrading state, Card, EA, EX5, setfile, basket manifest,
registry row, magic row, queue row, history archive, or containment state was
changed. Concurrent unrelated worktree changes were left unstaged and
untouched.
