# Dukascopy monthly refresh — Default-OFF implementation

**Task:** `e37931c2-f21f-46fb-ac63-65cf810730e2`  
**Disposition:** REVIEW — control plane built; activation/import blocked.

## Result

The monthly cadence is defined as day 3 at 03:10 Europe/Berlin for the complete
previous calendar month. The scheduler definition has two independent OFF
boundaries: Windows Task Scheduler state `Disabled`, and an entry point that
returns `DEFAULT_OFF` unless both `--apply` and the process-scoped
`QM_DUKASCOPY_MONTHLY_REFRESH_ENABLED=1` are present.

An apply admission additionally requires an OWNER-signed, self-hashed manifest
update for the exact month/year, Claude `APPROVED`, an open bounded window,
37/37 P3 PASS, exact P3 and manifest hashes, an exact current Factory-OFF flag
hash, and zero active claims. A create-exclusive per-year writer lock provides
the common collision boundary that the initial backfill and monthly importer
must both acquire. Missing or inconsistent evidence fails closed.

The controller creates only an `AUTHORIZED_HANDOFF` receipt. It deliberately
does not download, import, distribute, start/control a terminal, or write an
archive year. The later P4 writer must integrate the same validation and
reacquire the same year lock before its first history write. This preserves a
code-level no-write boundary while current P3 evidence is blocked.

## Current blocker

The 2026-09-12 Dukascopy tail has 36/37 scratch conversions and 0/24 P3 passes,
not 37/37. Therefore no signed archive update can pass this controller and no
history mutation was attempted. A separate OWNER escalation requests the
eventual 30–60 minute Factory-OFF distribution/audit window:
`docs/ops/OWNER_ESCALATIONS/2026-09-12_monthly_tick_refresh_pause.md`.

## Durable artifacts

- `tools/dukascopy/monthly_refresh.py`
- `tools/dukascopy/install_monthly_refresh_task.ps1`
- `tools/dukascopy/config/monthly_refresh.task.json`
- `tools/dukascopy/tests/test_monthly_refresh.py`
- `docs/ops/DUKASCOPY_MONTHLY_REFRESH_RUNBOOK_2026-09-12.md`

## Verification

```text
focused Dukascopy tests: 32 passed
Python compile: PASS
PowerShell parser: PASS
installer without -Apply: DRY_RUN; no scheduled task registered
runner without --apply: DEFAULT_OFF, archive_write_performed=false
git diff --check (scoped paths): PASS
```

No archive, Custom-history root, database, scheduled task, terminal, T_Live,
FTMO, AutoTrading, verdict, registry, or gate state was changed.
