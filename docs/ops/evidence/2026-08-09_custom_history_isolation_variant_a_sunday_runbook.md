# Variant A Custom-history isolation — Sunday execution runbook

Date: 2026-08-09
Authority required: OWNER-signed window receipt
Implementation review required: Claude `APPROVED`
Runtime scope: Strategy Farm T1–T10 only
Status: EXECUTION CHECKLIST — do not execute before the signed window

## Non-negotiable scope

The runner set is exactly `T1,T2,T3,T4,T5,T6,T7,T8,T9,T10`. T5 is an active
runner and is part of the migration; the earlier phrase “protected T_Live/T5”
was contradictory and is resolved here.

The exact protected-root set is:

- `C:\QM\mt5\T_Live`
- `D:\QM\mt5\T_Live` (reserved even when absent)
- `D:\QM\mt5\FTMO_STREAM1`
- `D:\QM\mt5\FTMO_STREAM2`
- `D:\QM\mt5\DEV1`
- `D:\QM\mt5\DEV2`
- `D:\QM\mt5\T_Export`

No command in this runbook may touch those roots, start `terminal64.exe`
directly, toggle AutoTrading, or change T_Live/FTMO task state. All test work
after restart goes through governed Q-only work items.

## OWNER receipt contract

Before the first `Bases\Custom` mutation, the detached OWNER JSON must exactly
match the approval embedded in the full-hash manifest. It binds:

- the manifest SHA-256 and Variant A;
- exact start/end time and T1–T10 set;
- rollback authorization;
- the reviewed implementation Git commit;
- Claude review task ID, `APPROVED` verdict, and review timestamp;
- an OWNER signature and the ratified decision SHA-256.

The tooling rejects metadata-only manifests, unsigned receipts, a non-approved
Claude review, a different commit, or any terminal-set mismatch.

## Stop conditions

Stop new claims and re-engage the global Custom-history lease on any of:

- error `[32]` / sharing violation;
- history synchronization abort;
- archive hash/file-ID drift or an unexpected runner write/delete deny ACL;
- missing real-ticks marker;
- isolation gate failure;
- missing/extra staged file, mutable hardlink, or reparse-point live root;
- a Q-only representative work item producing infrastructure evidence that
  cannot be authenticated.

Do not interrupt a running backtest. Preserve every receipt and use the
rollback section only after the affected runner set is quiescent.

## Variables

Set these in an elevated PowerShell owned by the signed window operator:

```powershell
$QmRepo = 'C:\QM\repo'
$QmFarm = 'D:\QM\strategy_farm'
$QmMt5 = 'D:\QM\mt5'
$QmWindow = '<OWNER_SIGNED_WINDOW_ID>'
$QmOps = Join-Path $QmFarm "artifacts\ops\custom_history_$QmWindow"
$QmManifestDraft = Join-Path $QmOps 'archive_manifest_draft.json'
$QmOwnerReceipt = Join-Path $QmOps 'owner_window_receipt.json'
$QmManifest = Join-Path $QmOps 'archive_manifest_owner_approved.json'
$QmImplementationCommit = '<CLAUDE_APPROVED_IMPLEMENTATION_COMMIT>'
Set-Location -LiteralPath $QmRepo
```

## Checklist

1. Verify the reviewed implementation is committed and byte-clean.

   ```powershell
   git cat-file -e "$QmImplementationCommit^{commit}"
   git status --short -- tools/strategy_farm/custom_history_contract.py tools/strategy_farm/custom_history_copy_on_claim.py tools/strategy_farm/custom_history_gate.py tools/strategy_farm/custom_history_lease.py tools/strategy_farm/custom_history_migration.py tools/strategy_farm/custom_history_acl.ps1 tools/strategy_farm/custom_history_smoke_admission.py tools/strategy_farm/mt5_history_isolation.py tools/strategy_farm/terminal_worker.py framework/scripts/run_smoke.ps1
   python -m pytest tools/strategy_farm/tests/test_custom_history_copy_on_claim.py tools/strategy_farm/tests/test_custom_history_smoke_admission.py tools/strategy_farm/tests/test_custom_history_variant_a.py tools/strategy_farm/tests/test_mt5_history_isolation.py tools/strategy_farm/tests/test_terminal_worker_custom_history_isolation.py -q
   pwsh.exe -NoProfile -File framework/scripts/tests/Test-RunSmokeCustomHistoryAdmission.ps1
   ```

   Require no output from `git status` for those paths and retain the test log.

