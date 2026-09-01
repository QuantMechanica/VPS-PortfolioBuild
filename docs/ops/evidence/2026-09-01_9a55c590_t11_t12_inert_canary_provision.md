# T11/T12 inert fleet-canary provisioning

- Task: `9a55c590-d426-4abb-bff3-87fc2805022d`
- Date: 2026-09-01 UTC
- Branch: `agents/board-advisor`
- Code commit: `2a1a83f0ed88b60cb1e6b64145fd2c5d9b6a1cdc`
- Result: `PASS_INERT_PROVISIONED`; activation was not performed.

## Acceptance result

Both `D:\QM\mt5\T11` and `D:\QM\mt5\T12` are complete cold portable installations. Each has physical `Bases/Custom`, `Config`, `MQL5`, `Profiles`, `Sounds`, `Tester`, `llm-agent`, and `logs` directories plus `terminal64.exe`, `metatester64.exe`, `MetaEditor64.exe`, and `portable.txt`. The mutable non-Custom broker `Bases` cache intentionally starts empty; it is downloadable cache, not an installation or governed-history prerequisite, and may populate only after the separate activation.

Tester configuration copied from T1 was checked against `framework/registry/tester_defaults.json` SHA-256 `e83e02b2a776bc5022dac8714e2f948a42fdf17a3aad1e64a8c2136e5ca4797b`: deposit 100000 USD, leverage 100, real-tick model 4, and fixed-risk authority 1000. Both profiles bind Darwinex-Live login `4000090541`, matching OQ-17. No terminal was launched to test the login.

## Custom-history proof

The signed v1 manifest was preserved byte-for-byte. Its content hash is `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`; its file SHA-256 is `6e82b478a09a642a189f0da17edb6f83c35fe32a587b398c3250ed056919c634`. The original signed T1-T10 runner binding was not rewritten.

Per terminal:

- 3,946/3,946 archive files and 44,231,653,718 bytes passed full SHA-256 verification.
- 2,149 archives (24,697,759,699 bytes) use the surviving manifest family inode and are ready for copy-on-claim privatization.
- 1,797 archives (19,533,894,019 bytes) whose original family had already fully privatized were copied separately from the verified master; each resulting inode has link count 1.
- 300 mutable/unclassified files (1,893,742,702 bytes) were copied privately per terminal.
- `custom_history_copy_on_claim.py` now admits provisioned T1-T12 identities, while the active gate remains authoritative. Direct post-provision probes for T11 and T12 both returned `FAIL_CLOSED`, reason `terminal_not_in_activation`, activation hash `61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e`.

Receipts:

- `docs/ops/evidence/2026-09-01_9a55c590_t11_inert_provision.json`, file SHA-256 `0a3443fc0ba2add6b959457b6a38abc08371509e55c2ee78190b3a4351d47355`, receipt SHA-256 `41f1951b3e28fbb5c19cc4b34754fe21b84b4691ec40974dfea4ab8d9a80f344`.
- `docs/ops/evidence/2026-09-01_9a55c590_t12_inert_provision.json`, file SHA-256 `3a46fdc579eebf437d59ec8f83787f158ceb2780a5f94c508f5d9b761350a03a`, receipt SHA-256 `1e804b578f1b09b8a66f7bbd5ba28588348b16ba0f341aaf6ab4bb9ffdad7628`.

## Inertness and zero-disruption proof

`D:\QM\strategy_farm\state\disabled_terminals.txt` contains exactly `T11` and `T12`; SHA-256 `c85fb75249417930338a310e62258c74c20b176f3c0bcbf9e2a079e2c04c75a9`. The Python launcher resolves the enabled installed cohort as exactly T1-T10. Factory watchdog capacity is now `12 - disabled_count`, hence remains 10 with this policy.

