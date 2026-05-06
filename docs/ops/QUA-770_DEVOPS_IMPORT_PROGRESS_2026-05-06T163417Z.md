# QUA-770 DevOps import progress (2026-05-06T163417Z)

## Actions executed this heartbeat
- Added idempotent sync script: `infra/scripts/Sync-CustomSymbolData.ps1`.
- Applied sync for bonus parity item: `NDXm.DWX` from `T2` -> `T1` (history + ticks).
- Re-ran presence audit with `infra/scripts/Test-CustomSymbolPresence.ps1`.
- Ran broker symbol scan on T1-T5 via MT5 Python API.

## Verified outcomes
- `NDXm.DWX` parity gap closed: now present on T1-T5.
- `US500.DWX` remains missing on T1-T5.
- `NAS100.DWX` remains missing on T1-T5.
- Broker symbol inventory on T1-T5 currently exposes `NDX`, but not `US500`/`NAS100`.

## Evidence
- `docs/ops/QUA-770_DEVOPS_CUSTOM_SYMBOL_PRESENCE_2026-05-06T163417Z.json`
- `docs/ops/QUA-770_DEVOPS_CUSTOM_SYMBOL_PRESENCE_2026-05-06T163417Z.pretty.json`
- `docs/ops/QUA-770_DEVOPS_BROKER_SYMBOL_SCAN_2026-05-06T163417Z.json`

## Blocker status
- Remaining blocker is source acquisition for `US500.DWX` + `NAS100.DWX` history/ticks.
- Unblock owner: DevOps.
- Unblock action: obtain/import Darwinex export package or broker account/server that exposes those symbols, then run all-terminal import and parity proof.
