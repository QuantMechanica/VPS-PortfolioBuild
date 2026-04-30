# QUA-601 Weekly Update Template

Use this template for each Monday snapshot (`QUA-603`, `QUA-604`) and for the final checkpoint (`QUA-605`).

## Snapshot Metadata

- Snapshot date (UTC): `<YYYY-MM-DDTHH:MM:SSZ>`
- Source file: `public-data/company-runtime.json`
- Source query:

```sql
select count(*)
from heartbeat_runs r
where r.company_id = '<company_id>'
  and r.started_at > now() - interval '7 days';
```

## Metrics

- Weekly run count: `<N>`
- Baseline: `14,639`
- Target (2026-05-15): `<=11,700`
- Delta vs baseline: `<+/-N>` (`<+/-PCT>%`)
- Delta vs target: `<+/-N>` (`<+/-PCT>%`)

## Trend Note

- Week-over-week change vs prior snapshot: `<+/-N>` runs (`<+/-PCT>%`).
- Direction: `<improving|flat|worsening>`.

## Next Action

- `<specific next step with date>`
