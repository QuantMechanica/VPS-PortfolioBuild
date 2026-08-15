# FX cointegration GBPUSD/USDJPY — physical-memory ceiling stop

Date: 2026-08-15

Branch: `agents/board-advisor`

Sample: `2026-08-15T17:50:25.2038179Z`

## Outcome

The frozen sign-aware 66-pair scan remains fully mechanized, so a new Card or
EA would duplicate existing work. The two requested anchors remain beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The non-duplicate fallback remains the repaired rank-58 `GBPUSD.DWX` /
`USDJPY.DWX` basket in `QM5_1257_lemishko-fx-cointpair`. A fresh canonical
queue read found its exact logical Q02 work item still pending once and
unclaimed. No second row was created, and no existing row was requeued,
restamped, or reprioritized.

## Exact Q02 identity

| Field | Value |
| --- | --- |
| Work item | `d4cd660c-c81a-41d3-8a4c-ad21d3319816` |
| Logical symbol | `QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1` |
| Status | `pending`, unclaimed |
| Attempt count | 2 |
| Open rows for exact identity | 1 |
| Last update | `2026-08-15T13:03:04.898529Z` |
| Entry repair | `751cb391d8f388f5b61641ba3299011cdf9a09ed` |
| Exit repair | `f9ef37c1c` |

The read-only command
`python tools/strategy_farm/farmctl.py work-items --ea QM5_1257` returned one
pending Q02 row, the exact identity above. The other 28 historical rows were
terminal: one logical FAIL, 21 superseded physical-basket rows, and six obsolete
non-DWX rows. The current row therefore remains the only legitimate execution
identity for the repaired basket.

## Binding resource ceiling

The post-containment OWNER decision
`RTA-2026-08-15-POST-CONTAINMENT-RELEASE-2` is present at current HEAD, so the
older signed-containment blocker is not used as the stop reason in this pass.
A fresh operating-system sample instead measured:

| Resource | Sample |
| --- | ---: |
| CPU load | 2.0% |
| Free physical memory | **0.40 GiB** |
| Total physical memory | 63.12 GiB |
| Free physical memory | **0.63%** |

Physical-memory exhaustion is independently binding. The same host had already
raised `System.OutOfMemoryException` during this target's strict compile with
materially more memory available. Per the mission's explicit backtest resource
ceiling, no compile, enqueue, dispatch tick, tester launch, terminal reservation
or control, containment mutation, or process cleanup followed.

This is materially distinct from the committed `16:07:12Z` stop. That snapshot
had 54.34 GiB free and was blocked by an active basket lane plus signed Custom
history containment. The current repository decision releases that containment,
but available memory has fallen to 0.40 GiB; the exact repaired Q02 row remains
pending without artifact or identity drift being introduced by this pass.

Machine-readable evidence:
`artifacts/fx_cointegration_gbpusd_usdjpy_memory_ceiling_stop_20260815T175025Z_board_advisor.json`.

## Safety

No portfolio-admission path, `_kpi`, `_q08_contribution`, T_Live manifest or
terminal, AutoTrading state, deploy artifact, Card, EA, registry, setfile,
basket manifest, external queue row, history archive, runtime containment state,
or factory process was changed. Unrelated WTI working-tree changes were left
unstaged and untouched.
