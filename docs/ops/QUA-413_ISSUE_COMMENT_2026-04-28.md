# QUA-413 Issue Comment — 2026-04-28

Status: ready for `in_review`

- Implemented `framework/scripts/deploy_ea_to_all_terminals.ps1` (idempotent, T1-T5, SHA256 verification, T6 refusal).
- Ran deployment for 4 approved binaries (`EA_Skeleton.ex5`, `QM5_1001_framework_smoke.ex5`, `QM5_1002_davey-eu-night.ex5`, `QM5_SRC04_S03_lien_fade_double_zeros.ex5`).
- Verified T1/T2/T3/T4/T5 hashes converge per binary (full transcript in `docs/ops/QUA-413_DEPLOY_VERIFY_T1_T5_2026-04-28.txt`).
- Verified T6 boundary rejection (`exit_code=1` on `T6_Live`).

Commits:
- `bd52db0` framework deploy script + evidence
- `47cd6d0` infra scope/docs alignment
- `097df4c` closeout markdown with hash transcript + T6 proof

Closeout artifact: `docs/ops/QUA-413_CLOSEOUT_2026-04-28.md`
