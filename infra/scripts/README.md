# Infra Scripts Notes

## `dwx_hourly_check.py`

- `spec_ok` is now evaluated by one shared helper (`is_symbol_spec_ok`) for both:
  - readiness gate (`spec_bad` aggregation)
  - per-symbol readiness report row (`spec_ok` column)
- Verifier output is parsed by `summarize_verify_failures(...)` to detect systemic
  runtime patterns before opening per-symbol investigations:
  - `systemic_zero_bars`: >= 10 FAIL rows where all have `bars expected > 0` and `got=0`
  - `systemic_zero_mid_ticks`: >= 10 FAIL rows where all have `mid_ticks_5min=0`
  - These are logged as verifier/runtime conditions, not symbol-specific corruption.
  - Parser contract covers real verifier row shapes with leading verdict spacing
    (for example `[ FAIL_tail_bars] XAGUSD.DWX: ...` and
    `[FAIL_tail_mid_bars] XNGUSD.DWX: ...`) and trailing fields.
- One-command triage on a captured verifier log:
  - `python -c "from pathlib import Path;import importlib.util as u;p=Path(r'C:\QM\repo\infra\scripts\dwx_hourly_check.py');s=u.spec_from_file_location('m',p);m=u.module_from_spec(s);s.loader.exec_module(m);t=Path(r'C:\QM\repo\infra\smoke\verify_import_run_2026-04-27_qua19.log').read_text(encoding='utf-8',errors='replace');print(m.summarize_verify_failures(t))"`
- Criterion:
  - `custom.trade_tick_value > 0`
  - `broker.trade_tick_value > 0`
  - `abs(custom.tv - broker.tv) / broker.tv < 0.05`
- Phase-B staging now includes CSV tail-alignment gate:
  - compares tick CSV tail vs M1 CSV tail (`MAX_CSV_TAIL_GAP_HOURS=1.0`)
  - symbols with stale/misaligned tails are deferred and not queued for import
  - already-imported symbols still emit a warning when tails are misaligned
  - when mismatches exist, hourly writes desktop nudge file
    `C:\Users\Administrator\Desktop\CSV_TAIL_MISMATCH.txt` listing affected symbols;
    file is removed automatically once no mismatches are detected
- No `tvp` / `tvl` fields are used for gate decisions.

## `verify_import_preflight_probe.py`

- Non-production helper for targeted verifier investigation on one symbol.
- Compares MT5 read paths directly:
  - `copy_ticks_range(...)` window counts (head/mid/tail)
  - `copy_ticks_from(...)` window counts (head/mid/tail)
  - `copy_rates_range(...)` bar count over sidecar M1 range
- Includes lightweight pre-flight + retries to reduce session/cache timing noise.
- Example:
  - `python C:\QM\repo\infra\scripts\verify_import_preflight_probe.py --symbol XAUUSD.DWX`

## `check_dwx_csv_tail_alignment.py`

- Fast DWX CSV preflight: compares tail timestamp of tick CSV vs M1 CSV.
- Use before `prepare_import.py`/verifier runs to catch stale or internally
  misaligned exports.
- Exit codes:
  - `0`: aligned within threshold
  - `1`: misaligned/stale beyond threshold
  - `2`: missing files
  - `3`: empty tails
- Example:
  - `python C:\QM\repo\infra\scripts\check_dwx_csv_tail_alignment.py --symbol XAUUSD --max-gap-hours 1 --json-out C:\QM\repo\lessons-learned\evidence\2026-04-27_qua93_xauusd_tail_alignment_check.json`

## `verify_import_candidate.py`

- Candidate (non-production) verifier behavior for handoff testing.
- Proposed deltas vs live verifier:
  - mid/tail probes use `copy_ticks_from(...)` windows
  - bounded tail tolerance (`--tail-basis source --tail-tol-ms 1000` used in QUA-95 proof flow)
  - bars fallback counts from `copy_rates_from_pos(...)` when range reads are zero/invalid
- Example:
  - `python C:\QM\repo\infra\scripts\verify_import_candidate.py --symbol XAUUSD.DWX`

## `patches/verify_import_candidate_port.patch`

- Unified diff artifact from live verifier:
  - `D:\QM\mt5\T1\dwx_import\verify_import.py`
  - to candidate logic in `infra/scripts/verify_import_candidate.py`
- Purpose: accelerate owner-side review/apply of tested read-path hardening.
- Generated in this issue heartbeat; regenerate by diffing the same two files when either side changes.

## `probe_verify_rates_span.py`

- Read-only MT5 probe for verifier investigations.
- Compares one-shot `copy_rates_range(...)` across the full sidecar span vs
  chunked `copy_rates_range(...)` windows.
- Also prints a short tail-window sample (`--tail-hours`, default `24`) and
  symbol metadata (`selected/visible/custom/path`) to distinguish range-query
  param issues from "no bars visible" runtime conditions.
- Use to confirm/quantify range-query limits (`Invalid params` / empty results)
  before classifying a symbol as corrupted.
- Default target is `WS30.DWX`; span comes from latest
  `imports\\done\\*_<symbol>.import.txt`.

## `probe_custom_symbol_visibility.py`

- Read-only MT5 probe that compares a custom symbol (for example `XTIUSD.DWX`)
  against its broker/source symbol (for example `XTIUSD`).
- Uses both bars APIs:
  - `copy_rates_range(...)`
  - `copy_rates_from_pos(...)`
- Also captures recent ticks (`copy_ticks_from(...)`) for context.
- Emits `isolated_custom_bars_visibility_failure=true` when:
  - source bars are available, and
  - custom bars are zero/failing in the same session.
- Exit codes:
  - `0`: no isolated custom-bars failure detected
  - `1`: isolated custom-bars visibility failure detected
  - `2`: MT5 init failed
- Example:
  - `python C:\QM\repo\infra\scripts\probe_custom_symbol_visibility.py --target XTIUSD.DWX --json-out C:\QM\repo\lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe.json`

## `Test-QUA95HandoffIntegrity.ps1`

- Verifies SHA256 integrity for the QUA-95 handoff package files listed in:
  - `docs\ops\QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.sha256`
