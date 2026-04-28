---
dl: DL-037
date: 2026-04-28
title: Stage B CSV cleanup — delete D:\QM\Reports\setup\tick-data-timezone\ (467.08 GB / 79 files); T2-T5 mirror is canonical retention
authority_basis: OWNER directive 2026-04-28 06:35 local (Board Advisor relay) — non-T6 retention reclaim, OWNER-gated direct (not under DL-025)
recording_issue: QUA-311
status: recorded (executed 2026-04-28 ~06:35 local; recording-only follow-up)
---

# DL-037 — Stage B CSV Cleanup (Tick-Data-Timezone Source CSVs Removed)

Date: 2026-04-28
Recording issue: [QUA-311](/QUA/issues/QUA-311) (this entry's authoring task — recording-only)
Driving issue: [QUA-297](/QUA/issues/QUA-297) (action H — Board Advisor wake [comment 04ed90b1](/QUA/issues/QUA-297#comment-04ed90b1-b12b-458a-8fb9-c9fb250897f8) 2026-04-28 06:36 local)
Authorizer: OWNER (directive 2026-04-28 06:35 local "Stage B Go!", relayed via Board Advisor)
Executor: Board Advisor (`local-board`) — manual execution 2026-04-28 06:35:59 local
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)
Authority basis: OWNER directive direct. **Not** under [DL-025](./DL-025_t6_deploy_boundary_refinement.md) — Stage B is non-T6 retention reclaim, outside the T6 deploy boundary entirely.
Status: Recorded. Operation already complete; this DL is the audit-trail entry.

> **Recorder's note (Doc-KM scope per BASIS).** This DL records a destructive operation that was executed by the Board Advisor under direct OWNER directive, *not* by CEO and *not* via the Paperclip approval workflow. The Paperclip approval thread filed by CEO heartbeat 7 (`7ac36dbb-e4d0-473d-ad3c-c60de4582722`) remained `pending` because OWNER's verbal "Stage B Go!" + Board Advisor manual execution closed the action surface before the approval card could resolve. The thread stays as the audit record of the *requested* approval path; this DL is the audit record of the *executed* path. Per the [DL-027](./DL-027_basis_active_diff_propagation_rule.md) propagation classification this DL carries `reference_only` — no agent prompt body changes; no operational convention shift either, just a recorded one-shot reclaim.

## Decision

Removed `D:\QM\Reports\setup\tick-data-timezone\` entirely on 2026-04-28 ~06:35 local. The directory contained 79 files (35 ticks `_GMT+2_US-DST.csv` + 35 bars `_GMT+2_US-DST_M1.csv` + 9 extras) totalling **467.08 GB**.

| Metric | Before | After | Delta |
|---|---|---|---|
| `D:\QM\Reports\setup\tick-data-timezone\` exists | yes | no | removed |
| D: drive free space | 78.6 GB | 545.7 GB | **+467.1 GB** (matches expected exactly) |
| File count under path | 79 | 0 | -79 |

Execution command (Board Advisor, evidence file lines 22-25):

```powershell
Remove-Item -LiteralPath "D:\QM\reports\setup\tick-data-timezone" -Recurse -Force
```

Elapsed: < 1 second (NTFS recursive metadata delete; lazy block reclaim with immediate visibility).

## Why

Tick-data-timezone CSVs were the *source* dataset for the T1 Custom Tick Data import (PR-19) on 2026-04-25/26. Once T1 was fully staged from those CSVs and T2-T5 had been hash-mirror-verified from T1, the source CSVs no longer carried any operational role — the **mirror state on T1-T5 became the canonical retention surface**.

Stage B was queued behind two preconditions, both met by the time of execution:

1. **T2-T5 mirror verification** — completed via PR-20 hash-matched mirror on 2026-04-27, evidence at `C:\QM\repo\artifacts\qua-21\pr20_mirror_20260427_084558.json`.
2. **DEVOPS-004 family `spec_ok` final pass** — Fix_DWX_Spec_v3 final pass on 2026-04-27, log line `expected=36 matched=36 patched=0 unchanged=36 failed=0` at `D:\QM\mt5\T1\MQL5\logs\20260427.log`. All 36 .DWX symbols verified `spec_ok`.

Net outcome: 467.1 GB freed on D: against the V5 pipeline / report retention budget. Reversibility is preserved because the CSVs can be re-downloaded from Tick Data Suite (TDS subscription) on demand; the `.DWX` import service on T1 + the `prepare_import.py` tooling at `D:\QM\mt5\T1\dwx_import\` remain in place to re-stage from any future CSV drop. The reclaim is therefore high-value (467 GB) and low-risk (re-stageable from the TDS source).

## Authority

- **OWNER directive direct.** OWNER said "Stage B Go!" at 2026-04-28 ~06:35 local; Board Advisor relayed and executed in the same minute.
- **Not under [DL-025](./DL-025_t6_deploy_boundary_refinement.md).** DL-025 governs the T6 deploy boundary (approved EAs / setfiles / templates / profiles, with AutoTrading toggle staying manual OWNER). Stage B is non-T6 retention reclaim and lives outside the T6 deploy boundary entirely. The authority basis here is the OWNER directive itself, not any prior delegated rule.
- **Not under [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md).** DL-023 grants CEO broadened-autonomy for non-destructive internal process choices; destructive disk operations remain OWNER-gated. CEO correctly *did not* execute and instead filed approval thread `7ac36dbb-e4d0-473d-ad3c-c60de4582722` as the Paperclip-side path. OWNER's verbal authorization + Board Advisor execution closed the action surface before that thread could resolve.
- **Approval thread disposition.** Paperclip approval thread `7ac36dbb-e4d0-473d-ad3c-c60de4582722` (filed by CEO heartbeat 7) remains `pending` in the API. Per the boundary above, manual execution by the Board Advisor under direct OWNER directive bypassed the thread — the thread stays as the audit record of the *requested* path; this DL is the audit record of the *executed* path. CEO is asked to surface the disposition (close or annotate) on the next heartbeat to keep the API state coherent with reality.

## Source change (evidence pointer)

The single source-of-record evidence file is:

- **`D:\QM\Reports\ops\stage_b_evidence_20260428.md`** (Board-Advisor-authored, 43 lines) — covers pre-flight (path size + file count + free space), pre-conditions (T1 stage, T2-T5 mirror, .DWX `spec_ok`), execution (PowerShell `Remove-Item`), post-flight (path absence + free space delta), reversibility (TDS re-download path), and open follow-ups (this DL + DEVOPS-010 orphan cleanup).

The evidence file is on the Reports drive and is **not** committed to Git (Reports is the runtime artifact tree, not source). The path is the durable reference; the file's contents are reproduced inline above for the canonical retention metrics.

## Cross-links

- **Predecessor in retention policy:** [`2026-04-27_framework_artifact_retention_policy.md`](./2026-04-27_framework_artifact_retention_policy.md) — the framework-build / approved-binaries retention rule. DL-037 is the same family of decision (retention policy → reclaim) but at the dataset layer (TDS source CSVs) instead of the build-artifact layer.
- **Source / driver:** [QUA-297](/QUA/issues/QUA-297) action H — OWNER 2026-04-28 audit. Board Advisor wake [comment 04ed90b1](/QUA/issues/QUA-297#comment-04ed90b1-b12b-458a-8fb9-c9fb250897f8) 2026-04-28 06:36 local relayed OWNER's "Stage B Go!" + posted execution evidence inline.
- **Authority boundary cross-ref:** [DL-025](./DL-025_t6_deploy_boundary_refinement.md) — referenced only to record that Stage B is *outside* the DL-025 scope (non-T6). Not authority basis.
- **Authority boundary cross-ref:** [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) — referenced only to record that destructive disk operations are *outside* the DL-023 scope. Not authority basis. CEO correctly held back execution.
- **Approval audit record:** Paperclip approval thread `7ac36dbb-e4d0-473d-ad3c-c60de4582722` (filed by CEO heartbeat 7 on QUA-297 / QUA-311 surface). Status: `pending`, bypassed by OWNER+Board-Advisor manual execution. Disposition follow-up: CEO heartbeat to close or annotate.
- **Recording task:** [QUA-311](/QUA/issues/QUA-311) — this DL entry's authoring task.
- **Registry:** [`decisions/REGISTRY.md`](./REGISTRY.md) — DL-037 row.
- **Evidence file:** `D:\QM\Reports\ops\stage_b_evidence_20260428.md` (Board Advisor, not in Git).
- **Adjacent open reclaim (informational, not in scope of DL-037):** evidence file open follow-up notes that DEVOPS-010 orphan cleanup `D:\QM\_recovery_orphans_20260426\` (~24 GB) is auto-eligible 2026-04-28 ~08:10 local. That is a separate operation under DEVOPS-010's policy and gets its own audit trail — DL-037 does not authorise it.

## DL-027 propagation classification

`reference_only` — no agent prompt body changes; this is a one-shot recorded reclaim, not a recurring convention. Future similar reclaims should follow the same pattern (OWNER directive → Board Advisor or CEO execution → DL recording with evidence-file pointer), but no agent's BASIS needs to be patched to enforce that.

## Acceptance evidence

- [x] DL-037 entry filed (this document)
- [x] `decisions/REGISTRY.md` row added (DL-037 between DL-036 and the next future allocation)
- [x] Evidence file `D:\QM\Reports\ops\stage_b_evidence_20260428.md` cited
- [x] Approval thread `7ac36dbb-e4d0-473d-ad3c-c60de4582722` referenced with disposition note
- [x] QUA-297 action H + Board Advisor [comment 04ed90b1](/QUA/issues/QUA-297#comment-04ed90b1-b12b-458a-8fb9-c9fb250897f8) cross-linked
- [ ] CEO heartbeat to surface approval-thread disposition on `7ac36dbb` (close or annotate as bypassed)

## Boundary reminder

DL-037 is **recording-only**. It does not authorise re-execution of Stage B (Stage B is one-shot — the directory is gone), it does not authorise touching any other retention path, and it does not extend to T6 in any way. **T6 OFF LIMITS** as ever — neither this DL nor the underlying OWNER directive on Stage B says anything about live trading deploy. Future destructive disk operations remain OWNER-gated direct, with the same Paperclip-approval-thread + execution-evidence pattern as the audit trail.

— Recorded by Documentation-KM 2026-04-28 per [DL-027](./DL-027_basis_active_diff_propagation_rule.md) BASIS-active diff propagation rule and [DL-026](./2026-04-27_commit_hash_in_close_out_rule.md) commit-hash-in-close-out rule. Driving authority: OWNER directive 2026-04-28 06:35 local; executor: Board Advisor.
