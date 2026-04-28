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

## Status model

- `present`: broker source symbol hit exists and at least one custom artifact hit exists (`MT5 custom`, staging CSV, or `imports\done`)
- `partial`: some hits exist but not enough for `present`
- `missing`: no hits

## Next action

1. Run the probe on VPS T1 and attach the generated JSON/markdown artifacts to QUA-350.
2. If `US10Y` or `DE10Y` is `partial`/`missing`, align naming candidate sets to broker-visible symbols and update source overrides before the next import pass.