- Fails (`exit 1`) when any file is missing, a hash mismatches, or manifest rows are malformed.
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95HandoffIntegrity.ps1`

## `Write-QUA95BlockedSummary.ps1`

- Renders a concise blocked-status markdown summary from:
  - `docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
- Default output:
  - `docs\ops\QUA-95_BLOCKED_COMMENT_2026-04-27.md`
- Useful for posting/attaching a deterministic issue status comment.
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Write-QUA95BlockedSummary.ps1`

## `Update-QUA95BlockedAssertion.ps1`

- Regenerates:
  - `docs\ops\QUA-95_BLOCKED_STATE_ASSERTION_2026-04-27.md`
- Uses canonical inputs:
  - `docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
  - `docs\ops\QUA-95_GATE_DECISION_2026-04-27.json`
- Keeps assertion markdown synchronized with latest blocked-state snapshot.
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Update-QUA95BlockedAssertion.ps1`

## `Update-QUA95BlockerStatus.ps1`

- Refreshes `docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json` from latest rerun evidence:
  - `lessons-learned\evidence\2026-04-27_qua95_xtiusd_rerun_evidence.json`
- Updates symbol verdict, bars/tail fields, disposition, acceptance flag, and check timestamp.
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Update-QUA95BlockerStatus.ps1`

## `Install-QUA95BlockerRefreshTask.ps1`

- Idempotently installs a Windows Scheduled Task that runs:
  1. `Invoke-VerifyDisposition.ps1` (`QUA-95`, `XTIUSD.DWX`)
  2. `Update-QUA95BlockerStatus.ps1`
  3. `Write-QUA95BlockedSummary.ps1`
  4. `Get-QUA95GateDecision.ps1` (writes gate snapshot; no-fail mode)
  5. `Test-QUA95HandoffIntegrity.ps1`
- Defaults:
  - task name: `QM_QUA95_BlockerRefresh`
  - interval: `60` minutes
  - principal: `SYSTEM` (highest)
  - log: `C:\QM\repo\infra\smoke\qua95_blocker_refresh_task.log`
  - python: resolved at install time via `Get-Command python` (pass `-PythonExe <fullpath>` if needed)
- Preview mode (no task registration):
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA95BlockerRefreshTask.ps1 -PreviewOnly`
- Validation note:
  - For SYSTEM tasks, prefer `schtasks /Query /TN "<task-name>" /V /FO LIST` as a visibility check when `Get-ScheduledTask` does not enumerate the task in the current shell context.
  - If task runs fail with `python not recognized`, reinstall with explicit `-PythonExe` so SYSTEM does not depend on PATH inheritance.

## `Run-QUA95BlockerRefresh.ps1`

- Task runner invoked by Scheduler for QUA-95 refresh chain.
- Executes and logs:
  1. `Invoke-VerifyDisposition.ps1`
  2. `Update-QUA95BlockerStatus.ps1`
  3. `Write-QUA95BlockedSummary.ps1`
  4. `Get-QUA95GateDecision.ps1 -OutPath docs\ops\QUA-95_GATE_DECISION_2026-04-27.json -NoFail`
  5. `Update-QUA95BlockedAssertion.ps1`
  6. `New-QUA95IssueTransitionPayload.ps1`
  7. `Test-QUA95IssueTransitionPayload.ps1`
  8. `Test-QUA95BlockedInvariant.ps1`
  9. `Update-QUA95UnblockReadiness.ps1`
  10. `Write-QUA95UnblockReadinessSummary.ps1`
  11. `monitoring/Test-QUA95AutomationHealth.ps1 -SkipRefreshLastResultCheck -SkipTaskHealthCheck`
  12. `Update-QUA95AuditSignal.ps1`
  13. `Test-QUA95AuditSignal.ps1`
  14. Refreshes `QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.sha256`
  15. `Test-QUA95HandoffIntegrity.ps1`
  16. `Update-QUA95OpsBundleManifest.ps1` (pre-suite resync)
  17. `Write-QUA95OpsSuiteSnapshot.ps1 -SkipBlockerTaskHealthCheck`
  18. `Update-QUA95OpsBundleManifest.ps1` (post-suite resync)
- Enforces non-zero exit handling for each step; task fails when any step exits non-zero.
- Log append writes are lock-tolerant (`Add-Content` retry loop) so concurrent
  writer contention does not crash the runner.
- Command-output logging is null-safe (steps that emit no stdout/stderr do not
  fail the run).
- Default log:
  - `C:\QM\repo\infra\smoke\qua95_blocker_refresh_task.log`

## `Get-QUA95GateDecision.ps1`

- Reads `docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json` and emits a deterministic transition payload.
- Reads custom-visibility evidence (`2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json`) and
  sets `runtime_visibility_recovered=true` when target bars are visible and isolated-failure is false.
- When runtime visibility is recovered, removes `runtime_custom_symbol_owner` from emitted `unblock_owners`.
- Exit code contract:
  - `0`: `recommended_state=clear`
  - `3`: `recommended_state=blocked`
- Optional:
  - `-OutPath <relative-path>` writes JSON payload to file.
  - `-NoFail` forces exit `0` (for scheduled refresh pipelines).
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Get-QUA95GateDecision.ps1`

## `New-QUA95IssueTransitionPayload.ps1`

- Builds a deterministic issue-transition payload from canonical QUA-95 artifacts:
  - `docs\ops\QUA-95_GATE_DECISION_2026-04-27.json`
  - `docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
  - `docs\ops\QUA-95_BLOCKED_COMMENT_2026-04-27.md`
- Writes:
  - `docs\ops\QUA-95_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json`
- Payload includes:
  - target status (`blocked` or `in_progress`)
  - reason/disposition/acceptance fields
  - current bars/tail values
  - unblock owners from gate snapshot (runtime owner auto-cleared when runtime visibility is recovered)
  - deterministic next-action text reflecting runtime recovery state
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\New-QUA95IssueTransitionPayload.ps1`

## `Test-QUA95IssueTransitionPayload.ps1`

