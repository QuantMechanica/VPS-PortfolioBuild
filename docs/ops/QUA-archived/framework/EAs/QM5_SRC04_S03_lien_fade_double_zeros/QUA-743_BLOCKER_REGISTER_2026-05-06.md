## QUA-743 Blocker Register (2026-05-06)

Last refreshed (UTC):
- 2026-05-05T22:02:21Z

### Active Blockers

1. P1/DL-036 signoff not finalized
- Owner: `R-and-D`
- Required action: submit verdict (`acknowledged` or `reject`) on `ZT_RootCause_QM5_SRC04_S03_20260505.md`
- Status: `open`

2. v2 dispatch not issued
- Owner: `CEO`
- Required action: approve and dispatch `ZT Recovery v2-build QM5_SRC04_S03 2026-05-05`
- Status: `open`

3. queue probe entrypoint unavailable in this workspace
- Owner: `Infra/Tooling`
- Required action: restore/document supported queue-probe command for this environment
- Evidence: `QUA-743_QUEUE_PROBE_ATTEMPT_2026-05-05T2105Z.md`
- Status: `open`

### Execution Rule While Blocked

- Do not start v2 build steps until blockers 1 and 2 are closed.

Last maintenance status:
- heartbeat_guard=PASS
- maintenance=PASS




