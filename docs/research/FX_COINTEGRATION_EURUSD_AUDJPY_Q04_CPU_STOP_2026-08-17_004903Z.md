# FX cointegration EURUSD/AUDJPY — Q04 reconciliation and CPU stop

Date: 2026-08-17 Europe/Berlin (`2026-08-17T00:49:03Z`)

Branch: `agents/board-advisor`

Status: the frozen 66-pair frontier is fully mechanized; the highest-ranked
exact successor still awaiting an economic verdict is already pending at Q04,
and the explicit backtest CPU ceiling is binding

## Outcome

No duplicate Strategy Card, EA, manifest, setfile, registry row, or queue row
was created. The committed sign-aware reconciliation of the frozen FX scan
accounts for all 66 relationships, so there is no unbuilt pair left to
mechanize. The two preferred anchors do not need Q02 repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.
- The canonical database has no open work item for either anchor.

The non-duplicate fallback is the existing rank-21 `EURUSD.DWX` /
`AUDJPY.DWX` D1 package, `QM5_20203_EURUSD_AUDJPY_COINTEGRATION_D1`.
It is an OWNER-approved, Tier-A-Chan-backed, structural fixed-beta basket with
no ML, banned indicator, online refit, grid, martingale, or rescue filter. Its
canonical setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## Canonical lineage repair

The build-local Card still said `Q02_PENDING`, but the canonical farm has
already resolved that phase. Initial work item
`803cfaaa-d1e4-4d5c-a599-4d33b536ea9f` exhausted its bounded cold-cache
retries with `NO_HISTORY`; append-only replacement
`85be20b6-d19d-46a2-9084-8786d9837399` then completed Q02 with PASS on
2026-08-05. Its Model-4 run produced 122 trades, no ONINIT failure, and stable
EX5 and fixed-risk setfile bindings.

Q02 is a capability gate, not a profitability waiver. The bound run was
adverse: PF `0.83`, net profit `-2189.95`, and drawdown `6775.59` (`6.55%`).
The Card now records those facts and advances only its pipeline metadata to
`Q04_PENDING`; no strategy rule, parameter, risk setting, or artifact changed.

Canonical automation already promoted that passing lineage exactly once to
Q04 work item `113ae6d1-33c0-42bc-b9b0-bf3a48ef3445`. A read-only database
check found it pending and found no duplicate Q04 row. Enqueueing, requeueing,
or restamping it would be duplicate work.

## Binding CPU stop

Five whole-machine CPU samples were `99.90%`, `99.81%`, `99.02%`, `95.31%`,
and `99.80%` (average `98.77%`, maximum `99.90%`). Both the average and the
maximum exceeded the explicit `97%` hard ceiling. Six factory terminals were
already active on `T2`, `T3`, `T4`, `T7`, `T9`, and `T10`, bound to six
canonical active work items across Q02, Q05, Q06, and Q08.

Per the mission stop condition, no dispatch tick, backtest, enqueue, requeue,
priority/timestamp mutation, reservation, tester launch, or terminal action
was attempted. The separately excluded live surface was not inspected or
controlled.

Machine-readable evidence is
`artifacts/fx_cointegration_eurusd_audjpy_q04_cpu_stop_20260817T004903Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- No T_Live manifest or terminal, AutoTrading state, or live artifact changed.
- No EA, EX5, setfile, basket manifest, registry, magic row, or runtime queue
  row changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