2. Capture the pre-migration read-only topology, junction map, ACLs, volume/file
   IDs, counts, sizes, free space, and current process/task state. The topology
   audit is expected to fail closed before cutover because T2–T10 still resolve
   to T1.

   ```powershell
   New-Item -ItemType Directory -Path $QmOps -ErrorAction Stop | Out-Null
   python tools/strategy_farm/mt5_history_isolation.py --output (Join-Path $QmOps 'topology_before.json')
   Get-ChildItem -LiteralPath $QmMt5 -Directory | Where-Object Name -Match '^T(?:[1-9]|10)$' | ForEach-Object { Get-Item -LiteralPath (Join-Path $_.FullName 'Bases\Custom') } | Select-Object FullName,LinkType,Target | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $QmOps 'junction_map_before.json')
   Get-Volume -DriveLetter D | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $QmOps 'volume_before.json')
   ```

3. Build the full 2017–2025 archive manifest. This is read-only against the
   live Custom tree. Confirm the measured baseline remains 3,946 archive files
   and 44,231,653,718 bytes; otherwise stop for review.

   ```powershell
   python tools/strategy_farm/custom_history_migration.py build-manifest --source-custom 'D:\QM\mt5\T1\Bases\Custom' --runner-identity 'WIN-B95G5LPSJ1O\qm-admin' --output $QmManifestDraft
   ```

   Claude reviews the draft and implementation commit. OWNER then creates the
   detached receipt described above. Attach it; this does not mutate MT5.

   ```powershell
   python tools/strategy_farm/custom_history_migration.py attach-owner-approval --manifest $QmManifestDraft --owner-receipt $QmOwnerReceipt --output $QmManifest
   python tools/strategy_farm/custom_history_migration.py plan --manifest $QmManifest --mt5-root $QmMt5 --window-id $QmWindow | Set-Content -Encoding UTF8 (Join-Path $QmOps 'stage_plan.json')
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/strategy_farm/custom_history_acl.ps1 -Mode Plan -ManifestPath $QmManifest -OwnerReceiptPath $QmOwnerReceipt -SourceCustom 'D:\QM\mt5\T1\Bases\Custom' -EvidencePath (Join-Path $QmOps 'acl_plan_unused.json') | Set-Content -Encoding UTF8 (Join-Path $QmOps 'acl_plan.json')
   ```

