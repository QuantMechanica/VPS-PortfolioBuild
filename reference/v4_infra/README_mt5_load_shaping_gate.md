# MT5 Load-Shaping Gate (DevOps)

Script: `Company/scripts/infra/mt5_load_shaping_gate.ps1`

Purpose:
- Non-destructive policy gate for deciding whether BL load should stay at 2T, allow 3T, hold 3T, or fallback to 2T.
- Encodes the `QUAA-21` draft thresholds from recurring memory/disk pressure alerts.

## Decision model

Entry gate (2T -> 3T):
- memory used <= 88%
- disk free >= 50 GB
- no active critical alert
- healthy polls >= 3

Fallback gate (3T -> 2T):
- memory used >= 92% for >= 6 minutes
- OR disk free <= 35 GB
- OR disk drop >= 10 GB in 10 minutes
- OR critical alert active

## Inputs

Defaults:
- Tries to read `Company/Observability/state.json` first.
- Falls back to live host probes (`Win32_OperatingSystem`, `Win32_LogicalDisk`) if needed.

Optional overrides:
- `-CurrentMode 2T|3T`
- `-MemoryUsedPct <double>`
- `-DiskFreeGb <double>`
- `-DiskDropGb10Min <double>`
- `-HighMemoryMinutes <double>`
- `-ConsecutiveHealthyPolls <int>`
- `-CriticalAlertActive` (switch)
- `-StateFilePath <path>`
- `-DiskDrive <drive>`

## Examples

Use current live/state data, evaluate 2T entry:

```powershell
powershell -ExecutionPolicy Bypass -File "Company/scripts/infra/mt5_load_shaping_gate.ps1" -CurrentMode 2T
```

Evaluate active 3T run with explicit stress telemetry:

```powershell
powershell -ExecutionPolicy Bypass -File "Company/scripts/infra/mt5_load_shaping_gate.ps1" `
  -CurrentMode 3T `
  -MemoryUsedPct 92.4 `
  -HighMemoryMinutes 8 `
  -DiskFreeGb 33.7 `
  -DiskDropGb10Min 11.2 `
  -ConsecutiveHealthyPolls 1 `
  -CriticalAlertActive
```

## Output

JSON object with:
- `recommendation`: `stay_2T`, `allow_3T`, `hold_3T`, or `fallback_to_2T`
- `metrics` used for decision
- `thresholds`
- `reasons`

## Safety

- No process kill, restart, or terminal mutation.
- Decision-only helper for CTO/DevOps/Pipeline policy gating.
