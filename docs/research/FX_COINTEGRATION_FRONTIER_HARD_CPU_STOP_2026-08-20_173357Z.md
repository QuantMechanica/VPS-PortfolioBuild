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
successor exists: work item `113ae6d1-33c0-42bc-b9b0-bf3a48ef3445`
remains pending, unclaimed, and at attempt zero.

The package remains unchanged. Its logical backtest setfile retains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; the EA has a
basket manifest and the approved Tier-A Chan Card snapshot. No enqueue,
requeue, priority mutation, or timestamp restamp was made because each would
duplicate or disturb the existing governed successor.

## Binding capacity stop

From `17:33:51Z` through `17:33:57Z`, five one-second whole-host CPU samples
were `100.0%`, `99.820293%`, `99.903271%`, `99.904514%`, and `100.0%`.
Their `99.925616%` average and `100.0%` maximum exceeded the explicit `97%`
hard ceiling.

Ten canonical work items were active: every factory terminal from T1 through
T10 owned a Q04, Q06, or Q07 run. `T_Live` and the unrelated FTMO terminal
were observed only to exclude them and were not controlled. This is a fresh
capacity snapshot 60.95 minutes after the preceding FX-frontier observation;
the active set increased from eight to ten and now occupies the entire factory
fleet. Per the mission stop condition, no Q02 or Q04 dispatch, queue mutation,
tester launch, terminal reservation, terminal reconciliation, or terminal
control followed.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260820T173357Z_board_advisor.json`.

## Safety

No portfolio admission, portfolio KPI, Q08 contribution, T_Live manifest,
T_Live terminal, AutoTrading state, Card, EA, EX5, setfile, basket manifest,
registry row, magic row, queue row, history archive, or containment state was
changed. Concurrent unrelated worktree changes were left unstaged and
untouched.