4. Assert the normal Factory OFF interlock, stop new claims, and drain. Never
   kill an active test. Require zero active database rows and no runner
   `terminal64.exe` or `metatester64.exe` before continuing.

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/strategy_farm/Factory_OFF.ps1 -NoPause
   python tools/strategy_farm/farmctl.py health
   ```

5. Engage Variant D containment before topology mutation. It remains engaged
   through staging, cutover, dual audits, gate activation, and worker-code
   recycle preparation.

   ```powershell
   python tools/strategy_farm/custom_history_migration.py engage-containment --manifest $QmManifest --owner-receipt $QmOwnerReceipt --farm-root $QmFarm --reason 'OWNER_quiesced_variant_a_migration' --execute
   ```

6. Stage ten physical directories beside the live paths. Archive records start
   as hardlinks to the manifest IDs; 2026 `.hcc`/`.tkc`, `.hc`, `.dat`, and every
   unclassified file are private copies. The command is idempotent. The original
   rollout applied a runner deny ACL; the OWNER amendment below supersedes that
   ACL step and requires its removal before any amended worker recycle.

   ```powershell
   python tools/strategy_farm/custom_history_migration.py stage --manifest $QmManifest --owner-receipt $QmOwnerReceipt --mt5-root $QmMt5 --receipt (Join-Path $QmOps 'stage_receipt.json') --acl-evidence (Join-Path $QmOps 'acl_apply.json') --execute
   python tools/strategy_farm/custom_history_migration.py verify-stage --manifest $QmManifest --mt5-root $QmMt5 --window-id $QmWindow | Set-Content -Encoding UTF8 (Join-Path $QmOps 'stage_verify.json')
   ```

   Require `PASS_ISOLATED`, exact manifest hashes, private mutable IDs across
   all ten terminals, archive IDs equal to the manifest, and sufficient free
   disk above the 25 GiB floor plus contingency.

7. Perform timestamped rename cutover. The tool rechecks quiescence, containment,
   staging, and creates a SQLite backup before the first rename. It never
   deletes the rollback topology.

   ```powershell
   python tools/strategy_farm/custom_history_migration.py cutover --manifest $QmManifest --owner-receipt $QmOwnerReceipt --mt5-root $QmMt5 --farm-root $QmFarm --db-backup (Join-Path $QmOps 'farm_state_before_cutover.sqlite') --receipt (Join-Path $QmOps 'cutover_receipt.json') --execute
   ```

8. Run two independent full deny-absence/integrity and isolation audits from
   fresh processes.

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/strategy_farm/custom_history_acl.ps1 -Mode Verify -ManifestPath $QmManifest -OwnerReceiptPath $QmOwnerReceipt -SourceCustom 'D:\QM\mt5\T1\Bases\Custom' -EvidencePath (Join-Path $QmOps 'acl_verify_1.json') | Set-Content -Encoding UTF8 (Join-Path $QmOps 'acl_verify_1_stdout.json')
   python tools/strategy_farm/mt5_history_isolation.py --manifest $QmManifest --require-owner-approval --acl-evidence (Join-Path $QmOps 'acl_verify_1.json') --output (Join-Path $QmOps 'isolation_audit_1.json')
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/strategy_farm/custom_history_acl.ps1 -Mode Verify -ManifestPath $QmManifest -OwnerReceiptPath $QmOwnerReceipt -SourceCustom 'D:\QM\mt5\T1\Bases\Custom' -EvidencePath (Join-Path $QmOps 'acl_verify_2.json') | Set-Content -Encoding UTF8 (Join-Path $QmOps 'acl_verify_2_stdout.json')
   python tools/strategy_farm/mt5_history_isolation.py --manifest $QmManifest --require-owner-approval --acl-evidence (Join-Path $QmOps 'acl_verify_2.json') --output (Join-Path $QmOps 'isolation_audit_2.json')
   ```

   Both must be `PASS_ISOLATED`; findings, manifest identity, per-terminal file
   counts, and inventory digests must match in substance.

9. Activate the governed worker gate while containment is still engaged.

   ```powershell
   python tools/strategy_farm/custom_history_migration.py activate-gate --manifest $QmManifest --owner-receipt $QmOwnerReceipt --audit (Join-Path $QmOps 'isolation_audit_1.json') --audit (Join-Path $QmOps 'isolation_audit_2.json') --farm-root $QmFarm --execute
   ```

10. Remint the fresh OWNER Factory ON runtime activation decision and SHA sidecar
    after the implementation commit is final. It must bind the current OFF
    record and final canonical source blobs. Validate it before changing the
    containment state.

    ```powershell
    python tools/strategy_farm/factory_runtime_activation.py --repo-root $QmRepo --factory-off-flag (Join-Path $QmFarm 'state\FACTORY_OFF.flag')
    ```

