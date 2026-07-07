# QM5_12712 Q07 Priority Requeue - 2026-07-07

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits, no portfolio admission/KPI/Q08 contribution edits, and no
deploy-manifest edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair FX cointegration scan artifact. The strict survivors are not Q02
blocked:

- `QM5_12532` AUDUSD/NZDUSD: logical-basket Q02 `PASS`, Q04 `PASS`, later Q05
  `FAIL`.
- `QM5_12533` EURJPY/GBPJPY: logical-basket Q02 `PASS`, later Q04 `FAIL`.

Current repo/farm triage found no unbuilt positive-hedge EdgeLab FX
cointegration pair left. Per the mission fallback, this pass advanced an
existing forex basket instead of minting a duplicate.

Selected basket:

- EA: `QM5_12712_edgelab-eurgbp-euraud-cointegration`
- Pair: `EURGBP.DWX` / `EURAUD.DWX`
- Logical basket: `QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1`
- Host: `EURGBP.DWX`, `D1`

## Preflight

- Basket manifest present and declares:
  `EURGBP.DWX`, `EURAUD.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`.
- Logical setfile:
  `framework/EAs/QM5_12712_edgelab-eurgbp-euraud-cointegration/sets/QM5_12712_edgelab-eurgbp-euraud-cointegration_QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1_D1_backtest.set`
- Backtest risk mode verified:
  `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Duplicate guard before mutation: exactly one Q07 row existed and it was
  `failed`; zero pending/active Q07 rows existed for `QM5_12712`.
- `validate_symbol_scope.py --ea-label QM5_12712_edgelab-eurgbp-euraud-cointegration --json`:
  `BASKET_OK`, `n_violations=0`.
- `build_check.ps1 -EALabel QM5_12712_edgelab-eurgbp-euraud-cointegration -SkipCompile`:
  `PASS`, 0 failures, 0 warnings.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260707_051809.json`.

The build-check run refreshed only the canonical `build_hash` headers on the
existing QM5_12712 logical/stress setfiles.

## Prior Q07 Failure

Existing Q07 work item:

| Field | Value |
|---|---|
| Work item | `1b9fa7a5-48a7-4e57-a699-9e55dfb0cb19` |
| Prior status | `failed` |
| Prior verdict | `INFRA_FAIL` |
| Prior attempts | `2` |
| Previous phase | Q06 `PASS`, work item `305dd60d-e74d-4b6c-a5db-aef2dbacc327` |

The archived prior report root contains per-seed smoke summaries but no Q07
aggregate. Sample seed summaries report:

- `TIMEOUT`
- `METATESTER_HUNG`
- `INCOMPLETE_RUNS`
- `MODEL4_MARKER_REQUIRED`
- `oninit_failure_detected=false`

This was infrastructure-invalid evidence, not a strategy verdict.

## Queue Action

Requeued the existing row in place:

```text
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest --ea QM5_12712 --phase Q07
```

Result:

- Requeued work item: `1b9fa7a5-48a7-4e57-a699-9e55dfb0cb19`.
- Created rows: `0`.
- Status after requeue: `pending`.
- Verdict after requeue: `NULL`.
- Attempt count after requeue: `0`.
- Archived previous report root:
  `D:/QM/reports/work_items/1b9fa7a5-48a7-4e57-a699-9e55dfb0cb19.requeued_20260707T0518420000`.

Then priority-marked the same pending row only:

- DB backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12712_q07_priority_20260707T051933Z.sqlite`
- Event: `priority_track_set`, id `219207`.
- `priority_reason`:
  `OWNER 2026-07-07 forex portfolio mission fallback: no unbuilt positive-hedge EdgeLab FX cointegration pair remains; advance existing QM5_12712 EURGBP~EURAUD Q07 after Q02-Q06 PASS without duplicate enqueue.`

## Verification

`farmctl work-items --ea QM5_12712` shows:

- Q02 `PASS`
- Q03 `PASS`
- Q04 `PASS`
- Q05 `PASS`
- Q06 `PASS`
- Q07 `pending`

Readback of the Q07 row:

- `status=pending`
- `verdict=NULL`
- `attempt_count=0`
- `claimed_by=NULL`
- `portfolio_scope=basket`
- `priority_track=true`
- Duplicate guard after mutation: exactly one pending/active Q07 row for
  `QM5_12712`.

`mt5_queue_status.py --sqlite D:/QM/strategy_farm/state/farm_state.sqlite --limit 10`
reports `QM5_12712` Q07 as `queued_top[0]`.

Stop condition: the farm was at the backtest CPU ceiling after the queue
mutation (`active=5`, `pending=5541`). No manual MT5/tester run was launched;
the paced workers own execution.
