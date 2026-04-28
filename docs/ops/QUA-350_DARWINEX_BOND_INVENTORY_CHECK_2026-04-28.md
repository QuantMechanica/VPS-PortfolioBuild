# QUA-350 - Darwinex bond-CFD inventory check (US 10Y + Bund 10Y)

Date: 2026-04-28  
Owner: DevOps

## Change delivered

- Added idempotent read-only probe:
  - `infra/scripts/Test-DarwinexBondInventory.ps1`
- Registered in infra index:
  - `infra/README.md`

## Run command (T1 VPS)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-DarwinexBondInventory.ps1
```

## Outputs

- `infra/reports/darwinex_bond_inventory_latest.json`
- `infra/reports/darwinex_bond_inventory_latest.md`

## Current run status (2026-04-28)

- Probe executed successfully on this host, but MT5 symbol probe is unavailable:
  - `mt5_probe_ok: false`
  - `mt5_probe_error: MT5 probe did not return output`
- Current inventory classification:
  - `US10Y`: `missing`
  - `DE10Y`: `missing`
- Local filesystem evidence (same run):
  - `D:\QM\mt5\T1\MQL5\Files\imports\done\*.import.txt` contains no `US10Y*`, `UST10Y*`, `US10YR*`, `DE10Y*`, `BUND*` entries.
  - `D:\QM\reports\setup\tick-data-timezone\*_GMT+*_US-DST.csv` has no bond-candidate staging files on this host.
- Disposition: not yet conclusive for Darwinex availability; requires execution on VPS T1 with live MT5 session access.

## Captured market-metadata fields

The probe now emits per-symbol MT5 detail when available, including:
- `trade_mode`, `trade_calc_mode`
- `spread_points`, `spread_float`, `bid`, `ask`
- `volume_min`, `volume_step`, `volume_max`
- `margin_initial`, `margin_maintenance`
- symbol description/path (used to infer session/liquidity context)

## Status model

- `present`: broker source symbol hit exists and at least one custom artifact hit exists (`MT5 custom`, staging CSV, or `imports\done`)
- `partial`: some hits exist but not enough for `present`
- `missing`: no hits

## Next action

1. DevOps: run the probe on VPS T1 with accessible Darwinex MT5 terminal and attach the generated JSON/markdown artifacts to QUA-350.
2. CEO/CTO: decide disposition from T1 artifact:
   - both `present` -> approve `_v2` Darwinex-bond-CFD-proxy path.
   - both `missing` -> escalate OWNER decision on FRED shim ratification vs `_v1` long-term hold.