11. Release the global lease after the dual audits and gate activation, then
    create ramp step 1. The release command refuses if either audit/activation
    differs, any work/process is active, or a lease record remains. The ramp
    command refuses while containment is engaged or if a step is skipped. The
    activation gate admits no terminal while the initial ramp receipt is absent.

   ```powershell
   python tools/strategy_farm/custom_history_migration.py release-containment --manifest $QmManifest --owner-receipt $QmOwnerReceipt --audit (Join-Path $QmOps 'isolation_audit_1.json') --audit (Join-Path $QmOps 'isolation_audit_2.json') --farm-root $QmFarm --mt5-root $QmMt5 --reason 'dual_cutover_audits_passed_before_ramp_1' --execute
   python tools/strategy_farm/custom_history_migration.py set-ramp --manifest $QmManifest --owner-receipt $QmOwnerReceipt --farm-root $QmFarm --limit 1 --reason 'dual_audits_passed_step_1_ready' --execute
   ```

12. Run the normal Factory ON scheduled task only after its fresh decision
    validates. This is the full worker-fleet recycle; never launch a terminal
    executable manually. The activation gate and ramp receipt are read by every
    new worker before claim and immediately before spawn.

    ```powershell
    Start-ScheduledTask -TaskName 'QM_StrategyFarm_FactoryON_AtLogon'
    ```

13. Ramp `1 → 2 → 5 → 10`. At each step, route governed real-tick Q02 work that
    covers EURUSD, NDX, a non-USD host requiring conversion, and a declared
    basket dependency. Require authenticated reports, real-ticks markers, zero
    stop conditions, and a passing scoped isolation audit before advancing.

    ```powershell
    python tools/strategy_farm/custom_history_migration.py set-ramp --manifest $QmManifest --owner-receipt $QmOwnerReceipt --farm-root $QmFarm --limit 2 --reason 'step_1_evidence_passed' --execute
    python tools/strategy_farm/custom_history_migration.py set-ramp --manifest $QmManifest --owner-receipt $QmOwnerReceipt --farm-root $QmFarm --limit 5 --reason 'step_2_evidence_passed' --execute
    python tools/strategy_farm/custom_history_migration.py set-ramp --manifest $QmManifest --owner-receipt $QmOwnerReceipt --farm-root $QmFarm --limit 10 --reason 'step_5_evidence_passed' --execute
    ```

14. Soak for at least 24 continuous hours and 500 governed MT5 runs. Require at
    least 80% aggregate runner occupancy for one sustained four-hour interval,
    zero error `[32]`, zero history synchronization aborts, zero cross-terminal
    mutable IDs, stable archive hashes, and no increased history-related
    infrastructure-failure rate. Claude independently reviews the soak before
    any rollback tree is considered for later retention cleanup.