- Validates `docs\ops\QUA-95_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json`
  against canonical inputs:
  - `docs\ops\QUA-95_GATE_DECISION_2026-04-27.json`
  - `docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
- Checks issue id, status mapping, disposition, bars/tail fields, last-checked timestamp,
  and unblock-owner count.
- Exit codes:
  - `0`: payload is consistent
  - `1`: payload mismatch or missing input
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95IssueTransitionPayload.ps1`

## `Test-QUA95BlockedInvariant.ps1`

- Enforces blocked/defer state invariants from canonical artifacts:
  - `docs\ops\QUA-95_GATE_DECISION_2026-04-27.json`
  - `docs\ops\QUA-95_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json`
- Invariant:
  - if `bars_got <= 0`, gate + transition must remain `blocked` + `defer`.
- Exit codes:
  - `0`: invariant satisfied
  - `1`: invariant violated
  - `2`: required artifact missing
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95BlockedInvariant.ps1`

## `Test-QUA95UnblockReadiness.ps1`

- Validates unblock-readiness artifact against blocker status:
  - `docs\ops\QUA-95_UNBLOCK_READINESS_2026-04-27.json`
  - `docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
- Checks:
  - lag vs `last_checked_local` within threshold
  - non-empty `unblock_owners`
  - `ready_to_unblock` is not true while `bars_got <= 0`
- Exit codes:
  - `0`: readiness artifact is consistent
  - `1`: readiness drift/missing artifact
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95UnblockReadiness.ps1`

## `Update-QUA95UnblockReadiness.ps1`

- Writes unblock-readiness snapshot from canonical gate/blocker/transition artifacts:
  - `docs\ops\QUA-95_GATE_DECISION_2026-04-27.json`
  - `docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
  - `docs\ops\QUA-95_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json`
- Output:
  - `docs\ops\QUA-95_UNBLOCK_READINESS_2026-04-27.json`
- Fields include:
  - `ready_to_unblock`
  - `unmet_criteria`
  - `unblock_owners`
- Current readiness contract:
  - `ready_to_unblock=true` when acceptance is met, bars are positive, gate is `clear`, and transition status is `in_progress`
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Update-QUA95UnblockReadiness.ps1`

## `Write-QUA95UnblockReadinessSummary.ps1`

- Writes deterministic markdown summary from:
  - `docs\ops\QUA-95_UNBLOCK_READINESS_2026-04-27.json`
- Output:
  - `docs\ops\QUA-95_UNBLOCK_READINESS_SUMMARY_2026-04-27.md`
- Includes:
  - `ready_to_unblock`, current blocker metrics, unmet criteria, unblock owners/actions
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Write-QUA95UnblockReadinessSummary.ps1`

## `Update-QUA95AuditSignal.ps1`

- Produces QUA-95-focused audit signal snapshot from:
  - `infra/reports/infra_audit_latest.json`
- Output:
  - `docs/ops/QUA-95_AUDIT_SIGNAL_2026-04-27.json`
- Includes:
  - total audit issues
  - QUA-95 issues vs non-QUA95 issues counts
  - QUA-95 check statuses
  - issue-name breakdown arrays for both QUA-95 and non-QUA95 issues
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Update-QUA95AuditSignal.ps1`

## `Test-QUA95AuditSignal.ps1`

- Validates the QUA-95-focused audit signal snapshot:
  - `docs\ops\QUA-95_AUDIT_SIGNAL_2026-04-27.json`
- Checks core fields and counts:
  - `issue == QUA-95`
  - `qua95_checks` array/count consistency
  - `qua95_*` prefix integrity for QUA-95 check/issue names
  - non-QUA95 issue-name prefix integrity
  - non-negative issue counters
  - expected check-count fields are present and valid
- Exit codes:
  - `0`: audit signal is valid
  - `1`: missing/invalid signal artifact
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95AuditSignal.ps1`

## `Test-QUA95DirectVerifierProof.ps1`

- Validates direct-verifier proof artifacts:
  - `lessons-learned\evidence\2026-04-27_qua95_xtiusd_direct_verify_rerun.json`
  - `docs\ops\QUA-95_DIRECT_VERIFIER_RERUN_2026-04-27.md`
- Cross-checks with blocker status:
  - `docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
- Checks:
  - issue/symbol identity
  - evidence freshness (`captured_at_local`) within max-age window (`-MaxEvidenceAgeMinutes`, default `240`)
  - raw log path exists, is absolute, and log content contains symbol + FAIL row (and verdict token when provided)
  - recommended/disposition consistency with acceptance semantics:
    `bars_positive && abs(tail_delta_ms) <= tail_tolerance_ms` => `clear/clear`, else `blocked/defer`
  - proof markdown contains expected heading/symbol
- Exit codes:
  - `0`: proof artifacts are consistent
  - `1`: drift/missing artifact detected
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95DirectVerifierProof.ps1`

## `Test-QUA95CustomVisibilityProof.ps1`

- Validates custom-visibility proof artifacts:
  - `lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json`
  - `docs\ops\QUA-95_CUSTOM_VISIBILITY_RERUN_2026-04-27.md`
- Cross-checks with blocker status:
  - `docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
- Checks:
  - evidence freshness (`captured_at_local`) within max-age window (`-MaxEvidenceAgeMinutes`, default `240`; falls back to evidence file write-time for legacy artifacts)
  - target/source symbol identity
  - non-negative bars counters
  - blocked/defer consistency when isolated custom visibility failure is true
  - proof markdown contains expected heading/target symbol
- Exit codes:
  - `0`: proof artifacts are consistent
  - `1`: drift/missing artifact detected
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95CustomVisibilityProof.ps1`

## `Test-QUA95FailureSignature.ps1`

- Validates QUA-95 blocked systemic failure signature coherence across:
  - `lessons-learned\evidence\2026-04-27_qua95_xtiusd_direct_verify_rerun.json`
  - `lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json`
  - `docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
- Checks (when blocker remains `blocked`):
  - `mid_ticks_5min > 0`
  - `bars_one_shot <= 0` and `bars_chunked <= 0`
  - `tail_delta_ms < 0` and `tail_shortfall_seconds >= MinTailShortfallSeconds` (default `3600`)
  - `isolated_custom_bars_visibility_failure == true`
  - `target` bars absent while `source` bars remain visible
  - blocker disposition remains `defer` with `bars_got <= 0`
- Behavior:
  - if blocker state is no longer `blocked`, check exits `0` with `signature_check=skipped`.
- Exit codes:
  - `0`: failure signature is coherent (or skipped for non-blocked state)
  - `1`: signature mismatch/drift detected
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95FailureSignature.ps1`

