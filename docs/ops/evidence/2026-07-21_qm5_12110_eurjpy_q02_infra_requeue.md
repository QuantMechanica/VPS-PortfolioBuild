# QM5_12110 EURJPY Q02 infrastructure requeue

- UTC: 2026-07-21T11:16:14+00:00
- Branch: `agents/board-advisor`
- Mission unit: priority-2 diverse-FX funnel recovery
- EA: `QM5_12110_mtf-stochastic-confirmation`
- Symbol / phase: `EURJPY.DWX` / Q02
- Existing work item: `30fe0a43-0ae2-4fca-b8d4-f8e4aba91fc1`
- Coordination claim: `2e7d1235-913c-494d-af25-6efcb94a4196`

## Diagnosis

The Q02 prescreen completed with `PASS` over 2022-07-01 through 2022-12-31. The
full-history attempt then exhausted infrastructure retries with
`summary_missing_retries_exhausted`; it did not record a strategy verdict.
The row was unclaimed and there was no open farm claim for QM5_12110.

The deployed build is not stale: its SHA-256 is
`43f9a56d3a307b0cad47dac0508f3ed6a58d85dcca826d5b666478f0ae7f6810`, matching
the compile-PASS hash recorded in the work item. The canonical EURJPY setfile
contains `qm_ea_id=12110`, `RISK_PERCENT=0.0`, `RISK_FIXED=1000.0`, H1 host
metadata, and build hash
`066fefcc3fbea48fa6e64092de1e6b6b077649ea70ce49b9bbb8f13fe23fdff4`.

## Resolution

Under `BEGIN IMMEDIATE`, the existing work item was reopened in place as
`pending`, with verdict/evidence/claim cleared and `attempt_count=0`. No duplicate
work item was inserted. A farm `q02_infra_repair` coordination row records the
claim and pipeline handoff.

The database backup is
`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12110_eurjpy_requeue_20260721T111614Z.sqlite`.
No smoke test or manual dispatch was requested, and no T_Live or portfolio-gate
state was changed.
