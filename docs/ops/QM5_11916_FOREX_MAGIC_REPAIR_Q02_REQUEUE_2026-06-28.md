# QM5_11916 Forex Magic Repair and Q02 Requeue - 2026-06-28

## Scope

EA: `QM5_11916_neely-weller-alexander-filter-2pct-d1`

Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11916_neely-weller-alexander-filter-2pct-d1.md`

Priority lane: diverse FX D1 infra rescue.

## Root Cause

Recent Q02 work items failed with `ONINIT_FAILED` / `EA_MAGIC_NOT_REGISTERED`.
Tester evidence showed `ea_id=11916 slot=0 magic=119160000`, while
`framework/registry/magic_numbers.csv` had no rows for EA ID `11916`.

The existing backtest setfiles also all used `qm_magic_slot_offset=0`, so
non-EURUSD symbols could not resolve their symbol-specific magic even after
registration.

## Repair

- Added ten `11916` magic registry rows for the approved FX universe.
- Regenerated `framework/include/QM/QM_MagicResolver.mqh`.
- Regenerated all ten D1 RISK_FIXED backtest setfiles with symbol slots:
  EURUSD=0, GBPUSD=1, USDJPY=2, USDCAD=3, USDCHF=4, AUDUSD=5,
  NZDUSD=6, EURJPY=7, GBPJPY=8, AUDJPY=9.
- Recompiled the `.ex5`.
- Added missing `SPEC.md`.
- Replaced raw `iClose` strategy reads with the framework `QM_SMA(..., period=1)`
  closed-bar reader and initialized `QM_EntryRequest.expiration_seconds`.

## Validation

- `python framework\scripts\validate_spec_doc.py framework\EAs\QM5_11916_neely-weller-alexander-filter-2pct-d1`
  - PASS: 1, FAIL: 0
- `.\framework\scripts\compile_one.ps1 -EALabel QM5_11916_neely-weller-alexander-filter-2pct-d1 -Strict`
  - PASS, 0 errors, 0 warnings
- `.\framework\scripts\build_check.ps1 -EALabel QM5_11916_neely-weller-alexander-filter-2pct-d1`
  - PASS, 0 failures
  - 16 advisory warnings from shared framework include scans

Build-check report:
`D:\QM\reports\framework\21\build_check_20260628_175437.json`

## Q02 Requeue

Queued a staged Q02 wave through the farm DB without starting local backtests:

| Work item | Symbol | Status |
|---|---|---|
| `ad1aaca6` | `EURUSD.DWX` | pending |
| `ddfca25d` | `USDJPY.DWX` | pending |
| `50063539` | `AUDJPY.DWX` | pending |

Deferred sidecar source: `codex_infra_repair.q02_requeue`

Deferred symbols: `GBPUSD.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`,
`NZDUSD.DWX`, `EURJPY.DWX`, `GBPJPY.DWX`.