## `Test-QUA95EvidenceCohesion.ps1`

- Validates timestamp cohesion across canonical QUA-95 evidence artifacts:
  - `lessons-learned\evidence\2026-04-27_qua95_xtiusd_direct_verify_rerun.json`
  - `lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json`
  - `docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
- Checks:
  - direct/custom/blocker identity fields
  - pairwise timestamp skew within `-MaxPairSkewMinutes` (default `20`)
  - uses custom-evidence file write-time fallback when `captured_at_local` is absent in legacy artifacts
- Exit codes:
  - `0`: evidence timestamps are coherent
  - `1`: skew/drift/missing data detected
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95EvidenceCohesion.ps1`

## `Test-QUA95HeartbeatCustomVisibility.ps1`

- Validates blocked-heartbeat `custom_visibility` section against canonical evidence:
  - `docs\ops\QUA-95_BLOCKED_HEARTBEAT_2026-04-27.json`
  - `lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json`
- Checks:
  - heartbeat issue identity
  - heartbeat custom-visibility section exists
  - isolated-failure flag + source/target bars counters match evidence
- Exit codes:
  - `0`: heartbeat custom-visibility section is coherent
  - `1`: missing/invalid/mismatched data
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95HeartbeatCustomVisibility.ps1`

## `Test-QUA95CanonicalSnapshot.ps1`

- Validates canonical snapshot summary artifact:
  - `docs\ops\QUA-95_CANONICAL_SNAPSHOT_2026-04-27.json`
- Cross-checks against:
  - `docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json`
  - `docs\ops\QUA-95_AUDIT_SIGNAL_2026-04-27.json`
  - `lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json`
  - `docs\ops\QUA-95_CUSTOM_VISIBILITY_RERUN_2026-04-27.md`
- Checks:
  - snapshot identity/flow fields
  - step exit codes (including direct verifier proof, custom visibility proof, heartbeat custom-visibility check, and task-health wiring)
  - blocker state/disposition/bars consistency
  - audit-signal count consistency
- Exit codes:
  - `0`: snapshot is consistent
  - `1`: missing/invalid/mismatched snapshot
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95CanonicalSnapshot.ps1`

## `Test-QUA95CanonicalSnapshotFreshness.ps1`

- Validates canonical snapshot freshness:
  - `docs\ops\QUA-95_CANONICAL_SNAPSHOT_2026-04-27.json`
- Checks:
  - issue/flow identity
  - `generated_at_local` parseability and non-future timestamp
  - age within `-MaxAgeMinutes` (default `180`)
- Exit codes:
  - `0`: snapshot is fresh
  - `1`: stale/invalid snapshot
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95CanonicalSnapshotFreshness.ps1`

## `Test-QUA95TaskHealthActionWiring.ps1`

- Validates scheduler action-argument wiring for:
  - `QM_QUA95_TaskHealth_15min`
- Ensures action args include:
  - `-TransitionPayloadCheckScript`
  - `-UnblockReadinessCheckScript`
  - `-AuditSignalCheckScript`
  - `-UnblockOwnerConsistencyCheckScript`
  - `-CanonicalSnapshotCheckScript`
  - `-CanonicalSnapshotFreshnessCheckScript`
  - `-DirectVerifierProofCheckScript`
  - `-CustomVisibilityProofCheckScript`
  - `-EvidenceCohesionCheckScript`
  - `-FailureSignatureCheckScript`
  - `-BlockerRefreshActionWiringCheckScript`
  - `-HeartbeatCustomVisibilityCheckScript`
- Exit codes:
  - `0`: wiring is present
  - `2`: task missing or required arg fragment missing
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95TaskHealthActionWiring.ps1`

## `Test-QUA95BlockerRefreshActionWiring.ps1`

- Validates scheduler action-argument wiring for:
  - `QM_QUA95_BlockerRefresh`
- Ensures task action uses PowerShell and includes required fragments:
  - `Run-QUA95BlockerRefresh.ps1`
  - `-RepoRoot`
  - `-LogPath`
  - `-TaskName`
  - `-PythonExe`
- Validates `-PythonExe` value:
  - present as quoted argument value
  - absolute path
  - target executable exists
- Exit codes:
  - `0`: wiring is present
  - `2`: task missing or required fragment missing
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95BlockerRefreshActionWiring.ps1`

## `Test-QUA95UnblockReadinessSummary.ps1`

- Validates markdown summary consistency with unblock-readiness JSON:
  - `docs\ops\QUA-95_UNBLOCK_READINESS_2026-04-27.json`
  - `docs\ops\QUA-95_UNBLOCK_READINESS_SUMMARY_2026-04-27.md`
- Checks:
  - `ready_to_unblock` value
  - `bars_got`, `tail_shortfall_seconds`
  - unblock owner keys
- Exit codes:
  - `0`: summary is consistent
  - `1`: summary drift detected
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95UnblockReadinessSummary.ps1`

## `Test-QUA95UnblockOwnerConsistency.ps1`

- Validates unblock-owner/action consistency across:
  - `docs\ops\QUA-95_UNBLOCK_READINESS_2026-04-27.json`
  - `docs\ops\QUA-95_GATE_DECISION_2026-04-27.json`
  - `docs\ops\QUA-95_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json`
  - `docs\ops\QUA-95_UNBLOCK_READINESS_SUMMARY_2026-04-27.md`
- Checks:
  - normalized owner/action pairs match across JSON artifacts
  - summary markdown includes each owner key and required action string
