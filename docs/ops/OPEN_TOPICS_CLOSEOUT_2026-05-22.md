# Open Topics Closeout 2026-05-22

## Overview
Cleanup of framework test drift and EA build/registry artifact drift identified during the Deep Audit 2026-05-20.

## Actions Taken

### 1. EA Build/Registry Cleanup (Task a48dfacc)
- **Status:** APPROVED
- **Actions:**
    - Identified stale build artifacts for QM5_1002, QM5_1003, and others in legacy directories.
    - Archived stale artifacts to `docs/ops/QUA-archived/2026-05-22_cleanup/`.
    - Cleaned up `.scratch` and `.tmp` directories of legacy EA build data.
- **Verdict:** EA_BUILD_REGISTRY_CLEANUP_APPROVED

### 2. Framework Test Drift Archive (Task ce5812f0)
- **Status:** APPROVED
- **Actions:**
    - Removed retired test files: `test_p8_news_driver.py`, `test_phase_input_generators.py`.
    - Surgically removed P3.5, P5b, and P8 references from:
        - `test_phase_verdict_semantics.py`
        - `test_phase_runners_contract.py`
        - `test_phase_runners_idempotence.py`
        - `test_phase_runner_log_schema.py`
        - `test_phase_end_to_end_dryrun.py`
        - `test_p4_walk_forward.py`
    - Updated infrastructure scripts to match current V5 phase gating:
        - `run_phase.ps1`: Removed retired phases from `ValidateSet` and `runnerMap`.
        - `aggregate_phase_results.py`: Removed retired phases from `EXPECTED_PHASES` and `REQUIRED_PHASES`.
- **Verdict:** FRAMEWORK_TEST_DRIFT_CLOSEOUT_APPROVED

## Verification Results
- All updated tests in `framework/scripts/tests/` passed (11 passed, 1 skipped).
- End-to-end dryrun now yields `READY` verdict without retired phase dependencies.

## Next Steps
- Continue with Friday smoke tasks and strategy research as assigned by the router.
