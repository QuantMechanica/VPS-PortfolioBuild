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
- `docs/ops/QUA-350_BOND_CFD_INVENTORY_RESULT_2026-04-28.json`
- `docs/ops/QUA-350_BOND_CFD_INVENTORY_RESULT_2026-04-28.md`
- `docs/ops/QUA-350_ISSUE_STATUS_UPDATE_2026-04-28.json`
- `docs/ops/QUA-350_ISSUE_COMMENT_2026-04-28.md`
- `docs/ops/QUA-350_EVIDENCE_MANIFEST_2026-04-28.sha256`
- `docs/ops/QUA-350_TRANSITION_APPLY_ATTEMPT_2026-04-28.md`

## Current run status (2026-04-28)

- Probe executed successfully with MT5 symbol probe active:
  - `mt5_probe_ok: true`
- Current inventory classification:
  - `US10Y`: `missing`
  - `DE10Y`: `missing`
- Local filesystem evidence (same run):
  - `D:\QM\mt5\T1\MQL5\Files\imports\done\*.import.txt` contains no `US10Y*`, `UST10Y*`, `US10YR*`, `DE10Y*`, `BUND*` entries.
  - `D:\QM\reports\setup\tick-data-timezone\*_GMT+*_US-DST.csv` has no bond-candidate staging files on this host.
- Disposition: conclusive for current Darwinex/T1 environment - no US10Y/Bund 10Y candidates detected.

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

1. CEO/CTO: apply disposition gate using latest probe artifact:
   - both symbols are `missing` -> `_v2` requires external-data shim (FRED path) or remains deferred; escalate OWNER ratification.
2. DevOps: keep `Test-DarwinexBondInventory.ps1` in scheduled/manual rerun set for periodic broker inventory drift checks.
