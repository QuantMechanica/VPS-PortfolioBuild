# SP-D4 isolated restore drill — dependency gate

Date: 2026-08-22  
Router task: `41aa55bc-0780-474d-8f26-332db8fb9e1b`  
Depends on: SP-D3  
Verdict: **DEFER — no SP-D3 encrypted backup/receipt exists to restore**

## Decision

SP-D4 requires an end-to-end restore of the governed backup created by SP-D3. SP-D3 is in REVIEW with a dependency deferral because the OWNER-approved ROT-4 key-custody and recovery contract is absent. Consequently there is no approved encrypted bundle, external key locator, decrypt receipt, `COMPLETE` marker, or restore-authority contract from which an SP-D4 RPO/RTO measurement can start.

The existing `QM_NightlyBackup_Vault` task is healthy and its 2026-08-22 run reported `failures=0`, elapsed `00:00:58.2821226`, including a WAL-consistent SQLite copy and T_Live/report/registry files. That legacy 14-day vault copy is not the SP-D3 encrypted backup and has no SP-D3 manifest or decryption ceremony. Substituting it would test a different contract and falsely close the dependency.

The backup path is also a per-user `G:` DriveFS mount. It is accessible to the `qm-admin` backup scheduled task but not to this headless orchestration security context, so even a read-only isolated restore from the legacy bundle cannot be reproduced here.

## Required drill receipt once SP-D3 is available

The first authorized SP-D4 run must restore into a newly created, explicitly bounded staging directory and record:

1. source bundle ID, manifest SHA-256, `COMPLETE` marker, and backup completion UTC;
2. key reference and authorization receipt without key material;
3. restore start/end UTC and measured RTO;
4. source cut-off versus recovery point and measured RPO;
5. decrypted file SHA-256 parity against the SP-D3 manifest;
6. SQLite `quick_check`, schema/core-row queries, and registry parsability;
7. terminal profile/preset/report readiness checks without starting any terminal;
8. destruction/retention disposition for the isolated staging copy;
9. monthly technical and quarterly full-drill scheduled-task definitions, installed only after OWNER approves their authority and alert destination.

No staging restore, decryption, scheduled drill, T_Live, terminal, AutoTrading, source backup, or retention set was changed. RPO and RTO are therefore correctly reported as **not measured**, not estimated from the backup log.
