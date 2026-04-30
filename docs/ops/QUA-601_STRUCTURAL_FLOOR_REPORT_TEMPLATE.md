# QUA-601 Structural Floor-Bound Report Template

Use only if target `<=11,700` weekly runs is not met by **2026-05-15**.

## Claim

- Target status: `<met|not met>`
- Final measured weekly run count: `<N>`
- Gap vs target: `<+/-N>` (`<+/-PCT>%`)
- Decision statement: `<why further reduction is structurally constrained>`

## Evidence

1. Metric source
- File: `public-data/company-runtime.json`
- Query contract:

```sql
select count(*)
from heartbeat_runs r
where r.company_id = '<company_id>'
  and r.started_at > now() - interval '7 days';
```

2. Timeline snapshots
- `<date>`: `<weekly_run_count>`
- `<date>`: `<weekly_run_count>`
- `<date>`: `<weekly_run_count>`

3. Constraint inventory
- Fixed operational obligations consuming baseline runs:
  - `<obligation 1>`
  - `<obligation 2>`
  - `<obligation 3>`
- What was already optimized:
  - `<optimization 1>`
  - `<optimization 2>`
  - `<optimization 3>`

## Scale-Invariance Assessment

1. Metrics affected by proposed further changes:
- `<list>`

2. Gate impact check:
- `<which pipeline gates would/would not change due to these metric changes>`

3. Re-run decision:
- `<explicit DO NOT RE-RUN or RE-RUN with reason>`

## Recommendation

- Recommended steady-state weekly cap: `<N>`
- Additional reduction options (if any), with expected impact and risk:
  1. `<option>`
  2. `<option>`
