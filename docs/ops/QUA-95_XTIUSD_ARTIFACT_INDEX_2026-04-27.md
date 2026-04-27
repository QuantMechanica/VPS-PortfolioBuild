# QUA-95 XTIUSD Artifact Index (2026-04-27)

Issue: `QUA-95`  
Status recommendation: `blocked` (`defer`)

## Canonical status package

- Blocker JSON:
  - `docs/ops/QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
- Handoff markdown:
  - `docs/ops/QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.md`
- Handoff structured JSON:
  - `docs/ops/QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.json`
- Integrity manifest:
  - `docs/ops/QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.sha256`
- Ready-to-post blocked summary:
  - `docs/ops/QUA-95_BLOCKED_COMMENT_2026-04-27.md`
- Task installer smoke evidence:
  - `docs/ops/QUA-95_BLOCKER_REFRESH_TASK_SMOKE_2026-04-27.md`
- Task install record:
  - `docs/ops/QUA-95_BLOCKER_REFRESH_TASK_INSTALL_2026-04-27.md`

## Investigation + evidence trail

- Investigation:
  - `lessons-learned/2026-04-27_qua95_xtiusd_verifier_failure_investigation.md`
- Rerun disposition JSON:
  - `lessons-learned/evidence/2026-04-27_qua95_xtiusd_rerun_evidence.json`
- Preflight/chunked probe:
  - `lessons-learned/evidence/2026-04-27_qua95_xtiusd_probe.md`
  - `lessons-learned/evidence/2026-04-27_qua95_xtiusd_chunked_probe.json`
  - `lessons-learned/evidence/2026-04-27_qua95_xtiusd_chunked_probe_v2.json`
- Source-vs-custom API probe:
  - `lessons-learned/evidence/2026-04-27_qua95_xtiusd_source_vs_custom_api_probe.md`
- Custom visibility probe:
  - `lessons-learned/evidence/2026-04-27_qua95_xtiusd_custom_visibility_probe.md`
  - `lessons-learned/evidence/2026-04-27_qua95_xtiusd_custom_visibility_probe.json`
  - `lessons-learned/evidence/2026-04-27_qua95_xtiusd_custom_visibility_probe_after_warmup.json`
- Scope matrix:
  - `lessons-learned/evidence/2026-04-27_qua95_custom_visibility_scope_matrix.md`
  - `lessons-learned/evidence/2026-04-27_qua95_custom_visibility_scope_matrix.json`
- Warm-up retry evidence:
  - `lessons-learned/evidence/2026-04-27_qua95_xtiusd_warmup_attempt.md`

## Operational scripts

- Visibility probe:
  - `infra/scripts/probe_custom_symbol_visibility.py`
- Handoff integrity check:
  - `infra/scripts/Test-QUA95HandoffIntegrity.ps1`
- Blocked summary generator:
  - `infra/scripts/Write-QUA95BlockedSummary.ps1`
- Task runner (scheduled execution target):
  - `infra/scripts/Run-QUA95BlockerRefresh.ps1`

## Verification commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95HandoffIntegrity.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Write-QUA95BlockedSummary.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-VerifyDisposition.ps1 -IssueId QUA-95 -Symbol XTIUSD.DWX
```

## Unblock owners

1. `runtime_custom_symbol_owner`
- Restore `XTIUSD.DWX` M1 bars visibility in T1 runtime (`copy_rates_range`/`copy_rates_from_pos` non-zero).

2. `verifier_implementation_owner`
- After runtime recovery, rerun verifier and confirm `bars_got > 0` with aligned tail.
