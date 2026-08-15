# Sparse active Custom-history contract — implementation receipt

Date: 2026-08-15

Router task: `71eba21c-e77c-40ca-96d5-d251ad8609f0`

Implementation lane: Codex

Required reviewer: Claude before any activation ceremony

## Result

Implemented the dual-forensics-approved sparse active Custom-history contract.
The implementation is code-and-test complete and remains in review; no
production acceptance run or activation was performed.

Design inputs:

- `docs/ops/evidence/2026-08-15_codex_archive_eater_forensics.md`
- `docs/ops/evidence/2026-08-15_claude_archive_eater_forensics.md`

## Contract implemented

1. Copy-on-claim restores any missing selected archive from the standalone
   manifest-bound `Custom_master`, verifies size and SHA-256 before atomic
   replacement, and proves the resulting terminal inode is private.
2. After the full selected set is proven private, copy-on-claim unlinks every
   non-required manifest archive pathname from the target terminal. This covers
   both `Bases/Custom/history` and `Bases/Custom/ticks`; non-manifest and mutable
   files are not pruned.
3. The dispatch audit has an explicit sparse mode. Missing non-required paths
   are non-failing `PRUNED_BY_DESIGN` observations, never
   `MANIFEST_ARCHIVE_FILE_MISSING` or `TERMINAL_MANIFEST_INCOMPLETE` findings.
4. The pre-copy audit permits a selected missing path only as
   `RESTORE_ON_DEMAND_REQUIRED`. The post-copy audit requires every selected
   path and remains fail-closed if one is absent, corrupt, shared unexpectedly,
   or otherwise outside the manifest contract.
5. The worker passes the host plus declared conversion/basket dependency set to
   both audit phases. The gate binds claim admission to the complete approved
   manifest and verified master-root record. Its repair branch has an
   independent target-and-required-path filter, so a bystander cannot be
   recreated even if an upstream audit were malformed.
6. Copy receipts use `qm.custom-history-copy-on-claim/v2` and record selected,
   restored, newly pruned, already-pruned, copied, and already-private counts.

## Fail-closed boundaries retained

- OWNER-approved manifest validation and activation/ramp checks are unchanged.
- Missing or mismatched master state stops claim admission.
- A master file used for restore/copy is checked for presence and size, then the
  copy is SHA-256 verified against the approved manifest before atomic replace.
- Selected terminal-private files are size/SHA/file-ID/link-count verified.
- Mutable-store collisions, protected-root aliases, manifest mismatches,
  unauthorized paths, and unexplained link-count deficits remain failures.
- Pruning is limited to manifest-declared archive paths beneath the claimed
  terminal's resolved `Bases/Custom` root.

## Verification

Focused and surrounding worker regression command:

```text
python -m pytest -q tools/strategy_farm/tests/test_custom_history_variant_a.py tools/strategy_farm/tests/test_custom_history_smoke_admission.py tools/strategy_farm/tests/test_custom_history_master.py tools/strategy_farm/tests/test_custom_history_copy_on_claim.py tools/strategy_farm/tests/test_terminal_worker_staged_ex5.py tools/strategy_farm/tests/test_terminal_worker_q_phase_stall.py tools/strategy_farm/tests/test_terminal_worker_identity.py tools/strategy_farm/tests/test_terminal_worker_history_lock_storm.py tools/strategy_farm/tests/test_terminal_worker_custom_history_isolation.py tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py tools/strategy_farm/tests/test_terminal_worker_adoption.py tools/strategy_farm/tests/test_mt5_history_isolation.py
```

Result: `185 passed, 4 subtests passed`.

Direct regression coverage includes:

- trimming both history and tick bystander archives;
- idempotent already-pruned handling;
- master-sourced restore-on-demand followed by private-inode verification;
- `PRUNED_BY_DESIGN` audit semantics with no missing-file finding;
- pre-copy restore allowance and post-copy completeness enforcement;
- the independent no-bystander-repair guard; and
- worker propagation of the exact claim symbol set and audit phase.

`git diff --check` passed.

## Deliberately not performed

- No real overlapping-terminal acceptance test. Claude owns that governed
  non-live test window per the routed task.
- No terminal process was launched, stopped, or interrupted.
- No containment, AutoTrading, `T_Live`, pipeline, or activation-ceremony state
  was changed.