15. Copy the signed summary, audit identities, ramp receipts, soak statistics,
    and independent review into `C:\QM\repo\docs\ops\evidence\`. Commit with
    explicit pathspecs on the registered board-advisor checkout and integrate
    to `main`; do not leave the evidence only in an agent worktree or in
    `D:\QM\strategy_farm\artifacts`.

## OWNER amendment — copy-on-claim archive privatization

Binding decision:
`decisions/2026-08-09_custom_history_isolation_amendment_copy_on_claim.md`.
Authority: OWNER “Ja freigegeben”, 2026-08-09. Window:
`custom_history_variant_a_20260809`, open through 2026-08-09 22:00Z. This
section supersedes the immutable-archive and deny-ACL premises in steps 6, 8,
11–14; it does not authorize any T_Live/FTMO mutation or a manual terminal
launch.

The triggering evidence is the T5 13:49 error `[5]` → archive-delete pattern,
the same T1 class on Q08 work item `5c3506e0`, and the retained window
restoration receipt. All 11/11 families were restored before this amendment;
containment remains the controlling state until Claude completes the amended
review and re-audit.

### Amended runtime contract

1. The worker derives the exact Custom-history set from the claimed host symbol
   plus declared `conversion_symbols` and `basket_symbols`. Before spawn, and
   while holding the existing global Custom-history lease, it copies only that
   terminal/symbol archive set to same-directory temporary files, verifies each
   full SHA-256 against the OWNER-bound manifest, and atomically replaces the
   hardlink. A retry verifies and reuses an already-private file. A missing row,
   size/hash mismatch, shared private inode, or rename failure is fail-closed
   and re-engages containment.
2. The immediate gate accepts an archive path only as either:

   - a manifest family hardlink whose link count is at least the manifest
     baseline plus the family members still observed across T1–T10; or
   - a terminal-private inode with link count 1 and a full manifest SHA-256.

   Private inode identities must be unique to one terminal/path. The worker
   runs the gate both before and after copy-on-claim. Every successful claim
   writes a hash-bound receipt below
   `D:\QM\strategy_farm\artifacts\ops\custom_history_copy_on_claim\`.
3. `custom_history_acl.ps1 -Mode Apply -Execute` now removes the explicit runner
   write/delete deny from archive files; `Verify` fails if any matching deny
   remains. Content integrity is enforced by the manifest, copy receipt, and
   mixed-topology audits, not by an ACL premise MT5 disproved.
4. `run_smoke.ps1` checks the activation gate and ramp before resolving any
   factory-terminal launch boundary, then owns a farm reservation through its
   `finally` block. A gate-held terminal is refused. While isolation is active,
   factory smoke must also be bound to the already-claimed work item via
   `QM_WORK_ITEM_ID`; unbound direct factory smoke is refused because it has no
   worker copy-on-claim proof. DEV1/DEV2 remain outside the T1–T10 reservation
   helper and retain their existing isolation rules.

### Claude-reviewed continuation only

Do not run these steps from the implementation ticket. After approving the
amendment commit, Claude owns the quiesced ACL removal, two fresh full audits,
worker recycle, representative Q-only work, and resumed `1 → 2 → 5 → 10` ramp.

```powershell
$QmAmendmentCommit = '<CLAUDE_APPROVED_AMENDMENT_COMMIT>'
git cat-file -e "$QmAmendmentCommit^{commit}"
python -m pytest tools/strategy_farm/tests/test_custom_history_copy_on_claim.py tools/strategy_farm/tests/test_custom_history_smoke_admission.py tools/strategy_farm/tests/test_custom_history_variant_a.py tools/strategy_farm/tests/test_mt5_history_isolation.py tools/strategy_farm/tests/test_terminal_worker_custom_history_isolation.py -q
pwsh.exe -NoProfile -File framework/scripts/tests/Test-RunSmokeCustomHistoryAdmission.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/strategy_farm/custom_history_acl.ps1 -Mode Apply -ManifestPath $QmManifest -OwnerReceiptPath $QmOwnerReceipt -SourceCustom 'D:\QM\mt5\T1\Bases\Custom' -EvidencePath (Join-Path $QmOps 'acl_amendment_remove_deny.json') -FarmRoot $QmFarm -Execute
```

After the deny-removal receipt passes, repeat the two fresh-process commands in
step 8 and replace the activation-bound audit identities under the still-open
OWNER window. Recycle workers only through the governed scheduled task; never
start `terminal64.exe` manually. At every Q-only ramp step, require the claimed
host/conversion/basket symbols, copy-on-claim receipt, post-copy gate audit,
authenticated report, and zero stop conditions to agree before advancing.

## Rollback

On a cutover or soak stop condition, engage containment immediately, stop new
claims, and let active work finish. Then execute rollback under the same OWNER
receipt:

```powershell
python tools/strategy_farm/custom_history_migration.py engage-containment --manifest $QmManifest --owner-receipt $QmOwnerReceipt --farm-root $QmFarm --reason 'variant_a_stop_condition_rollback' --execute
python tools/strategy_farm/custom_history_migration.py rollback --manifest $QmManifest --owner-receipt $QmOwnerReceipt --mt5-root $QmMt5 --farm-root $QmFarm --receipt (Join-Path $QmOps 'rollback_receipt.json') --execute
```

The new trees move to retained failure-analysis paths and the timestamped
original objects return to `Bases\Custom`. If the isolation gate had already
been activated, rollback writes a hash-bound `PASS_SERIALIZED_ROLLBACK` receipt;
workers may then operate only while the global containment lease remains
engaged. Do not delete either topology or any manifest/receipt in this window.
