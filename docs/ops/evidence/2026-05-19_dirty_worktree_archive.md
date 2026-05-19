# Dirty Worktree Archive - 2026-05-19

Purpose: non-destructive audit of the dirty worktree after commit `2b12a086`.
No EA artifacts, registry rows, setfiles, binaries, or runtime logs were moved,
deleted, reverted, or staged as part of this archive.

## Snapshot

- Total dirty entries: 1057
- Docs runtime files modified: 3
- EA tracked source/binary/setfile modifications: 146
- EA tracked deletions: 254
- EA untracked artifacts/directories: 639
- Other framework modifications: 6
- Other untracked files: 9

## Buckets

### Safe to archive as evidence

These are small textual ops/evidence or proposed-issue files. They look like
historical audit records, not executable runtime state:

- `docs/ops/evidence/2026-05-15_mt5_worker_pool_smoketest/scheduled_tasks_ready.txt`
- `docs/ops/evidence/2026-05-16T191500Z_sp500_dwx_custom_symbol_t2_t5_rollout.md`
- `docs/ops/evidence/QUA-1597_QM5_1006_deploy_t1_t5_2026-05-15.json`
- `docs/ops/evidence/QUA-1605_QM5_1006_p2_zero_trade_triage_input_2026-05-15.csv`
- `docs/ops/evidence/QUA-1605_QM5_1006_p2_zero_trade_triage_result_2026-05-15.json`
- `docs/ops/evidence/QUA-1605_QM5_1006_valid_zero_trade_run_2026-05-15.md`
- `docs/ops/proposed_issues/2026-05-15_ceo_no_ghost_builds_enforcement.md`
- `docs/ops/proposed_issues/2026-05-16_sp500_dwx_unlock_prompt.md`

Recommendation: commit in a dedicated docs/evidence commit if OWNER wants repo
history to retain these operational receipts.

### Runtime logs, not commit candidates

- `docs/ops/api_failures/2026-05-15.jsonl`
- `docs/ops/pipeline_health/2026-05-15.jsonl`
- `docs/ops/pipeline_health/latest.json`

These append health/error samples from 2026-05-15. They should either be owned
by a log-retention process or moved out of the main repo runtime path. They are
not good candidates for normal feature commits.

### Potential process-code commit, but needs validation

- `framework/scripts/verify_build_deployment.py` is untracked and implements a
  strict P0 artifact/deployment verifier for T1-T5.
- `framework/scripts/phase_orchestrator.py` already calls that verifier and was
  modified to support exact EA directory names.
- `framework/scripts/gen_setfile.ps1` was modified to allow hyphenated EA slugs,
  resolve `qm_magic_slot_offset` from `magic_numbers.csv`, and add richer setfile
  headers.

Recommendation: validate these three together in a dedicated commit. Do not mix
them with the current EA artifact wave.

### Registry changes are high-risk

- `framework/registry/ea_id_registry.csv` grows from 88 rows at `HEAD` to 465
  rows in the worktree.
- `framework/registry/magic_numbers.csv` grows from 824 rows at `HEAD` to 1328
  rows in the worktree.
- `framework/include/QM/QM_MagicResolver.mqh` was regenerated from the dirty
  magic registry and increases `QM_MAGIC_REGISTRY_ROWS` from 537 to 1041.
- `framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json` adds an
  auto-stub calibration for `NDX.DWX` derived from one work item summary.

Blocking validation issue: the dirty `ea_id_registry.csv` contains 7 duplicated
`ea_id` values. `HEAD` has no duplicated `ea_id` values.

Detected duplicated EA IDs in the dirty registry:

- `1101`: `turn-around-tuesday` and `qp-comm-mom12`
- `1223`: `bhatti-fx-zscore-mr` and `hopwood-dmi-cross-h1`
- `1224`: `white-okunev-fx-xmom` and `antor-mtf-macd-scalper`
- `1225`: `dahlquist-fx-econmom` and `channel-cci-bollinger-mr`
- `1226`: `psaradellis-oil-channel` and `4h-box-frankfurt-london`
- `1227`: `neely-fx-channel` and `pip-hunter-heiken-ashi`
- `1434`: duplicate `andrews-pitchfork-sliding-parallel-h4`

Recommendation: do not commit registry or regenerated magic resolver until
duplicate IDs are resolved and the resolver is regenerated from the corrected
registry.

### EA artifact wave

Observed dirty EA artifact classes:

- Modified `.mq5`: 9
- Modified `.ex5`: 9
- Modified `.set`: 128
- Deleted `.set`: 253
- Deleted `.ex5`: 1
- Untracked EA directories: 72
- Untracked `.mq5`: 13
- Untracked `.ex5`: 13
- Untracked `.set`: 541

Recommendation: do not stage this as one commit. Split into explicit OWNER
choices:

1. Source EAs that are intentionally promoted.
2. Compiled `.ex5` binaries that must be versioned.
3. Baseline `.set` files that should stay tracked.
4. Grid/synth/ablation `.set` files that should move to report storage or be
   ignored.
5. Deleted setfiles that need confirmation before removal from Git history.

## Decision

This archive records the dirty state and triage decision without changing the
dirty files. The repo is not clean after this archive by design. The next safe
step is a registry cleanup pass before any EA artifact commit.
