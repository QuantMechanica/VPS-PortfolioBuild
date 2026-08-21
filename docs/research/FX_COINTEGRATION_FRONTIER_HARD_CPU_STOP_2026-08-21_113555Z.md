# FX cointegration frontier hard CPU stop

Date: 2026-08-21 UTC (`2026-08-21T11:35:55Z`)

Branch: `agents/board-advisor`

Status: the frozen 66-pair frontier is exhausted; the exact rank-21 Q04
successor remains enqueued once; stopped at the explicit backtest CPU ceiling

## Outcome

No new FX Strategy Card or EA was created. The durable sign-aware
reconciliation in `a80493291` covers all 66 relationships from
`analyze_cross_asset_v3.py --include-negative-hedges`; another Card, registry
allocation, basket manifest, or EA would duplicate governed work.

Fresh read-only farm queries reconfirm that the preferred anchors are not
blocked at Q02 by ONINIT or NO_HISTORY:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

## Existing-pair fallback

The highest-ranked frozen-scan relationship still awaiting its next economic
verdict is rank 21, `EURUSD.DWX` / `AUDJPY.DWX`, implemented once as
`QM5_20203_eurusd-audjpy`. Its logical Q02 result is PASS. Exactly one Q04
successor exists: work item `113ae6d1-33c0-42bc-b9b0-bf3a48ef3445`
remains pending, unclaimed, and at attempt zero.

The approved Card remains backed by the OWNER-ratified Tier-A Chan extraction
and the OWNER-requested frozen FX scan, with R1-R4 PASS. Fresh hashes confirm
that its EA, EX5, basket manifest, logical backtest setfile, approved Card, and
EA Card snapshot are unchanged. The setfile retains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No enqueue, requeue, priority
mutation, or timestamp restamp was made because each would duplicate or
disturb the governed successor.

## Binding capacity stop

The first five-sample CPU preflight was temporarily below the ceiling: samples
were 89.41%, 95.52%, 88.77%, 96.75%, and 84.96% (91.08% average, 96.75%
maximum). During the audit the paced fleet admitted more work. A second
five-sample observation was 94.68%, 99.41%, 95.23%, 97.18%, and 96.44%.
Its 99.41% maximum exceeded the explicit 97% hard ceiling.

The canonical database then contained six active work items and 2,238 pending
items. `QM5_20234_XAU_XAG_RSJ_D1` was active on T2 as a multi-symbol Q03
basket. The worker's farm-wide single-basket serialization rule therefore
independently blocked `QM5_20203`, even apart from the CPU ceiling.

The supported path-aware slot view observed five running factory terminals
(`T2`, `T4`, `T8`, `T9`, and `T10`). The database claim on `T7` had no matching
terminal process in that nearby snapshot. This discrepancy was recorded
without reconciliation or control because the CPU stop was already binding.

Compared with the preceding `10:38:05Z` evidence, active work fell from ten to
six, pending work rose from 2,231 to 2,238, the path-attributed terminal count
fell from nine to five, and the active phase mix changed. The selected
QM5_20203 Q04 row itself did not change state.

Per the mission stop condition, no Q02 or Q04 dispatch, queue mutation, tester
launch, terminal reservation, terminal reconciliation, or terminal control
followed.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_hard_cpu_stop_20260821T113555Z_board_advisor.json`.

## Safety

No portfolio admission, portfolio KPI, Q08 contribution, T_Live manifest,
AutoTrading state, Card, EA, EX5, setfile, basket manifest, registry row, magic
row, queue row, history archive, or containment state was changed. Concurrent
unrelated worktree changes were left unstaged and untouched.
