# Governed monthly Dukascopy custom-history refresh

Status: **BUILT, DEFAULT-OFF — initial P2/P3 evidence still blocks activation**  
Task: `e37931c2-f21f-46fb-ac63-65cf810730e2`  
Authority: OWNER note on `OWNER-DEC-Q09-LEGACY-CALENDAR-INPUT-20260909`.

## Cadence and boundaries

The proposed task runs on the third calendar day at 03:10 Europe/Berlin and
targets the entire previous calendar month. This avoids a partial final day and
gives the source two days to settle. The scheduled action is deliberately only
an admission probe: the task is registered **Disabled**, its Python entry point
returns `DEFAULT_OFF` without arguments, and `QM_DUKASCOPY_MONTHLY_REFRESH_ENABLED=1`
is additionally required for `--apply`.

The signed 2017–2025 archive is outside this lane. During 2026, only the
OWNER-authorized mutable 2026 year may be refreshed. A December-to-January
sealing transition needs a new archive decision and implementation review.
Nothing in this task touches `T_Live`, FTMO, AutoTrading, or a terminal process.

## Why activation is blocked today

Evidence `docs/ops/evidence/2026-09-12_dukascopy_p2_p3_tail_execution.md`
records 36/37 conversions and **0/24 P3 passes**. AUDCAD has an unresolved
source hour; the governed T1 overlap ends in December 2025; coverage is below
99%; and XAUUSD/UK100/XTIUSD have unresolved scale/basis defects. The monthly
lane cannot turn that result into an archive write. Its first possible
activation is after a fresh 37/37 P3 PASS and separate signed manifest update.

## Monthly ceremony

1. Run the disabled entry point manually without `--apply`; retain its
   `DEFAULT_OFF` JSON. Do not enable the scheduled task.
2. Complete P1 download and P2 conversion into new immutable scratch roots.
   They may run while the factory operates because they do not write Custom
   history.
3. Run P3 against a fresh governed T1 overlap export. Require 37/37 PASS,
   the fixed price/coverage/DST criteria, and hash-bound source sidecars.
4. Prepare a manifest-update proposal naming the exact month, target mutable
   year, scratch identities, splice points and rollback inputs. It must say
   `archive_write_authorized=true` only after independent Claude APPROVED
   review and OWNER signature.
5. Obtain a new bounded OWNER pause receipt. Run normal Factory OFF, drain
   without killing work, and require an exact `FACTORY_OFF.flag` hash plus zero
   active rows. The approval window binds those facts and the P3/manifest hashes.
6. Set the enable variable only in the ceremony process and create the admission
   receipt:

   ```powershell
   $env:QM_DUKASCOPY_MONTHLY_REFRESH_ENABLED = '1'
   python C:\QM\repo\tools\dukascopy\monthly_refresh.py --apply `
     --refresh-month 2026-08 `
     --owner-approval D:\QM\reports\dukascopy\approvals\<window>\owner_approval.json `
     --farm-root D:\QM\strategy_farm `
     --output D:\QM\reports\dukascopy\approvals\<window>\admission.json
   Remove-Item Env:\QM_DUKASCOPY_MONTHLY_REFRESH_ENABLED
   ```

7. The result must be `AUTHORIZED_HANDOFF`. It does **not** write history.
   The reviewed P4 importer/distributor must revalidate the same approval and
   acquire `state/dukascopy_archive_year_<YYYY>.lock` before its first year
   write. The initial backfill and monthly lane use the same lock, so they
   cannot write the same archive year concurrently.
8. Import only via the governed T1 import queue, run `verify_import.py` per
   symbol, then distribute the mutable-year segment to T2–T10 inside the same
   pause. No direct terminal start is allowed.
9. Run two fresh full isolation audits. Require exact per-terminal private
   mutable inode identities, copy-on-claim receipts, manifest hashes, no
   cross-terminal mutable alias, and no unexpected archive change. Preserve
   rollback inputs and stop on any mismatch.
10. Claude reviews the receipt chain before the orchestrator performs the
    normal Factory ON ceremony. Unset the enable variable. The scheduled task
    remains Disabled until a separate recurring-activation decision.

## Scheduled-task installation

The installer is print-only by default. Even with a separate registration
release, it registers the task Disabled and never starts it:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  C:\QM\repo\tools\dukascopy\install_monthly_refresh_task.ps1
```

Registration, if later released, requires `-Apply -OwnerReleaseId OWNER-DEC-...`.
Rollback is `Unregister-ScheduledTask -TaskName QM_Dukascopy_MonthlyCustomHistoryRefresh`
after confirming the exact task name; registration alone cannot mutate data.

## Stop conditions

Stop before the first history write for any active claim, absent/drifted
Factory-OFF flag, closed approval window, missing signature/hash, P3 below
37/37, year-lock collision, Variant-A audit failure, sharing violation, or any
path resolving under `T_Live`. Retain all scratch and receipts for review.