- Exit codes:
  - `0`: owner/action data is coherent
  - `1`: owner/action drift detected
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95UnblockOwnerConsistency.ps1`

## `Test-QUA95OpsSuite.ps1`

- Single-command QUA-95 ops sanity suite.
- Runs:
  1. `Test-QUA95OpsBundleManifest.ps1`
  2. `Test-QUA95CanonicalSnapshot.ps1`
  3. `Test-QUA95CanonicalSnapshotFreshness.ps1`
  4. `Test-QUA95HandoffIntegrity.ps1`
  5. `Test-QUA95IssueTransitionPayload.ps1`
  6. `Test-QUA95BlockedInvariant.ps1`
  7. `Test-QUA95UnblockReadiness.ps1`
  8. `Test-QUA95UnblockOwnerConsistency.ps1`
  9. `Test-QUA95UnblockReadinessSummary.ps1`
  10. `Test-QUA95AuditSignal.ps1`
  11. `Test-QUA95DirectVerifierProof.ps1`
  12. `Test-QUA95CustomVisibilityProof.ps1`
  13. `Test-QUA95EvidenceCohesion.ps1`
  14. `Test-QUA95FailureSignature.ps1`
  15. `Test-QUA95HeartbeatCustomVisibility.ps1`
  16. `Test-QUA95TaskHealthActionWiring.ps1`
  17. `Test-QUA95BlockerRefreshActionWiring.ps1`
  18. `monitoring/Test-QUA95BlockedHeartbeatWrapper.ps1`
  19. `monitoring/Test-QUA95BlockerTaskHealth.ps1`
- Emits JSON summary to stdout and returns:
  - `0` when all checks pass
  - `2` when any check is critical
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95OpsSuite.ps1`

## `Test-QUA95OpsBundleManifest.ps1`

- Verifies SHA256 entries in:
  - `docs\ops\QUA-95_OPS_BUNDLE_2026-04-27.sha256`
- Confirms all listed blocked-ops artifacts are present and hash-consistent.
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA95OpsBundleManifest.ps1`

## `Write-QUA95OpsSuiteSnapshot.ps1`

- Runs `Test-QUA95OpsSuite.ps1` and persists the JSON output artifact.
- Defaults:
  - suite script: `infra\scripts\Test-QUA95OpsSuite.ps1`
  - output: `docs\ops\QUA-95_OPS_SUITE_2026-04-27.json`
- Automatically resyncs (pre and post run):
  - `docs\ops\QUA-95_OPS_BUNDLE_2026-04-27.sha256`
  to prevent pre-check and post-write manifest drift.
- Exit code mirrors suite result.
- Optional:
  - `-SkipBlockerTaskHealthCheck` to run the suite without the scheduler last-result gate check (used by refresh runner self-heal path).
  - `-SkipManifestResync` to skip post-write manifest refresh.
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Write-QUA95OpsSuiteSnapshot.ps1`

## `Update-QUA95OpsBundleManifest.ps1`

- Regenerates SHA256 manifest for core QUA-95 blocked ops artifacts.
- Default output:
  - `docs\ops\QUA-95_OPS_BUNDLE_2026-04-27.sha256`
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Update-QUA95OpsBundleManifest.ps1`

## `Invoke-QUA95BlockedHeartbeat.ps1`

- One-command heartbeat wrapper for blocked QUA-95 operations.
- Runs, by default:
  1. `Run-QUA95BlockerRefresh.ps1`
  2. `Invoke-InfraAudit.ps1`
  3. `Update-QUA95BlockedAssertion.ps1`
  4. `Test-QUA95BlockedInvariant.ps1`
  5. `Update-QUA95UnblockReadiness.ps1`
  6. `Write-QUA95UnblockReadinessSummary.ps1`
  7. `monitoring/Test-QUA95AutomationHealth.ps1`
  8. `Update-QUA95AuditSignal.ps1`
  9. `Test-QUA95AuditSignal.ps1`
  10. `Update-QUA95OpsBundleManifest.ps1` (pre-suite resync)
  11. `Write-QUA95OpsSuiteSnapshot.ps1 -SkipBlockerTaskHealthCheck`
  12. `Update-QUA95OpsBundleManifest.ps1` (post-suite resync)
- Reads canonical outputs and writes consolidated summary:
  - `docs\ops\QUA-95_BLOCKED_HEARTBEAT_2026-04-27.json`
- Summary includes:
  - gate state snapshot
  - infra-audit counts
  - audit-signal issue counts/names split (`qua95` vs `non_qua95`)
  - custom-visibility snapshot fields (isolated failure flag + source/target bars)
- Supports:
  - `-SkipRefresh` (audit-only heartbeat)
  - `-SkipAudit` (refresh-only heartbeat)
- Companion validator:
  - `infra\monitoring\Test-QUA95BlockedHeartbeatWrapper.ps1`
  - default validator mode uses `-SkipRefresh -SkipAudit` and an automation-health self-check mode that skips scheduler last-result gates; pass `-RunRefresh` to include refresh execution.
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-QUA95BlockedHeartbeat.ps1`

## `Run-QUA95CanonicalSnapshot.ps1`

- One-command canonical QUA-95 blocked snapshot flow:
  1. `Run-QUA95DirectVerifierProof.ps1`
  2. `Run-QUA95CustomVisibilityProof.ps1`
  3. `Invoke-QUA95BlockedHeartbeat.ps1`
  4. `Test-QUA95HeartbeatCustomVisibility.ps1`
  5. `Test-QUA95TaskHealthActionWiring.ps1`
  6. `Update-QUA95OpsBundleManifest.ps1`
  7. `Test-QUA95OpsBundleManifest.ps1`
- Writes machine-readable run summary:
  - `docs\ops\QUA-95_CANONICAL_SNAPSHOT_2026-04-27.json`
