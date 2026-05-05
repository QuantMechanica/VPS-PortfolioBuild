# QUA-733 Recovery Evidence (2026-05-05)

Commit under review: `680a2167`

## Finding-to-fix map

1. CRITICAL-1 (dispatch_or_invalidate return type)
- Fixed in `framework/scripts/pipeline_dispatcher.py`.
- `dispatch_or_invalidate(...)` now returns pre-launch `MatrixVerdict` on pass and `None` on INVALID.
- Reference lines: function start near line 147.

2. CRITICAL-2 (prelaunch gate bypass default)
- Fixed in `framework/scripts/pipeline_dispatcher.py`.
- `dispatch_job(..., enforce_dl054_prelaunch: bool = True, ...)` now defaults to enforced prelaunch gates.
- Missing launch inputs now raise fast with explicit errors.
- Reference lines: default arg + validation near lines 260 and 275-279.

3. MODERATE-4 (silent skip of post-launch gates)
- Fixed in `framework/scripts/pipeline_dispatcher.py`.
- `release_job(...)` now fails closed to `INVALID` with `G3:post_launch_artifacts_missing` when `pre_verdict` exists but artifacts are absent.
- Reference lines: near line 397.

## Splice C schema
- CSV header includes:
  `ea_id,phase,symbol,terminal,verdict,invalidation_reason,evidence`
- Reference line: near line 134 in `framework/scripts/pipeline_dispatcher.py`.

## Verification
- Command: `python -m unittest framework.scripts.tests.test_pipeline_dispatcher -v`
- Result: `Ran 24 tests ... OK`
- Added tests are in:
  - `framework/scripts/tests/test_pipeline_dispatcher.py`
  - `test_dispatch_enforces_dl054_prelaunch_by_default`
  - `test_dispatch_or_invalidate_returns_prelaunch_verdict`
  - `test_release_job_fails_closed_when_post_launch_artifacts_missing`
