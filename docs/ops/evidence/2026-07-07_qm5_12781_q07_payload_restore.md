# QM5_12781 Q07 Payload Restore

Date: 2026-07-07
Branch: `agents/board-advisor`
Operator: Codex

## Action

Advanced the existing non-duplicate FX cointegration basket `QM5_12781`
(`USDJPY.DWX/AUDJPY.DWX`) by restoring explicit Q07 queue payload controls on
the existing pending work item:

- Work item: `38226031-b41f-4f03-ab86-d1697ca5e203`
- Phase: `Q07`
- Status after mutation: `pending`
- Duplicate work item created: no
- Manual MT5 dispatch launched: no

The guarded update added `priority_track=true` and `q07_seed_timeout_sec=5400`
to the existing row. It did not change strategy code, setfiles, manifests, or
any portfolio gate artifact.

## Rationale

No unbuilt card-worthy FX cointegration pair remained from the checked scan
frontier:

- `QM5_12532`: Q02 PASS, Q04 PASS, Q05 FAIL; not Q02-blocked.
- `QM5_12533`: Q02 PASS, Q04 FAIL; not Q02-blocked.
- `QM5_13024`: Q02 PASS, Q04 FAIL.
- `QM5_13029`: Q02 PASS, Q03 PASS, Q04 FAIL.
- `QM5_13020`: Q02 PASS, Q03 FAIL, Q04 FAIL.

`QM5_12781` is the current clean continuation candidate because it already has
Q02/Q05/Q06 PASS evidence and a pending Q07 retry after the seed-timeout repair.
The live row lacked the explicit priority and seed-timeout payload fields, so
this restores the intended routing without adding CPU load.

## Evidence

- DB backup before update:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12781_q07_payload_restore_20260707T190316Z.sqlite`
- Conditional guard: `status='pending' and claimed_by is null`
- Rows updated: 1
- Before payload: no `priority_track`, no `q07_seed_timeout_sec`
- After payload: `priority_track=true`, `q07_seed_timeout_sec=5400`

Post-checks:

- `python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --ea QM5_12781`
  shows Q07 still pending and unclaimed.
- SQLite payload check confirms the existing Q07 row has
  `priority_track=true` and `q07_seed_timeout_sec=5400`.
- Active farm load remained at 7, so no new test was launched under the CPU
  ceiling.

Machine-readable artifact:
`artifacts/qm5_12781_q07_payload_restore_20260707T190323Z.json`.

## Safety

No `T_Live`, AutoTrading, deploy manifest, portfolio gate, portfolio admission,
portfolio KPI, or Q08 contribution file was touched.
