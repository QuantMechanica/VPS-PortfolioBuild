# Live Factory dispatch check, 2026-09-22

All six recovered strategies are registered and COMPILE_OK/build_check PASS.
Independent POC implementation review bb697211 and Q01 route 7267e593 are now
APPROVED. The stale POC review hold was cleared through agent_router; original
build 751d8eb5 is TODO and bound to exact compile evidence.

Actual Q01 dispatch dry-runs for six frozen 2019 single-symbol diagnostics all
refuse artifact_drift_since_compile on setfile SHA only. No smoke work item was
appended and no real smoke test has started. The existing 36008 Q02 remains pending.

Producer records setfile_generation SHA before build_check applies the final
build_hash stamp; the new consumer compares current final bytes to that earlier
hash. Evidence: q01_dispatch_dry_run_2019.json and compile_work_items.py generation
before build_command sequence. Do not weaken hash checks or edit sealed history.

Priority-81 repair task: 32d39ccd-7c78-4845-951c-5ac6678be580. It must repair exact provenance,
obtain independent review, close the separately documented agent_tasks-to-Q02
admission handoff gap, and then actually dispatch the six existing candidates.
No duplicate build/Q02 task is authorized by this follow-up.
