# QUA-1075 runner-missing evidence (2026-05-09)

Source: `D:/QM/reports/pipeline/QM5_1014/orchestration.log`

Observed line:

`2026-05-09T10:00:10Z state=BOOTSTRAP next_phase=P1 launch.status=runner_missing script=C:\QM\repo\framework\scripts\p1_build_validation.py`

Interpretation:
- This host has no built EA artifacts for `QM5_1014`.
- In addition, orchestration history records a pipeline bootstrap failure due to missing P1 runner script.

Unblock owner/action:
- Development/CTO to restore `framework/scripts/p1_build_validation.py` (or update orchestrator to current runner entrypoint), then scaffold/compile/setfiles for `QM5_1014`.
