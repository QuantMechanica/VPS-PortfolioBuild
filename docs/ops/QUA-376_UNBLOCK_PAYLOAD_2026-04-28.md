# QUA-376 Unblock Payload — 2026-04-28

## Decision

SRC05_S01 pair proxy preflight is **READY** using `XAUUSD.DWX` + `XTIUSD.DWX`.

Authoritative readiness artifact:
- `artifacts/qua-376/proxy_pair_readiness.json`

## Heartbeat Metrics

- queue depth: `0`
- claimed terminals in smoke state: `T1`
- dedup rows: `13`
- ack statuses (smoke state):
  - `succeeded=6`
  - `no_report=7`
- current running terminals: `T1,T2,T3,T4,T5` (single `T1` process normalized)

## Queue-Ready Commands (pair-mapped)

1. XAU leg (pair context encoded in config):
```powershell
.\infra\scripts\Invoke-PipelineQueuedSmokeRun.ps1 `
  -EAId 1001 -Version v1 -Symbol XAUUSD.DWX -Phase P3.5 `
  -SubGateConfig "src05_s01:pair_proxy=xauusd.dwx-xtiusd.dwx:xau:lb20:<nonce>" `
  -Terminal T1 -Year 2024 -Expert "QM/QM5_1001_framework_smoke" -Period H1 `
  -Runs 2 -MinTrades 1 -TimeoutSeconds 600 -AllowMissingRealTicksLogMarker
```

2. XTI leg (same nonce family):
```powershell
.\infra\scripts\Invoke-PipelineQueuedSmokeRun.ps1 `
  -EAId 1001 -Version v1 -Symbol XTIUSD.DWX -Phase P3.5 `
  -SubGateConfig "src05_s01:pair_proxy=xauusd.dwx-xtiusd.dwx:xti:lb20:<nonce>" `
  -Terminal T1 -Year 2024 -Expert "QM/QM5_1001_framework_smoke" -Period H1 `
  -Runs 2 -MinTrades 1 -TimeoutSeconds 600 -AllowMissingRealTicksLogMarker
```

3. Automated equivalent:
```powershell
.\infra\scripts\Invoke-QUA376ProxyPairReadiness.ps1
```

## Evidence Pointers

- readiness summary: `artifacts/qua-376/proxy_pair_readiness.json`
- XAU success run dir: `artifacts/qua-376-smoke/factory_runs/QM5_1001/v1/P3.5/XAUUSD.DWX/c7ed324a9c006503d6995afa462be36f8bd06f779a68f9b2ee730a96560987ce/`
- XTI success run dir: `artifacts/qua-376-smoke/factory_runs/QM5_1001/v1/P3.5/XTIUSD.DWX/d15bd9f3d61246ff09589c0a1e9f08083e3250d9fb8f9e752c42d4af0c721987/`

## Next Action

Move from smoke preflight to first SRC05_S01 implementation candidate with true pair-spread logic and queue it against the same proxy pair mapping digest.
