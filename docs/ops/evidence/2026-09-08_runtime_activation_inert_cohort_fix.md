# Runtime activation: preserve the approved inert T11/T12 cohort

The controlled R2 restart on 2026-09-08 passed the 48-task/10-worker health
gate, then failed closed at `maintenance_control.release-on-restart`.
Evidence: `D:/QM/reports/maintenance/factory_restart/20260908T0948Z_controlled_resume/resume_r2_stderr.log`.

The raw disabled-policy hash was unchanged on both sides:
`5af124b9494bf8c1391765fddb5462b963b61abbb973eebbdcb14d810c72aa3d`.
Its rows were T11/T12, as required by the existing Factory_ON fleet contract.
But the runtime template/schema/validator still required `disabled_terminals=[]`.
Thus the independently authenticated final release correctly rejected the
inconsistent generated authorization. No hold was released and OFF recovery
proved quiescence again at 10:49:52 UTC.

Fix: require exactly T11/T12 in the runtime template, JSON schema and validator,
with T1–T10 still the exact active cohort. The maintenance release guard,
raw-policy hash check, parent/lock authentication, source binding, task health,
resource thresholds and strategy gates are unchanged. Old empty-policy runtime
generations are no longer accepted; build a fresh committed generation after
this change against the exact current OFF record. The standing preparation
decision is not edited.

Regression evidence: the builder test failed before the production fix because
it generated the empty list. Afterward 98 runtime/builder/maintenance/restart
tests passed in 40.84 seconds. Added exact-cohort negative cases reject an empty,
partial, reordered, expanded or duplicate inert list. Maintenance tests cover
both exact T11/T12 acceptance and rejection of an omitted inert cohort even
when the raw policy hashes are equal. This is a configuration consistency fix,
not a validation bypass or a new authorization to activate T11/T12.