- Purpose:
  - avoids post-heartbeat manifest drift by always finishing with manifest resync + verification.
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Run-QUA95CanonicalSnapshot.ps1`

## `Run-QUA95DirectVerifierProof.ps1`

- Runs direct verifier command for `XTIUSD.DWX`:
  - `python D:\QM\mt5\T1\dwx_import\verify_import.py --symbol XTIUSD.DWX --tail-basis source --tail-tol-ms 1000`
- Captures raw log under:
  - `infra\smoke\verify_import_direct_*_qua95.log`
- Writes durable proof artifacts:
  - `lessons-learned\evidence\2026-04-27_qua95_xtiusd_direct_verify_rerun.json`
  - `docs\ops\QUA-95_DIRECT_VERIFIER_RERUN_2026-04-27.md`
- Exit behavior:
  - script exits `0` when proof artifacts are written (even when verifier exits non-zero), and prints `verify_exit_code=<n>`.
- Acceptance semantics:
  - `recommended_state=clear` when `(bars_one_shot > 0 or bars_chunked > 0)` and `abs(tail_delta_ms) <= tail_tolerance_ms`.
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Run-QUA95DirectVerifierProof.ps1`

## `Run-QUA95CustomVisibilityProof.ps1`

- Runs custom-symbol visibility probe for `XTIUSD.DWX`:
  - `python C:\QM\repo\infra\scripts\probe_custom_symbol_visibility.py --target XTIUSD.DWX`
- Writes durable proof artifacts:
  - `lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_rerun.json`
  - `docs\ops\QUA-95_CUSTOM_VISIBILITY_RERUN_2026-04-27.md`
- Exit behavior:
  - script exits `0` when proof artifacts are written (even when probe exits non-zero), and prints `probe_exit_code=<n>`.
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Run-QUA95CustomVisibilityProof.ps1`

## `Run-QUA207XtiusdReimportRepair.ps1`

- Deterministic runtime repair flow for QUA-207 (`XTIUSD.DWX` bars visibility).
- Steps:
  1. choose latest archived `imports\done\*XTIUSD.DWX.import.txt` and resolve matching archived bins from sidecar-declared filenames
  2. compile and run `Delete_One_Custom_Symbol.mq5` via startup ini
  3. re-stage sidecar+bins into `MQL5\Files\imports\`
  4. temporarily disable `MQL5\Services\Import_DWX_Queue_Service.ex5` to avoid startup race/partial import
  5. run `Import_DWX_From_Bin` via startup ini
  6. restore queue-service ex5
  7. refresh custom-visibility proof (`Run-QUA95CustomVisibilityProof.ps1`)
- Safety:
  - T1-scoped (`D:\QM\mt5\T1`) by default
  - refuses T6 paths
  - single-symbol scope (`XTIUSD.DWX`) only
- Outputs:
  - `docs\ops\QUA-207_REIMPORT_REPAIR_XTIUSD_2026-04-27.json`
  - `docs\ops\QUA-207_REIMPORT_REPAIR_XTIUSD_2026-04-27.md`
- Exit codes:
  - `0`: runtime bars visibility restored (target bars available via range or pos probe)
  - `2`: not restored
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Run-QUA207XtiusdReimportRepair.ps1`

## `Test-QUA207RuntimeRestoreCompletion.ps1`

- Validates QUA-207 runtime-restore completion contract across canonical artifacts:
  - custom visibility evidence (`target bars visible`, `isolated_custom_bars_visibility_failure=false`)
  - gate decision (`runtime_visibility_recovered=true`)
  - owner lists in gate/transition/readiness (runtime owner removed, verifier owner present)
- Exit codes:
  - `0`: completion contract holds
  - `1`: mismatch detected
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA207RuntimeRestoreCompletion.ps1`

## `New-QUA207IssueTransitionPayload.ps1`

- Generates QUA-207 issue transition payload directly from current custom-visibility evidence.
- Writes:
  - `docs\ops\QUA-207_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json`
- Decision mapping:
  - `in_review` when runtime visibility is restored (`target bars visible` and `isolated_custom_bars_visibility_failure=false`)
  - `blocked` otherwise
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\New-QUA207IssueTransitionPayload.ps1`

## `Run-QUA207RuntimeCompletionHeartbeat.ps1`

- One-command QUA-207 runtime completion heartbeat.
- Runs:
  1. `New-QUA207IssueTransitionPayload.ps1`
  2. `Test-QUA207RuntimeRestoreCompletion.ps1`
- Writes summary:
  - `docs\ops\QUA-207_RUNTIME_HEARTBEAT_2026-04-27.json`
- Exit codes:
  - `0`: all steps passed
  - `2`: one or more steps failed
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Run-QUA207RuntimeCompletionHeartbeat.ps1`

## `Install-QUA207RuntimeHeartbeatTask.ps1`

- Idempotently installs a Scheduler task for periodic QUA-207 runtime heartbeat refresh.
- Defaults:
  - task name: `QM_QUA207_RuntimeHeartbeat_30min`
  - interval: `30` minutes
  - principal: `SYSTEM` (highest)
- Preview mode:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA207RuntimeHeartbeatTask.ps1 -PreviewOnly`

## `Remove-QUA207RuntimeHeartbeatTask.ps1`

- Idempotently removes scheduler task `QM_QUA207_RuntimeHeartbeat_30min`.
- Behavior:
  - returns `status=ok task_absent=<name>` when task does not exist
  - removes task without prompt when present
- Preview mode:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Remove-QUA207RuntimeHeartbeatTask.ps1 -PreviewOnly`

## `Run-QUA207OpsBundle.ps1`

- One-command QUA-207 maintenance bundle:
  1. `Run-QUA207RuntimeCompletionHeartbeat.ps1`
  2. `New-QUA207IssueComment.ps1`
  3. `New-QUA207BlockedOnVerifierSnapshot.ps1`
- Writes consolidated snapshot:
  - `docs\ops\QUA-207_OPS_BUNDLE_2026-04-27.json`
- Exit codes:
  - `0`: all steps passed
  - `2`: at least one step failed
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Run-QUA207OpsBundle.ps1`

## `New-QUA207BlockedOnVerifierSnapshot.ps1`

- Generates blocker snapshot when QUA-207 runtime scope is complete but verifier owner remains pending.
- Inputs:
  - custom visibility evidence JSON
  - QUA-207 transition payload JSON
- Writes:
  - `docs\ops\QUA-207_BLOCKED_ON_VERIFIER_2026-04-27.json`
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\New-QUA207BlockedOnVerifierSnapshot.ps1`

## `New-QUA207IssueComment.ps1`

- Generates ready-to-post QUA-207 issue comment markdown from:
  - QUA-207 transition payload JSON
  - custom-visibility evidence JSON
- Writes:
  - `docs\ops\QUA-207_ISSUE_COMMENT_2026-04-27.md`
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\New-QUA207IssueComment.ps1`

