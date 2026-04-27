# QUA-95 XTIUSD Verifier Handoff (2026-04-27)

Issue: `QUA-95` (DEVOPS-004 child)  
Scope: investigate verifier failure for `XTIUSD.DWX` only.

## Decision

- **XTIUSD-specific status: BLOCKED / DEFER**
- Acceptance target is still unmet:
  - `bars_got=0`
  - tail mismatch remains (`tail_shortfall_seconds=7141.322`)
- Read-only MT5 warm-up retry did not recover custom-symbol bars visibility.

## Recommended issue transition

- Set `QUA-95` to **blocked**.

## Unblock owners and actions

1. Runtime/custom-symbol owner (T1 DWX runtime)
- Action: restore `XTIUSD.DWX` M1 bars visibility in MT5 runtime (`copy_rates_range`/`copy_rates_from_pos` must return non-zero).

2. Verifier implementation owner (`D:\QM\mt5\T1\dwx_import\verify_import.py`)
- Action: keep bars-path hardening and rerun verification after runtime recovery.
- Close condition: `bars_got > 0` and aligned tail for `XTIUSD.DWX`.

## Canonical branch payload

- Branch: `qua95-clean`
- Worktree: `C:\QM\worktrees\qua95-clean`
- Ordered commits:
  1. `87a68a4` docs(devops): capture QUA-95 XTIUSD verifier rerun disposition
  2. `d1bfe30` docs(devops): add QUA-95 XTIUSD preflight/chunked probe evidence
  3. `b972948` docs(devops): isolate QUA-95 custom-vs-source bars API boundary
  4. `2a58f09` infra(devops): add custom-symbol visibility probe for QUA-95
  5. `d0dc820` docs(devops): add QUA-95 custom visibility scope matrix
  6. `06438e4` docs(devops): record failed QUA-95 warmup recovery and rerun

Cherry-pick block:

```powershell
git cherry-pick 87a68a4 d1bfe30 b972948 2a58f09 d0dc820 06438e4
```

## Evidence pointers

- Investigation log: `lessons-learned/2026-04-27_qua95_xtiusd_verifier_failure_investigation.md`
- Rerun evidence JSON: `lessons-learned/evidence/2026-04-27_qua95_xtiusd_rerun_evidence.json`
- Warm-up attempt: `lessons-learned/evidence/2026-04-27_qua95_xtiusd_warmup_attempt.md`
- Custom visibility probe: `infra/scripts/probe_custom_symbol_visibility.py`
- Scope matrix: `lessons-learned/evidence/2026-04-27_qua95_custom_visibility_scope_matrix.md`
- Artifact index: `docs/ops/QUA-95_XTIUSD_ARTIFACT_INDEX_2026-04-27.md`
- Task install proof: `docs/ops/QUA-95_BLOCKER_REFRESH_TASK_INSTALL_2026-04-27.md`
- Task health install proof: `docs/ops/QUA-95_TASK_HEALTH_TASK_INSTALL_2026-04-27.md`
- Infra audit integration proof: `docs/ops/QUA-95_INFRA_AUDIT_INTEGRATION_2026-04-27.md`
- Gate snapshot: `docs/ops/QUA-95_GATE_DECISION_2026-04-27.json`
- Structured handoff JSON: `docs/ops/QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.json`
- Structured blocker status JSON: `docs/ops/QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
- Integrity manifest (SHA256): `docs/ops/QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.sha256`
