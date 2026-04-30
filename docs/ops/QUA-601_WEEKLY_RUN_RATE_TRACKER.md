# QUA-601 Weekly Run-Rate Tracker

Issue: `QUA-601`  
Scope: follow-up to `QUA-596` for weekly heartbeat run-rate tracking through **2026-05-15**.

## Baseline And Target

- Baseline weekly runs: **14,639**
- Target weekly runs by **2026-05-15**: **<= 11,700** (20% reduction)

## Source Query Contract

Authoritative query (from `infra/scripts/Run-RuntimeHealthScan.ps1`):

```sql
select count(*)
from heartbeat_runs r
where r.company_id = '<company_id>'
  and r.started_at > now() - interval '7 days';
```

Runtime snapshot source file: `public-data/company-runtime.json` (`budget.weekly_run_count`, `data_source=postgres`).

Helper command for weekly reporting:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\QM\repo\infra\scripts\Get-QUA601Snapshot.ps1"
```

## Weekly Snapshots

| Snapshot Date (UTC) | Window Metric | Weekly Runs | Delta Vs Baseline | Delta Vs Target | Notes |
|---|---:|---:|---:|---:|---|
| 2026-04-30T22:31:01Z | last 7 days | 14,656 | +17 (+0.12%) | +2,956 (+25.27%) | Bootstrap snapshot recorded on 2026-05-01 heartbeat. |

## Next Actions

- `QUA-603`: Monday snapshot for **2026-05-04**.
- `QUA-604`: Monday snapshot for **2026-05-11**.
- `QUA-605`: final checkpoint for **2026-05-15** (or earlier if completed).
