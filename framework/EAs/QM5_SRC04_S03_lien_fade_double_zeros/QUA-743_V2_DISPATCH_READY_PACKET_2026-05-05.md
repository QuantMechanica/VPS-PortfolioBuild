## QUA-743 v2 Dispatch-Ready Packet

Purpose:
- Leave a zero-latency handoff artifact so execution can start immediately after approvals.

Parent issue:
- `QUA-743` (`QM5_SRC04_S03 lien_fade_double_zeros`, `ea_id=1009`)

## Gate Snapshot (must be true before build starts)

- [ ] R-and-D verdict is `acknowledged` on `ZT_RootCause_QM5_SRC04_S03_20260505.md`
- [ ] CEO dispatch is approved for `ZT Recovery v2-build QM5_SRC04_S03 2026-05-05`

## Child-Issue Draft (for immediate creation on unblock)

- Assignee: `CTO`
- Title: `ZT Recovery v2-build QM5_SRC04_S03 2026-05-05`
- Scope:
  - Create new v2 lineage (do not overwrite v1)
  - Apply one change only: `order_expiration_minutes` default `60 -> 240`
  - Compile and capture compile evidence
  - Run P2 mini-cohort smoke (5 symbols, 2 runs each)
  - Promote to full P2 baseline only if mini-cohort improves

## v2 Acceptance Checks

- [ ] v1 lineage preserved unchanged
- [ ] v2 source contains only the intended single-axis parameter change
- [ ] compile result `0 errors, 0 warnings`
- [ ] mini-cohort ZT count `< 5` (target `< 3`)
- [ ] if mini-cohort passes, full P2 outputs published (`CSV` + `JSON` + `v1_vs_v2` comparison)

## Escalation Rule

- If v2 still returns cohort `>=5` ZT, open next recovery iteration (v3 hypothesis path), do not abandon trail.

## Operator Note

- This packet is preparatory only and does not bypass governance gates.
- Build execution starts immediately once both gate checkboxes above are satisfied.
