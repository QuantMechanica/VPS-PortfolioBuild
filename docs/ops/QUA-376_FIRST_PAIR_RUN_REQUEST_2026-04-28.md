# QUA-376 First Pair Run Request — 2026-04-28

Machine-readable request:
- `docs/ops/QUA-376_FIRST_PAIR_RUN_REQUEST_2026-04-28.json`

## Current Gate State

- Proxy pair readiness: `ready` (`artifacts/qua-376/proxy_pair_readiness.json`)
- Queue/dispatch contract: verified
- Remaining block: **SRC05_S01 expert binary + active magic registry row are missing**

## Evidence for Block

- Available `QM` experts on T1 do not include `SRC05_S01` pair EA.
- `framework/registry/magic_numbers.csv` has only one active row (`ea_id=1001`, `EURUSD.DWX` smoke baseline).

## Unblock Owner / Action

- Owner: `CTO/Dev`
- Action: compile + deploy `QM5_SRC05_S01_chan_at_bb_pair.ex5` to T1-T5 and add active magic row for SRC05_S01.

## Immediate Next Command Once Unblocked

Use nonce-safe queue tuple with pair mapping in config digest:

```powershell
.\infra\scripts\Invoke-PipelineQueuedSmokeRun.ps1 `
  -EAId <SRC05_S01_EAID> -Version v1 -Symbol XAUUSD.DWX -Phase P3.5 `
  -SubGateConfig "src05_s01:pair_proxy=xauusd.dwx-xtiusd.dwx:lookback20:entry1:exit0:<nonce>" `
  -Terminal T2 -Year 2024 -Expert "QM/QM5_SRC05_S01_chan_at_bb_pair" -Period H1 `
  -Runs 2 -MinTrades 1 -TimeoutSeconds 600 -AllowMissingRealTicksLogMarker
```
