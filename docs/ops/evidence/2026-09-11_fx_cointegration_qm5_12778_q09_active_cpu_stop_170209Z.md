# FX cointegration fallback — QM5_12778 Q09 active / hard CPU stop

Recorded: 2026-09-11T17:02:09Z (19:02 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `1a5f7bacb7d8d98e89f15a07812f3945792f5601`

## Outcome

The frozen sign-aware 66-pair FX cointegration frontier remains fully
mechanized, so no duplicate Card, EA, registry identity, basket manifest, or
Q02 row was created. The two preferred anchors are already beyond Q02 and do
not have an ONINIT or NO_HISTORY repair to perform:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The selected existing low-frequency market-neutral continuation is
`QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`. Its unique priority-tracked Q09
work item `1ba8f6c7-7725-47c5-b0e5-6a4736c4ad44` advanced from pending to
active on T8 at 2026-09-11T16:52:44Z. The row is attempt zero, has no verdict
yet, and is bound to the checked-in basket manifest. The governed worker
recorded `PASS_PRIVATIZED` for all four required custom-history symbols and
verified the staged EX5 before launch.

No second Q09 row was inserted. The older existing-forex fallback
`QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` also retains its one pending,
unclaimed, attempt-zero, priority-tracked logical Q02 row
`547c4fd3-f3fd-4c59-b9dc-654e96521251`; it was not duplicated or mutated.

## Identity and PACER guard

The active Q09 payload and repository artifacts agree on the compiled binary:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `132a501d94685f013cc62a8b3c2de111d0a8b1e616a8656d2c61b061a754c146` |
| EX5 | `2a105cfbb364142c96c552136bb450162c142845665ce3366d0c045248c17a01` |
| Basket manifest | `0ce25d17ebe7c3664e4acdb6c1d302b28b1f40710301189cc633e44f25854d57` |
| Logical D1 backtest setfile | `0e7949276927c8c5355c413c631e7b67f684e757892de59fa2cff5521836c8e9` |

The backtest setfile seals `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No MQ5 was generated or edited and no compile was
enqueued. A read-only PACER audit was nevertheless run against the absolute
source path:

```powershell
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_12778_edgelab-audusd-eurjpy-cointegration/QM5_12778_edgelab-audusd-eurjpy-cointegration.mq5"
```

It exited zero with `ok=true`, `hit_count=0`, and no
`EA_FRAMEWORK_INPUT_PINNED` findings.

## Binding CPU stop

At the exact database observation there were three active and 7,647 pending
work items. The paced launch setting was `launch_gate_max=1`, while the
path-aware factory snapshot already showed T7, T8, and T9 running testers.

Five one-second whole-host CPU samples were `98.93%`, `95.59%`, `97.60%`,
`99.12%`, and `99.80%` (average `98.21%`, maximum `99.80%`). Both the average
and maximum crossed the binding 97% ceiling. Per the explicit mission stop,
no queue mutation, worker claim, dispatch tick, tester launch, terminal
control, compile, or backtest enqueue followed.

## Safety

- No Card, EA source or binary, setfile, basket manifest, registry, magic row,
  queue identity, priority, hold, claim, or verdict was changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
  deploy-manifest, `T_Live`, or AutoTrading surface was touched.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this commit.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12778_q09_active_cpu_stop_20260911T170209Z_board_advisor.json`.

## Resume contract

Let the governed T8 run reach a terminal Q09 verdict. Do not enqueue or
priority-mark another Q09 identity. After capacity recovers, re-read that exact
row; only a governed append-only infrastructure recovery is eligible if the
terminal result is non-economic and explicitly retryable.
