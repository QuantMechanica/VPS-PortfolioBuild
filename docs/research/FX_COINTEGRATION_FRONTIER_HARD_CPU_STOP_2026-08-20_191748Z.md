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

The approved Card, EA, EX5, basket manifest, and logical backtest setfile retain
the hashes recorded in the preceding handoff. The setfile remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No enqueue,
requeue, priority mutation, or timestamp restamp was made because each would
duplicate or disturb the existing governed successor.

## Binding capacity stop

The five one-second whole-host CPU samples ending at `19:15:46Z` were
`98.830009%`, `96.227714%`, `99.610007%`, `99.121180%`, and `99.220784%`.
Their `98.601939%` average and `99.610007%` maximum both exceeded the explicit
`97%` ceiling.

Seven canonical work items were active on T2, T3, T4, T6, T8, T9, and T10.
This is a fresh observation 44.80 minutes after the preceding FX-frontier
evidence: the active set increased from six to seven and the hard ceiling
remained binding. A path-anchored terminal-process snapshot observed T2, T3,
T4, T6, T8, and T9. `T_Live` and the unrelated FTMO terminal were observed
only to exclude them and were not controlled.

Per the mission stop condition, no Q02 or Q04 dispatch, queue mutation, tester
launch, terminal reservation, terminal reconciliation, or terminal control
followed.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260820T191748Z_board_advisor.json`.

## Safety

No portfolio admission, portfolio KPI, Q08 contribution, T_Live manifest,
T_Live terminal, AutoTrading state, Card, EA, EX5, setfile, basket manifest,
registry row, magic row, queue row, history archive, or containment state was
changed. Concurrent unrelated worktree changes were left unstaged and
untouched.
