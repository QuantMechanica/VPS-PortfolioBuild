# QM5_12778 FX cointegration dispatch-readiness handoff

Recorded: 2026-09-04T23:52:49Z (2026-09-05 01:52 Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

The selected non-duplicate continuation is the existing D1 AUDUSD/EURJPY
cointegration basket `QM5_12778`. Its exact `Q09_NEWS` row is now confirmed
runnable, priority-bound, unheld, and unique. It remains pending because the
sealed OOS campaign assigns diagnostic order 10,006, which puts it 1,241st
among 9,240 rows returned by the canonical claim selector at observation time.

No duplicate row was enqueued and no tester was manually dispatched. The
resident five-minute paced task ran successfully at 01:50:50 local time but did
not claim this row during the six-sample watch window. Rewriting its campaign
order or pretending it is an append-only lineage rerun would falsify governed
queue semantics, so neither was done.

## Why no new pair was built

The frozen 66-pair scan is already fully represented: the latest complete
census records 123 approved identities and 123 matching EA directories, with
zero approved-but-unbuilt identities. Creating another card, EA, manifest, or
logical Q02 row would duplicate the governed frontier.

The two requested anchors also need no Q02 setup repair:

- `QM5_12532` has logical-basket Q02 PASS and Q04 PASS, then Q05 FAIL.
- `QM5_12533` has logical-basket Q02 PASS, then Q04 FAIL.

Historical ONINIT, NO_HISTORY, per-leg, and invalid rows do not override those
later canonical Q02 PASS receipts.

## Exact continuation state

- Work item: `24acc5d4-3e34-526e-a7a8-12640a2e759f`
- Phase: `Q09_NEWS`
- State: pending, unclaimed, attempt 0, no verdict
- Open identical `(EA, phase, symbol)` rows: 1
- Active holds: none
- Activation: `RUNNABLE_BOUND`
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Payload SHA-256: `5b7613207b9f89bd466b9165d6b257c4f1d97e33a954be3c6c66f6be9c6d7589`

The basket payload declares AUDUSD.DWX and EURJPY.DWX as the traded legs and
EURUSD.DWX/EURAUD.DWX as conversion history. Repository artifact observations:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `132a501d94685f013cc62a8b3c2de111d0a8b1e616a8656d2c61b061a754c146` |
| EX5 | `2a105cfbb364142c96c552136bb450162c142845665ce3366d0c045248c17a01` |
| Basket manifest | `0ce25d17ebe7c3664e4acdb6c1d302b28b1f40710301189cc633e44f25854d57` |
| Logical backtest setfile | `0e7949276927c8c5355c413c631e7b67f684e757892de59fa2cff5521836c8e9` |

## Capacity and safety

Five one-second host-CPU samples were 55.70%, 69.54%, 62.61%, 55.09%, and
58.70% (average 60.33%, maximum 69.54%). The explicit 97% ceiling did not bind,
but no extra load was created because scheduled workers own dispatch.

No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
T_Live manifest/file, terminal control, or AutoTrading state was touched.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12778_dispatch_readiness_20260904T235249Z_board_advisor.json`.

## Resume contract

On the next wake, re-read the exact row. If it is still pending, retain its
sealed diagnostic order and let the resident paced worker claim it. If it ends
with `CONFIG_LOCKED`, accept only the canonical automatic successor. If it ends
with an infrastructure taxonomy, use the governed append-only rerun path and
preserve the terminal row.