## `New-QUA208IssueTransitionPayload.ps1`

- Generates deterministic QUA-208 transition payload from canonical unblock artifacts:
  - direct verifier rerun evidence JSON
  - QUA-95 blocker status JSON
  - QUA-95 gate decision JSON
  - QUA-208 closeout markdown
- Writes:
  - `docs\ops\QUA-208_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json`
- Decision mapping:
  - `in_review` when acceptance is met, bars are positive, and tail delta is within tolerance
  - `blocked` otherwise
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\New-QUA208IssueTransitionPayload.ps1`

## `Test-QUA208IssueTransitionPayload.ps1`

- Validates QUA-208 transition payload consistency against canonical evidence:
  - payload JSON (`docs\ops\QUA-208_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json`)
  - direct verifier rerun evidence JSON
  - blocker status JSON
  - gate decision JSON
- Checks:
  - issue/parent IDs
  - transition status mapping
  - bars/tail fields and acceptance flag
  - blocker/gate clear-state fields
- Exit codes:
  - `0`: payload is consistent
  - `1`: payload mismatch or missing input
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA208IssueTransitionPayload.ps1`

## `Assert-CommitAllowlist.ps1`

- Guardrail for staged-file safety before committing in noisy worktrees.
- Reads `git diff --cached --name-only` and fails when staged files fall outside allowed path prefixes.
- Typical usage:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Assert-CommitAllowlist.ps1 -AllowedPaths infra/scripts/ docs/ops/QUA-207_`
- Exit codes:
  - `0`: staged set is allowed
  - `2`: staged files violate allowlist

## `Restore-QUA95RuntimeBars.ps1`

- Bounded runtime restore flow for `XTIUSD.DWX` M1 bars visibility.
- Uses check-then-act sequence:
  1. precheck custom-vs-source visibility probe
  2. only if still failing, stop/restart T1 `terminal64.exe` and re-probe
  3. repeat up to `-MaxRestartAttempts` (default `2`)
- Writes deterministic artifacts:
  - `docs\ops\QUA-207_RUNTIME_RESTORE_XTIUSD_2026-04-27.json`
  - `docs\ops\QUA-207_RUNTIME_RESTORE_XTIUSD_2026-04-27.md`
- Safety:
  - refuses T6 paths
  - scoped process control to the exact `terminal64.exe` under configured `-TerminalRoot`
- Exit codes:
  - `0`: restored (or already healthy at precheck)
  - `2`: still not restored / probe init failure
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Restore-QUA95RuntimeBars.ps1`

## `Install-QUA95RuntimeRestoreTask.ps1`

- Idempotently installs a Scheduler task for periodic runtime restore attempts.
- Defaults:
  - task name: `QM_QUA95_RuntimeRestore_15min`
  - interval: `15` minutes
  - principal: `SYSTEM` (highest)
  - flow: runs `Restore-QUA95RuntimeBars.ps1` with explicit Python path and bounded restart attempts
- Preview mode (no registration):
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA95RuntimeRestoreTask.ps1 -PreviewOnly`

## `Install-QUA95BlockedHeartbeatTask.ps1`

- Idempotently installs a Scheduler task that runs:
  - `Invoke-QUA95BlockedHeartbeat.ps1`
- Defaults:
  - task name: `QM_QUA95_BlockedHeartbeat_60min`
  - interval: `60` minutes
  - principal: `SYSTEM` (highest)
- Preview mode (no registration):
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA95BlockedHeartbeatTask.ps1 -PreviewOnly`

## `Update-QUA93BlockerStatus.ps1`

- Idempotently creates/refreshes `docs\ops\QUA-93_XAUUSD_BLOCKER_STATUS_2026-04-27.json`
  from latest QUA-93 rerun evidence:
  - `lessons-learned\evidence\2026-04-27_qua93_xauusd_rerun_evidence.json`
- Tracks:
  - current observed verifier row (`verdict`, `bars_got`, `tail_shortfall_seconds`, `disposition`)
  - acceptance-met flag (`bars_got > 0` and tail exact match)
  - last check timestamp and evidence path
  - recommended state (`blocked` vs `ready`)
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Update-QUA93BlockerStatus.ps1`

## `Write-QUA93BlockedSummary.ps1`

- Renders a concise markdown blocked-status comment from:
  - `docs\ops\QUA-93_XAUUSD_BLOCKER_STATUS_2026-04-27.json`
- Default output:
  - `docs\ops\QUA-93_BLOCKED_COMMENT_2026-04-27.md`
- Useful when posting deterministic issue status updates for blocked QUA-93 follow-up.
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Write-QUA93BlockedSummary.ps1`

## `Run-QUA93BlockerRefresh.ps1`

- Single-run orchestrator for QUA-93 blocked-state refresh.
- Runs in order:
  1. `Invoke-VerifyDisposition.ps1` (`QUA-93`, `XAUUSD.DWX`)
  2. `Update-QUA93BlockerStatus.ps1`
  3. `Write-QUA93BlockedSummary.ps1`
- Appends task log lines to:
  - `C:\QM\repo\infra\smoke\qua93_blocker_refresh_task.log`
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Run-QUA93BlockerRefresh.ps1`

## `Install-QUA93BlockerRefreshTask.ps1`

- Idempotently installs a Windows Scheduled Task for QUA-93 blocked-state refresh.
- Defaults:
  - task name: `QM_QUA93_BlockerRefresh`
  - interval: `60` minutes
  - principal: `SYSTEM` (highest)
- Preview mode (no task registration):
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Install-QUA93BlockerRefreshTask.ps1 -PreviewOnly`
- Smoke proof artifact:
  - `docs\ops\QUA-93_BLOCKER_REFRESH_TASK_SMOKE_2026-04-27.md`

## `Test-QUA93HandoffIntegrity.ps1`

- Validates SHA256 entries in:
  - `docs\ops\QUA-93_XAUUSD_VERIFIER_HANDOFF_2026-04-27.sha256`
