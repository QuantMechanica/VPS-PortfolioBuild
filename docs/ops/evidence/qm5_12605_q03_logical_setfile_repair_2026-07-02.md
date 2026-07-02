# QM5_12605 Q03 Logical Setfile Repair - 2026-07-02

## Target

- EA: `QM5_12605_cme-oilgold-brk`
- Sleeve: `QM5_12605_XTI_XAU_BRK_D1`
- Phase: Q03
- Failed work item: `1a5582b1-543d-44c8-8556-45b0cbac8d33`
- Invalidated host-only work item: `6910df5d-2046-4d07-b36f-fcfce0353472`
- New work item: `9254332a-f0db-403b-8416-d467ae429767`

## Diagnosis

The latest Q03 failure reported `BARS_ZERO;REPORT_MISSING;NO_HISTORY;INCOMPLETE_RUNS`.
The work item was dispatching this setfile path:

`C:\QM\repo\framework\EAs\QM5_12605_cme-oilgold-brk\sets\QM5_12605_cme-oilgold-brk_QM5_12605_XTI_XAU_BRK_D1_D1_backtest.set`

That file had been removed by the 2026-07-02 rebuild and replaced with a host-symbol
setfile named `QM5_12605_cme-oilgold-brk_XTIUSD.DWX_D1_backtest.set`. This broke the
logical basket launch contract: Q03 expects the logical symbol plus `host_symbol:
XTIUSD.DWX`, matching the basket manifest and the other logical basket EAs.

## Repair

- Removed the host-only `XTIUSD.DWX` setfile.
- Restored the canonical logical-basket setfile path.
- Set header `symbol` to `QM5_12605_XTI_XAU_BRK_D1`.
- Set header `host_symbol` to `XTIUSD.DWX`.
- Kept the current v3 strategy inputs and explicit `qm_ea_id=12605`.
- Recompiled the EA and reran strict build checks.

## Verification

- `compile_one.ps1 -EALabel QM5_12605_cme-oilgold-brk -Strict`
  - PASS, 0 errors, 0 warnings
- `build_check.ps1 -EALabel QM5_12605_cme-oilgold-brk -Strict`
  - PASS, 0 failures
  - 16 existing framework include advisories

## Queue

Inserted Q03 pending work item `9254332a-f0db-403b-8416-d467ae429767` for
`QM5_12605_XTI_XAU_BRK_D1`, parent task `6f6719da-18f8-470c-b18f-edc702a8ccf2`,
pointing at the restored logical setfile.

Marked pending host-only Q02 work item `6910df5d-2046-4d07-b36f-fcfce0353472`
`INVALID` because logical Q02 had already passed and the host-only setfile surface
was the broken replacement introduced by the rebuild.

No local backtest was run; this was a launch-contract repair and the farm queue owns Q03 execution.
