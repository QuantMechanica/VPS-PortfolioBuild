# QM5_10998 EURJPY Q02 infrastructure requeue — 2026-07-24

## Scope

- Work item: `9a4079d9-20df-4341-b229-c464e1fb3c6f`
- EA / symbol: `QM5_10998 / EURJPY.DWX`
- Phase: `Q02`
- Failed terminal: `T4`
- Evidence: `D:\QM\reports\work_items\9a4079d9-20df-4341-b229-c464e1fb3c6f\QM5_10998\20260724_024935\summary.json`

## Diagnosis

The Q02 prescreen failure is infrastructure, not a strategy or binary defect.
The evidence binds identical source and deployed `.ex5` hashes
(`54a961cb222976f33476f5793a654f5501795cd24c2b06b75be549637b370246`)
and identical source and deployed setfile hashes
(`73b00dd4a68c2ec7e19fe2b86234840b2dabf0756451ca6906f83451ac33f6cb`).
MT5 loaded `EURJPY.DWX` history and ticks, initialized the EA, and began the
requested H4 test. It then disconnected after the EA's secondary
`EURUSD.DWX` series reported `history synchronization error`.

The three retries on T4 consequently emitted incomplete zero-bar reports.
There was no `OnInit` failure and no evidence of stale build artifacts.

## Repair

The existing farm row was atomically returned to `pending` with:

- `avoid_terminals` extended to include `T4`;
- the original setfile and evidence-binding hashes retained;
- `infra_repair_reason=secondary_EURUSD_history_sync_error_on_T4`;
- the failed evidence path retained in `prior_infra_evidence_path`.

This requeues only the affected diverse forex work item. It does not change EA
logic, risk settings, portfolio gates, T_Live state, or live manifests.
