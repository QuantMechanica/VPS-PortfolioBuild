# QM5_20098 XAGUSD.DWX Q02 requeue — TP-attach defect fixed (2026-07-24)

## Why

The registry-swept Q02 items for the new harvest EAs were picked up by the
factory before the build run finished its smoke validation. XAGUSD.DWX ran with
the original binary (67d9a3d24) which carried the deferred-TP defect: positions
whose 2R target was traded through before the TP attach ran WITHOUT their
intended exit (653,089 rejected `10016` modifies in the XAUUSD smoke year).
Old-binary verdicts:

- Q02 PASS 2026-07-24T12:26:30Z (work item `e02998af-3809-4c81-b385-bd65497a4ea5`)
- Q04 FAIL 2026-07-24T12:42:35Z (work item `6b3ae1ef-3ccb-4264-a6c2-86d67721fbd5`)

Both are structurally distorted by the missing 2R exits — the Q04 FAIL judged a
defective EA, not the strategy.

## Fix lineage

- Fix commit (pump auto-commit of the corrected source+binary): `1331c827f`
  (+ mid-edit `0f8744270`); rationale/amendments committed in the follow-up
  docs commit. Fixed-build smoke: `D:\QM\reports\smoke\QM5_20098\20260724_124929\`
  (542 trades deterministic, logger 2,838 events vs 1.3M).

## Action (per QM5_1642 requeue precedent)

Under `BEGIN IMMEDIATE`, the existing XAGUSD Q02 row was reopened in place as
`pending`; verdict/evidence/claim cleared; payload records requeue reason,
actor, and superseded old-binary evidence. No duplicate item inserted; no
priority raised (OWNER 2026-07-24: "keine Priorisierung"). DB backup:
`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_20098_xagusd_q02_requeue_20260724T125549Z.sqlite`

The old Q04 FAIL row stays as immutable old-binary history; the cascade
creates the successor Q04 item when the requeued Q02 completes. Follow-up
check owed: verify a fresh Q04 item appears after the Q02 verdict (if the
cascade dedupes against the historical row, reopen manually by the same
procedure).

XAUUSD.DWX Q02 was still `pending` and needs no action — dispatch deploys the
fixed binary from the repo automatically.

## Follow-up 13:52Z

Requeued Q02 re-ran with the fixed binary: **PASS** (13:26Z, evidence
`...e02998af...\QM5_20098\20260724_131930\summary.json`). The cascade did NOT
create a successor Q04 item (deduped against the historical old-binary FAIL
row) — as anticipated above, the Q04 XAGUSD row was reopened in place as
`pending` (backup `farm_state_before_qm5_20098_xagusd_q04_reopen_20260724T135251Z.sqlite`).