- Verifies core blocked-state handoff artifacts for QUA-93:
  - blocker status JSON
  - blocked comment markdown
  - blocker refresh smoke markdown
  - latest rerun evidence JSON
  - CSV mismatch nudge evidence JSON
- Default run:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Test-QUA93HandoffIntegrity.ps1`

## `verify_import_chunked_probe.py`

- Read-only verifier mirror for symbol-level deep dive.
- Reuses verifier checks (head/tail/mid/spec) and compares:
  - full-span `copy_rates_range(...)` count
  - position-based `copy_rates_from_pos(...)` counts (pos `0`, `1000`)
  - chunked `copy_rates_range(...)` count
- Prints `terminal_maxbars` so evidence can distinguish:
  - MT5 chart-history cap effects (for example 100k cap), vs
  - genuine zero-bars visibility for a symbol.
- Supports `--json-out <path>` to emit machine-readable probe payloads for
  issue evidence/handoff.

## `verify_import_chunked_probe.py`

- Non-production probe that mirrors `verify_import.py` checks for one symbol.
- Keeps tick checks intact, but compares:
  - one-shot full-span M1 read (current verifier shape)
  - chunked M1 range reads (diagnostic/fix candidate)
- Helps decide whether `FAIL_bars` is query-shape/API-limit related vs data loss.
- Also reports source-vs-custom tail parity (`custom_minus_source_tail_ms`) so
  tail failures can be classified as symbol corruption vs expectation-basis mismatch.

## `verify_import_candidate.py`

- Repo-side candidate replacement for production `verify_import.py`.
- Uses chunked M1 reads + `terminal.maxbars`-aware bar expectations.
- Keeps existing tick/spec checks and outputs one-shot vs chunked bar diagnostics.
- Supports `--tail-basis sidecar|source`:
  - `sidecar`: strict match to archived `tick_last_ms`
  - `source`: compare custom tail to broker source tail in same window (`--tail-tol-ms`)
- Useful handoff artifact to the verifier owner; does not mutate production files.

## `summarize_verify_candidate_log.py`

- Parses `verify_import_candidate.py` log output and reports:
  - total parsed rows
  - unique symbol count
  - verdict distribution for all rows
  - verdict distribution by latest row per symbol
- list of latest `OK` symbols

## `Verify-HandoffIntegrity.ps1`

- Validates SHA256 entries in `docs/ops/QUA-91_WS30_VERIFIER_HANDOFF_2026-04-27.sha256`.
- Outputs per-file `OK/FAIL` plus final `checked`/`failed` counters.

## `Run-QUA91-HandoffChecks.ps1`

- Single entrypoint for QUA-91 closeout checks:
  - runs `Verify-HandoffIntegrity.ps1`
  - runs `summarize_verify_candidate_log.py` against the candidate run log

## `Invoke-VerifyDisposition.ps1`

- Idempotent verifier rerun helper for issue triage.
- Runs `verify_import.py` (scoped symbol + source-tail basis by default), captures a timestamped raw log under `infra\\smoke\\`,
  parses FAIL rows, and writes tracked evidence JSON under
  `lessons-learned\\evidence\\`.
- Parser supports both verifier output schemas for bars fields:
  - legacy `bars expected=.../got=...`
  - newer `bars_sidecar_expected=...; ... bars_chunked=...`
- Emits symbol-level disposition:
  - `clear`: `bars_got > 0` and tail aligned within tolerance (`abs(tail_delta_ms) <= 1000`)
  - `defer`: systemic zero-bars pattern or symbol bars still zero
  - `fix`: not clear/defer; investigation still in-flight
- Example:
  - `powershell -File C:\QM\repo\infra\scripts\Invoke-VerifyDisposition.ps1 -IssueId QUA-92 -Symbol XAGUSD.DWX`

## `Confirm-DwxRegistryMitigation.ps1`

- Idempotent QUA-69 confirmation helper for the `Fix_DWX_Spec_v3` registry-corruption mitigation.
- Pulls latest T1 terminal log + MQL5 log and checks:
  - successful script close events (`Fix_DWX_Spec_v3 ... closes terminal with code 0`) >= `-MinSuccessfulRuns` (default `3`)
  - throttle markers present (`BATCH|processed=5|sleep_ms=200`)
  - `symbols.custom.dat` exists and is above truncation floor (`-MinSafeBytes`, default `16384`)
- Emits machine-readable evidence JSON:
  - default `C:\QM\repo\lessons-learned\evidence\qua69_registry_mitigation_confirmation.json`
- Optional failure gate:
  - pass `-FailOnInsufficientEvidence` to return exit code `2` when checks fail.
- Example:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Confirm-DwxRegistryMitigation.ps1 -FailOnInsufficientEvidence`

## `Ensure-Mt5PortableMarker.ps1`

- Idempotent factory terminal convergence helper for MT5 portable markers.
- Default scope is `D:\QM\mt5\T1` through `D:\QM\mt5\T5`.
- Check-then-act behavior:
  - creates missing `portable.txt`
  - normalizes non-empty marker files back to empty
  - skips missing roots (optionally hard-fail with `-FailOnMissingRoot`)
- Safety:
  - refuses any `T6` terminal root path.
- Example:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Ensure-Mt5PortableMarker.ps1 -FailOnMissingRoot`

## `Drop-PortableMarkers.ps1`

- Acceptance-run wrapper for QUA-190 factory marker drift fix (`T1`-`T5` only).
- Idempotent behavior:
  - ensures/normalizes `portable.txt` at each terminal root
  - verifies marker existence per terminal
  - writes JSON evidence to `D:\QM\reports\ops\devops\portable_marker_evidence_<timestamp>.json`
- Optional probe mode (`-RestartForNonPortableProbe`) does a controlled restart:
  - starts each terminal once without `/portable` argument
  - checks for AppData `origin.txt` writes tied to that terminal exe
  - restores previously running factory terminals with `/portable`
- Safety:
  - hard-refuses T6 scope.
- Example:
  - `powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Drop-PortableMarkers.ps1 -RestartForNonPortableProbe -ProbeWaitSeconds 10`
