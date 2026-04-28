# QUA-411 Completion Record

Date: 2026-04-28
Issue: QUA-411

## Objective Coverage

- Required script path delivered:
  - `framework/scripts/deploy_ea_to_all_terminals.ps1`
- Required contract validated:
  - `-EaPath <abs .ex5>` (single-EA)
  - fanout to `T1..T5`
  - create-if-missing `MQL5\Experts\QM`
  - SHA256 verification for each destination
  - non-zero on mismatch
  - success line format `T<n> OK <sha256> <dst path>`

## Concrete Deploy Runs

- Primary manifest run evidence:
  - `docs/ops/QUA-411_DEPLOY_MANIFEST_T1_T5_2026-04-28.json`
- Idempotency rerun evidence:
  - `docs/ops/QUA-411_DEPLOY_MANIFEST_T1_T5_2026-04-28_rerun.json`

Both runs show 4 EAs across all 5 terminals with hash match success.

## Related Implementation Commits

- `8ec4a2a` infra-side initial deploy helper/evidence
- `014b87c` QUA-411 rollout evidence note
- `b56707f` manifest wrapper + strict OK-line contract
- `dc38433` idempotency rerun evidence