No T11/T12 `terminal64.exe`, `python.exe`, or `pythonw.exe` process existed before, during, or after provisioning. The ten worker PIDs observed before provisioning remained identical after it: T1 8276, T2 15944, T3 37832, T4 9080, T5 12168, T6 11596, T7 32052, T8 24976, T9 33728, T10 21876. No worker restart, factory stop/start, scheduled-task mutation, terminal launch, AutoTrading toggle, or T_Live operation occurred. Containment remained `enabled:false`, mode hash `a4fa8c01c2d282ef4dd195761e1573f0382a5dc043104a1e1188fd0d28f6add8`.

An initial staging attempt exposed that T1's mutable non-Custom broker cache exceeds 64 GiB. Only newly created `T11`/`T12.__provisioning__` paths and the provisional receipt were removed; they were reproducible and contained no pre-existing data. Free space returned to 94.6 GiB before the corrected cold-cache run. The final verified installations leave 44.74 GiB free.

## Hard-code inventory and changes

All executable T1-T10 assumptions in the ticket-named farm control paths were located and extended:

- `farmctl.py`: factory regex, `MT5_TERMINALS`, MT5 and worker process scans, path attribution, reservation help, and operator labels.
- `terminal_worker.py`: excluded/avoid fleet sets; CLI choices inherit the extended `farmctl.MT5_TERMINALS`.
- `start_terminal_workers.py` and `.ps1`: T1-T12 inventory, worker command-line classifier, and disabled-policy classifier.
- `factory_watchdog.ps1`: disabled classifier, `12 - disabled_count` expected cohort, and terminal process scan.
- `framework/scripts/reconcile_dispatch_state.py`: governed factory set and process documentation.

Necessary adjacent control surfaces were also extended so later activation cannot fall through an old classifier: `health.py`, `factory_process_scope.ps1`, `Factory_ON.ps1`, `factory_restart_health.ps1`, `TestWindow_OFF.ps1`, and `framework/scripts/run_smoke.ps1`. `Factory_ON.ps1` preserves the currently approved active T1-T10 cohort by explicitly approving T11/T12 as disabled. `run_smoke.ps1` accepts the new identities but its `any` resolver skips disabled terminals. Historical incident comments and specialized single-terminal contracts were not mechanically rewritten.

The signed Variant-A v1 contract remains T1-T10. A separate `PROVISIONED_FACTORY_TERMINALS` T1-T12 set enables copy-on-claim validation for the canaries without admitting them through the active gate. Actual activation still requires a separate Orchestrator ceremony that extends signed activation/ramp authority.

## Verification

- `python -m pytest ...test_factory_canary_fleet.py ...test_custom_history_copy_on_claim.py ...test_custom_history_variant_a.py ...test_custom_history_smoke_admission.py ...test_terminal_worker_custom_history_isolation.py -q`: `47 passed`.
- `powershell.exe -NoProfile -NonInteractive -File tools/strategy_farm/tests/Test-FactoryProcessScope.ps1`: `PASS (285 assertions)`.
- `python -m py_compile` on the provisioner, farmctl, terminal worker, launcher, health, and reconcile modules: PASS.
- `git diff --check` on all scoped code paths: PASS.
- Post-provision gate: T11/T12 both `FAIL_CLOSED: terminal_not_in_activation`.
- Post-provision enabled launcher cohort: `('T1', ..., 'T10')` only.

## Rollback

Rollback is permitted only while each canary remains disabled and has no terminal/worker process:

1. Verify the resolved targets are exactly `D:\QM\mt5\T11` and `D:\QM\mt5\T12`, then delete only those two directories.
2. Revert code commit `2a1a83f0ed88b60cb1e6b64145fd2c5d9b6a1cdc` through normal OWNER integration control.
3. Keep or remove the T11/T12 disabled-list rows only under OWNER direction. Leaving the rows is fail-closed.

Activation is explicitly outside this ticket: do not remove the disabled rows, start workers, change the signed activation/ramp, or run a rate canary from this artifact.
