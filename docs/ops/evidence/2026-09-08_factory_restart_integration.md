# Controlled factory restart: workspace integration

OWNER authorized backup, review and separate local commits on 2026-09-08, then
instructed autonomous implementation without repeated approval requests.

Recovery root: `D:/QM/reports/maintenance/factory_restart/20260908T0948Z_controlled_resume`.
The original HEAD is `3137b7d978a2582f2e0ef84e6bc1d592e9306b1a`.
`checkout_before_integration/` preserves the original index, staged and unstaged
binary patches, and a SHA-256-verified ZIP of all 1,332 dirty paths. ZIP SHA-256:
`de72d7cec921b3594870403daecb022fd773b3267ee3772ad34168f24b13073b`.

## Scope and disposition

This is preservation/integration, not strategy approval, a compile waiver, gate
promotion, or live deployment. Existing work includes substantive strategy changes
(e.g. QM5_10025, QM5_1538, QM5_41223, QM5_41238); versioning does not qualify them.
No gates, historical verdicts, data windows or execution permissions are loosened.
The EURUSD Design-2 implementation and its already-recorded release evidence are
preserved; the later dashboard-1/chart-2 enhancement remains a separate task.

The unchanged EX5 commit guard was evaluated against a disposable candidate index:
239 binaries, 226 with matching governed receipts and 13 without. The rejected
binaries were moved, with unchanged hashes, to `unbound_ex5_quarantine/` outside
the checkout. Original bytes also remain in the verified ZIP. They are NOT
committed as approved builds. Four previously tracked binaries become deletions;
nine untracked binaries stay outside the canonical build tree. A future build
must use governed compile admission; no fabricated COMPILE_OK receipts.

Quarantined IDs: 10850, 1252, 20291, 21524, 41179, 41186, 41187, 41188, 41189,
41190, 41276, 41340, 41374. At review only 21524, 41179 and 41189 had queued rows;
missing binaries must fail closed rather than use these unauthenticated artifacts.

## Integration repairs

- Rename `artifacts/qm5_41286_build_task_20260902.json` to `.md`: it is a Markdown
  build handoff, not JSON. No repository references to the old filename found.
- Pin QM5_41242's three existing news-OFF/NONE default values explicitly in its
  backtest setfile, satisfying the existing build-contract test. No risk changes.
  This changes setfile identity; do not silently rewrite prior job hash bindings.
- Update the outdated restart test to the already-implemented twelve-identity,
  ten-active-worker fleet: T11/T12 remain inert. Add disjointness/full-identity
  assertions; preserve exact T1-T10 and task/worker health requirements.

## Validation

- Full initial selected console/restart/provenance suite: 890 passed, one stale
  fleet-test assertion failed. That assertion is corrected as described above.
- Five declared restart residual tests passed; the separately added QM5_41242
  test exposed missing explicit default pins. Its targeted rerun passed.
- Targeted corrected fleet/canary/QM5_41242 suite: 21 passed.
- QM5_41223, QM5_41238 reference and EX5-guard tests: 30 passed.
- Backup scan: Python syntax/JSON parsing, conflict-marker and credential-location
  checks found only the mislabeled Markdown handoff above (no credential hits).
- The real Git pre-commit EX5 guard remains enabled for every commit.

The original mixed staging state is recoverable from the saved index/patches;
integration deliberately regroups it into separate commits. No push is performed
by the integration helper. FTMO and T_Live binaries, charts and AutoTrading are
outside the operation. Actual restart/throughput evidence follows separately.
