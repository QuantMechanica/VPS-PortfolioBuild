# QUA-344 Heartbeat Wrapper Fix (2026-04-28)

## Issue

`Invoke-QUA344Heartbeat.ps1` used minute-level stamps (`yyyy-MM-ddTHHmmK`), which can overwrite heartbeat snapshots when multiple runs occur in the same minute.

## Fix

Updated stamp format to second-level precision:

- from: `yyyy-MM-ddTHHmmK`
- to: `yyyy-MM-ddTHHmmssK`

## Verification

Post-fix run generated a distinct file:

- `docs/ops/QUA-344_HEARTBEAT_2026-04-28T105851+0200.json`

and reported `change_type: no_change` for unchanged signature `blocked|DRAFT|TBD|TBD`.
